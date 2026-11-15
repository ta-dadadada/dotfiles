# ツール管理方針

## 管理境界

設定はchezmoi、バージョンをそろえる共通CLIとランタイムはmise、OSの基盤はmacOSでHomebrew、Ubuntuでaptを使う。NixとHome Managerは使わない。

| 対象 | macOS | Ubuntu |
| --- | --- | --- |
| git、tmux、jq、rg、direnv、gh、eza、zoxide | Homebrew | apt |
| mise本体 | Homebrew | mise公式aptリポジトリ |
| chezmoi、ghq、fzf、bat、fd、starship、trivy（共通の必須CLI） | mise | mise |
| AWS CLI、Java（マシンごとに選択） | mise | mise |
| Node.js、pnpm、Bun、Python、uv、Yarn、Granted、kubectl、Helm、Terraform、npm製CLI（マシンごとに選択） | mise | mise |
| Google Cloud CLI（任意） | Homebrew Cask `gcloud-cli` | Google公式apt `google-cloud-cli` |
| Ghostty本体（任意） | Homebrew Cask | 導入しない |
| Ghostty terminfo | アプリ同梱 | 同梱のソースをユーザー領域へコンパイル |
| 設定・PATH・社内CA用補助スクリプト | chezmoi | chezmoi |

同じコマンドの直接の管理元は一つにする。Homebrewやaptが別パッケージの依存としてNode.jsやPython等を導入することはあるが、開発用のコマンドとバージョンはmiseから選択する。依存パッケージを強制削除しない。

OS管理のツールはOSごとのバージョン差を許容する。差によって必要な機能が使えない場合は、両OS共通のmise管理へ移すことを検討する。新しいPPAや手書きのダウンローダーをツールごとに増やさない。

## 唯一の一覧

- macOS: `.chezmoitemplates/packages/Brewfile`
- Ubuntu: `.chezmoitemplates/packages/ubuntu.txt`。miseは `scripts/install-ubuntu.sh`、任意のGoogle Cloud CLIは `scripts/install-google-cloud.sh` で公式リポジトリから導入する。
- 両OSの共通CLI: `dot_config/mise/config.toml`
- マシン固有の追加・上書き: `~/.config/mise/config.local.toml`（Git管理外、chezmoi適用時も保持）
- 任意ツールの記入例: `examples/mise/config.local.toml`

共通設定はシェル操作とdotfiles管理に必要な7種類に絞る。ランタイム、言語ごとのパッケージマネージャー、クラウド・インフラ・npm製CLIは、マシンまたはプロジェクト側で選ぶ。
グローバルは原則 `latest`、Javaはベンダーを明示した `temurin` とする。プロジェクトの再現性は各リポジトリの `mise.toml` で固定する。具体的な不具合や配布制約による例外には、理由と解除条件をコメントする。共通のlockfileで全マシンの更新を止めない。
fzfは `fzf --zsh` を利用するため、古いUbuntuパッケージに依存させない。batとfdはUbuntuの別コマンド名を設定全体に持ち込まないためmiseにそろえる。

mise自身はOSパッケージとして導入し、自分自身では管理しない。chezmoiはmiseで導入する。初回のchezmoi取得だけcheckoutの設定で隔離する。実際のapplyへ隔離用の環境変数を持ち込まず、配置後の共通設定と既存のローカル設定を結合する。

## セットアップと適用順

明示的な `sh scripts/bootstrap.sh` で次を行う。

1. 対応OS/CPUを検査し、基盤パッケージを導入する。Ubuntuはsudoを使う。
2. checkoutの設定を使ってmiseでchezmoiを導入する。
3. そのchezmoiで同じcheckoutを適用する。

`chezmoi apply` は次を行う。Homebrewやaptの操作は含めない。

