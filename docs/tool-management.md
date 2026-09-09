# ツール管理方針

## 目的

同じコマンドを複数のツールで導入すると、PATH の順序によって意図しないバージョンが選ばれる。
この文書では、Nix、mise、chezmoi、Homebrew の責務を分離し、各ツールの管理元を一つに定める。

## 管理境界

| 管理ツール | 責務 | 主な対象 |
| --- | --- | --- |
| Nix / Home Manager | 端末を構成する基盤 CLI | mise、chezmoi、Git、ghq、AWS CLI、kubectl、Terraform、Trivy |
| mise | バージョンを固定・切り替えたいランタイムと開発ツール | Node.js、pnpm、Bun、Python、uv、Granted、npm製CLI |
| chezmoi | ユーザー設定と各管理ツールをつなぐ設定 | zsh、mise設定、Ghostty、tmux、Emacs |
| Homebrew | Nixで扱わないmacOS固有パッケージ | GUIアプリ、Homebrew Cask |

一つのコマンドは一つの管理ツールだけから導入する。例外を設ける場合は、理由と優先するPATHをこの文書へ記録する。

## 管理対象

### Nix / Home Manager

次の条件に当てはまるツールを管理する。

- ログイン直後から利用する基盤CLI
- プロジェクトごとのバージョン切り替えが不要なCLI
- mise自身やchezmoiなど、環境を構成するためのブートストラップ用CLI

`dot_config/nix/home.nix` を唯一のパッケージ一覧とする。`home.stateVersion`は依存更新に合わせて変更しない。

### mise

次の条件に当てはまるツールを管理する。

- 言語ランタイムとパッケージマネージャー
- プロジェクトごとに異なるバージョンを使う可能性があるツール
- リリース単位で明示的に更新したい開発用CLI

グローバル既定値は `dot_config/mise/config.toml` で正確なバージョンに固定する。各プロジェクトは自身の `mise.toml` でグローバル既定値を上書きできる。
バージョンを更新するときは設定変更後に `mise install` と動作確認を行い、古いバージョンの削除は別操作とする。

### chezmoi

設定ファイルだけを管理し、CLI本体や言語ランタイムの配布元にはしない。
マシン固有設定と秘密情報は、リポジトリ外のローカル設定へ置く。

### Homebrew

GUIアプリやNixで扱わないmacOS固有パッケージに限定する。同名のCLIをNixまたはmiseでも導入しない。

## 現在の割り当て

| コマンド | 管理元 |
| --- | --- |
| `mise`, `chezmoi`, `git`, `ghq`, `aws`, `kubectl`, `helm`, `terraform`, `trivy` | Nix |
| `node`, `pnpm`, `bun`, `python`, `uv`, `granted`, `assume`, `devcontainer`, `gemini` | mise |

Java 17は、現在はHome Managerのセッション変数と一体で管理しているためNixに残す。プロジェクトごとのJava切り替えが必要になった時点でmiseへの移行を別途検討する。

## 適用順序

`chezmoi apply`では次の順序で適用する。

1. 設定ファイルをホームディレクトリへ展開する。
2. `run_onchange_after_20-apply-home-manager.sh.tmpl`でHome Managerを適用し、miseとchezmoiを含む基盤CLIを導入する。
3. `run_onchange_after_25-install-mise-tools.sh.tmpl`でmise設定に固定されたツールを導入する。
4. `run_onchange_after_30-configure-git-hooks.sh.tmpl`でGit hookを設定する。

Nixまたはmiseが未導入の場合、対応するスクリプトは再実行方法を表示して終了する。導入後にターミナルを再起動し、再度 `chezmoi apply` を実行する。

## Granted

Granted本体はmiseで管理する。zshでは `alias assume='source assume'` が必要なため、`dot_zshenv.d/granted.zsh`で管理する。
バージョン0.39.0にはmacOS用の配布物がないため、macOSとLinuxの両方を同じ設定で扱える0.38.0に固定する。将来更新するときは、両方の対応環境で配布物が提供されていることを確認する。

次のファイルは個人設定や認証情報を含むため管理しない。

- `~/.aws/config`
- `~/.aws/credentials`
- `~/.granted/`

導入後は `granted --version` と `command -v assume assumego` を確認する。実際のロール引き受けは、利用者のAWSプロファイルとSSO設定を使って対話的に確認する。

## 移行とロールバック

Voltaや個別インストールしたBunのディレクトリは自動削除しない。mise版のコマンドが利用できることを確認した後、PATH設定だけをchezmoiから外す。

問題が起きた場合は、`dot_zshenv.d/remove_nodejs.zsh`を削除して元の`dot_zshenv.d/nodejs.zsh`を復元し、新しいシェルを開けば既存のVolta環境へ戻せる。miseで導入したツールの削除はロールバックとは分けて行う。
