# ツール管理方針

## 管理境界

設定はchezmoi、バージョンをそろえる共通CLIとランタイムはmise、OSの基盤はmacOSでHomebrew、Ubuntuでaptを使う。NixとHome Managerは使わない。

| 対象 | macOS | Ubuntu |
| --- | --- | --- |
| git、tmux、jq、rg、direnv、gh、eza、zoxide | Homebrew | apt |
| mise本体 | Homebrew | mise公式aptリポジトリ |
| chezmoi、ghq、fzf、bat、fd、starship、trivy、aws、Java 17 | mise | mise |
| Node.js、pnpm、Bun、Python、uv、Yarn、Granted、kubectl、Helm、Terraform、npm製CLI | mise | mise |
| Google Cloud CLI | Homebrew Cask `gcloud-cli` | Google公式apt `google-cloud-cli` |
| Ghostty本体 | Homebrew Cask | 導入しない |
| Ghostty terminfo | アプリ同梱 | 同梱のソースをユーザー領域へコンパイル |
| 設定・PATH・社内CA用補助スクリプト | chezmoi | chezmoi |

同じコマンドの直接の管理元は一つにする。Homebrewやaptが別パッケージの依存としてNode.jsやPython等を導入することはあるが、開発用のコマンドとバージョンはmiseから選択する。依存パッケージを強制削除しない。

OS管理のツールはOSごとのバージョン差を許容する。差によって必要な機能が使えない場合は、両OS共通のmise管理へ移すことを検討する。新しいPPAや手書きのダウンローダーをツールごとに増やさない。

## 唯一の一覧

- macOS: `.chezmoitemplates/packages/Brewfile`
- Ubuntu: `.chezmoitemplates/packages/ubuntu.txt`。miseとGoogle Cloud CLIは `scripts/install-ubuntu.sh` で公式リポジトリから導入する。
- 両OSの共通CLI: `dot_config/mise/config.toml`

miseは互換性を保つリリース系列を指定する。0.xはminor系列、安定版はmajor系列を基本とし、JavaはTemurin 17を使う。プロジェクト固有のバージョンは各リポジトリの `mise.toml` で上書きする。
fzfは `fzf --zsh` を利用するため、古いUbuntuパッケージに依存させない。batとfdはUbuntuの別コマンド名を設定全体に持ち込まないためmiseにそろえる。

mise自身はOSパッケージとして導入し、自分自身では管理しない。chezmoiはmiseで導入する。初回はcheckoutのmise設定を明示してchezmoiを起動するため、既存のグローバル設定やNix版chezmoiには依存しない。

## セットアップと適用順

明示的な `sh scripts/bootstrap.sh` で次を行う。

1. 対応OS/CPUを検査し、基盤パッケージを導入する。Ubuntuはsudoを使う。
2. checkoutの設定を使ってmiseでchezmoiを導入する。
3. そのchezmoiで同じcheckoutを適用する。

`chezmoi apply` は次を行う。Homebrewやaptの操作は含めない。

1. 設定ファイルを展開する。
2. 社内CAを検出した場合だけ、OSのCAと結合したバンドルを生成する。
3. UbuntuのGhostty terminfoを `~/.local/share/terminfo` へ導入する。
4. chezmoiが配置したmise設定を信頼済みに登録し、グローバルのmiseツールを導入する。
5. 旧Voltaがある場合、代替コマンドを確認して `~/.volta.retired` へ退避する。
6. JDK導入後にJava truststoreの生成を再確認する。
7. リポジトリのGit hookを設定する。

OSパッケージの追加だけなら `sh scripts/bootstrap.sh --base-only` を実行する。macOSでは既存パッケージを一括upgradeせず、Brewfileの不足分を導入する。Ubuntuの `apt-get install` は指定パッケージを更新することがあるが、全体のupgradeは行わない。

## シェルと環境変数

`dot_zshenv.d/homebrew.zsh` はApple Silicon Macの標準パスからHomebrewを初期化する。UbuntuではHomebrewを読み込まない。
`dot_zshenv.d/tools.zsh` はmiseのshimsをPATHへ追加し、`~/.local/bin`は末尾へ置く。対話シェルでは `dot_zshrc.d/tools.zsh` がmiseをactivateする。
`dot_zshenv.d/runtime.zsh` は選択中のJavaから `JAVA_HOME` を設定し、ユーザー領域のterminfoを参照する。

`dot_zshenv.d/nix.zsh` は旧管理ファイルを上書きするため残す。NixやHome Managerの初期化を行わず、親プロセスやシステム設定から継承したNixのPATH、Nixの `JAVA_HOME` と証明書変数を除く。`dot_zshrc`でも再度除き、システム初期化で再追加されるPATHに対応する。Nixを必要とする別プロジェクトがある場合は、撤去前にその依存を確認する。

## GrantedとVolta

Grantedは両OSに配布物がある0.38.0へ固定する。更新時はmacOS arm64とLinux amd64の両方を確認する。
`assume`のsource用エイリアス、`assume-shell`、`fassume`は維持する。AWS設定や認証情報は管理しない。実際のSSO・ロール引き受けは利用者が対話的に確認する。

旧Voltaの退避先は自動削除しない。戻す場合は `~/.volta.retired` を `~/.volta` へ戻し、`dot_zshenv.d/remove_nodejs.zsh` とPATHの変更を確認する。miseの削除は別操作とする。

## 更新・撤去

miseの系列内更新は `mise outdated` と `mise upgrade`、OSの基盤更新はbrew/aptで行う。更新と古いバージョン・キャッシュの削除は分ける。
Nix環境からの段階移行、旧パッケージの整理、復旧方法は [移行手順](migration-from-nix.md) を参照する。