1. 設定ファイルを展開する。
2. 社内CAを検出した場合だけ、OSのCAと結合したバンドルを生成する。
3. UbuntuのGhostty terminfoを `~/.local/share/terminfo` へ導入する。
4. 共通とマシン固有のmise設定を信頼済みに登録し、有効なグローバルのツールを導入する。
5. 旧Voltaがあり代替コマンドがすべてそろう場合だけ、`~/.volta.retired` へ退避する。不足時は退避せず続行する。
6. Javaを利用するマシンでは、JDK導入後にtruststoreの生成を再確認する。
7. リポジトリのGit hookを設定する。

OSパッケージの追加だけなら `sh scripts/bootstrap.sh --base-only` を実行する。macOSでは既存パッケージを一括upgradeせず、Brewfileの不足分を導入する。Ubuntuの `apt-get install` は指定パッケージを更新することがあるが、全体のupgradeは行わない。

## マシン固有設定の扱い

`config.local.toml` は標準の上書きファイルとして読み込む。共通設定にないツールの追加、同じツールの版の上書き、明示的な `disable_tools` を尊重する。無効化はプロジェクト側にも及ぶため、任意ツールは共通設定へ入れて無効化するより、必要なマシンだけに追加する。
追加例、編集・導入・更新操作は [README](../README.md#マシンごとのツール選択) を参照する。

`scripts/mise-global.sh` は中立な一時ディレクトリからmiseを呼び、作業中のプロジェクト設定だけを除外する。導入と環境確認は同じ読み込み規則を使う。`MISE_GLOBAL_CONFIG_FILE` で共通設定だけを強制するとローカル設定を読まなくなるため、通常運用では設定しない。
`run_onchange` はローカル設定の内容ハッシュも含み、変更後のapplyで再実行する。ファイル自体の内容はスクリプトへ埋め込まない。

環境確認はOSの基盤に加え、有効なmise設定の導入状態を調べる。JavaやAWS CLIなど未選択のツールは要求せず、Google Cloud CLIは既に存在する場合だけ起動を検査する。新しい任意ツールをローカル設定へ追加しても、導入状態の確認に別の必須一覧を追加する必要はない。

## シェルと環境変数

`dot_zshenv.d/homebrew.zsh` はApple Silicon Macの標準パスからHomebrewを初期化する。UbuntuではHomebrewを読み込まない。
`dot_zshenv.d/tools.zsh` はmiseのshimsをPATHへ追加し、`~/.local/bin`は末尾へ置く。対話シェルでは `dot_zshrc.d/tools.zsh` がmiseをactivateする。
`dot_zshenv.d/runtime.zsh` は選択中のJavaから `JAVA_HOME` を設定し、ユーザー領域のterminfoを参照する。

`dot_zshenv.d/nix.zsh` は旧管理ファイルを上書きするため残す。NixやHome Managerの初期化を行わず、親プロセスやシステム設定から継承したNixのPATH、Nixの `JAVA_HOME` と証明書変数を除く。`dot_zshrc`でも再度除き、システム初期化で再追加されるPATHに対応する。Nixを必要とする別プロジェクトがある場合は、撤去前にその依存を確認する。

## GrantedとVolta

Grantedは任意のローカル設定で `latest` を指定する。0.40.0でmacOS配布物が復帰しており、過去の配布制約による0.38.0固定は解除する。両OSで配布・起動をCI確認し、実際のSSOとKeychainは利用者が確認する。
`assume`のsource用エイリアス、`assume-shell`、`fassume`は維持する。AWS設定や認証情報は管理しない。実際のSSO・ロール引き受けは利用者が対話的に確認する。

旧Voltaの退避先は自動削除しない。戻す場合は `~/.volta.retired` を `~/.volta` へ戻し、`dot_zshenv.d/remove_nodejs.zsh` とPATHの変更を確認する。miseの削除は別操作とする。

## 更新・撤去

miseの最新版追従は `scripts/mise-global.sh outdated` と `scripts/mise-global.sh upgrade --no-prune`、OSの基盤更新はbrew/aptで行う。更新と古いバージョン・キャッシュの削除は分ける。
Nix環境からの段階移行、旧パッケージの整理、復旧方法は [移行手順](migration-from-nix.md) を参照する。
