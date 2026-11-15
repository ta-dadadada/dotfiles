# dotfiles

macOSの基盤CLIはHomebrew、Ubuntuの基盤CLIはapt、共通の開発ツールはmise、個人設定はchezmoiで管理するdotfilesです。NixとHome Managerは使用しません。

## 対応環境

- Apple Silicon macOS (`darwin/arm64`)
- x86_64 Ubuntu（セットアップ対象: 24.04 / 26.04、CI検証: 24.04）

ユーザー名とホームディレクトリはchezmoiが検出します。固定の個人パスは使用しません。

## 管理範囲

| 管理元 | 対象 |
| --- | --- |
| Homebrew / apt | Git、tmux、jq、ripgrep、direnv、gh、eza、zoxide、mise、OSの補助ツール |
| mise（共通の必須CLI） | chezmoi、ghq、fzf、bat、fd、starship、Trivy。すべて `latest` |
| mise（マシンごとの任意CLI） | ランタイム、Java、AWS CLI、Granted、kubectl、Helm、Terraform、npm製CLI |
| Homebrew Cask / Google公式apt（任意） | Google Cloud CLI |
| Homebrew Cask（macOS・任意） | GhosttyなどのGUIアプリは必要なマシンへ個別導入 |
| chezmoi | zsh、mise、tmux、Ghostty、Emacsなどのユーザー設定 |

詳細は[ツール管理方針](docs/tool-management.md)を参照してください。
**既存のNix環境から更新する場合は、先に[移行手順](docs/migration-from-nix.md)を読んでください。**

## 初回セットアップ

macOSはXcode Command Line Toolsと[Homebrew](https://brew.sh)を先に導入します。Ubuntuはgit、sudoが必要です。UbuntuへHomebrewは導入しません。

```sh
git clone https://github.com/ta-dadadada/dotfiles.git "$HOME/.local/share/chezmoi"
cd "$HOME/.local/share/chezmoi"
sh scripts/bootstrap.sh
```

上のclone先が既に存在する場合は、そのcheckoutで実行します。リポジトリURLは実際の取得元に合わせてください。
`bootstrap.sh`はOSのパッケージ、mise経由のchezmoi、設定の適用、共通CLIの順に導入します。Ubuntuではapt用にsudoを使います。既存のmiseやNix版chezmoiには依存しません。

設定適用時に上書き確認が出た場合は、ローカル変更を確認してから進めてください。Java、言語ランタイム、クラウドCLI、GUIアプリは自動導入しません。既存のマシン固有設定があれば、初回の適用から尊重します。

ターミナルを開き直して確認します。

```sh
cd "$(chezmoi source-path)"
sh scripts/check-environment.sh
```

AWS/GCPのログインやロール引き受けは行いません。必要に応じて利用者自身で確認します。

## マシンごとのツール選択

共通の `~/.config/mise/config.toml` はchezmoiで管理します。マシンごとの追加と版の上書きは、Git管理外の `~/.config/mise/config.local.toml` に書きます。例えば次の設定なら、そのマシンだけにNode.js、Python、AWS CLI、Javaを追加します。

```toml
[tools]
node = "latest"
python = "latest"
aws-cli = "latest"
java = "temurin"
```

全候補は [設定例](examples/mise/config.local.toml) にあります。必要な行だけ使い、既存ファイルを全体コピーで上書きしないでください。`latest` は最新版追従、`temurin` は最新のTemurin JDKを選びます。
一つ追加する場合も、書き込み先を明示します。

```sh
mise use --path "$HOME/.config/mise/config.local.toml" go@latest
```

設定を編集した後は次のいずれかで導入します。`mise-global.sh` は作業中のプロジェクト設定を除き、共通・ローカルのグローバル設定を通常の規則で結合します。

```sh
cd "$(chezmoi source-path)"
sh scripts/mise-global.sh install --yes
# または、ローカル設定の変更を検出するchezmoiで適用する
chezmoi apply
```

プロジェクトが要求する版は、そのリポジトリの `mise.toml` で固定します。グローバルの版を止める必要はありません。例えばJava 17が必要なプロジェクトだけ `java = "temurin-17"` を指定します。kubectlは接続するAPIサーバーとの対応範囲に合わせてプロジェクト側で指定してください。

共通ツールを明示的に無効化することもできます。ただし `disable_tools` はプロジェクト設定の同じツールも無効にするため、普段使わないだけのツールは最初からローカル設定に追加しない方が適しています。chezmoiやTrivyを無効にすると、設定適用やGit hookが利用できなくなります。

```toml
[settings]
disable_tools = ["starship"]
```

`config.local.toml` はchezmoiの対象から除外し、追加・上書き・削除を行いません。ローカル設定の読み込みを無効にする `MISE_GLOBAL_CONFIG_FILE` を常用しないでください。
ローカル設定で共通設定の版を上書きできない場合は、mise本体をHomebrew/aptから更新してください。mise 2026.5.12では共通設定が優先される挙動を確認し、2026.11.8ではローカル設定が優先されることを検証しています。

Google Cloud CLIが必要なマシンでは明示的に導入します。macOSではCask、UbuntuではGoogle公式aptリポジトリを使います。

```sh
sh scripts/install-google-cloud.sh
# macOSでGhosttyが必要な場合
brew install --cask ghostty
```

そのほかのOSパッケージも必要なマシンでbrew/aptから追加できます。共通一覧にないという理由で自動削除しません。

## 通常の更新

設定の更新と共通CLIの追加導入は次で行います。

```sh
chezmoi update
```

`chezmoi apply`はsudoを使わず、Homebrewやaptの一括更新も行いません。OSのパッケージ一覧を変更した場合は、別途再実行します。

```sh
cd "$(chezmoi source-path)"
sh scripts/bootstrap.sh --base-only
```

共通とマシン固有のツールは、明示的に最新版へ更新します。`latest` でも新しい版の公開だけでは通常切り替わらず、導入済みの版を使います。

```sh
cd "$(chezmoi source-path)"
sh scripts/mise-global.sh outdated
sh scripts/mise-global.sh upgrade --no-prune
```

基盤CLIの更新はmacOSではHomebrew、Ubuntuではaptの通常の操作で行います。mise自身も同じ管理元から更新し、`mise self-update`は使いません。
既存のHomebrew版miseはbootstrapでも更新しません。移行時やmise自体の更新時は `brew update` と `brew upgrade mise` を明示的に実行してください。
上の更新例は `--no-prune` で旧版を保持します。miseの過去バージョン、brew/aptのキャッシュ整理は動作確認後の別操作です。ローカル設定から項目を外しても、既存のバイナリは自動削除しません。

## シェルとJava・端末設定

`~/.zshenv.d`は環境変数とPATH、`~/.zshrc.d`は対話シェルの初期化を管理します。
非対話シェルではmiseのshims、対話シェルでは`mise activate zsh`を使います。`~/.local/bin`はPATH末尾に置き、補助ファイル`~/.local/bin/env`がなくても参照できます。

Javaを設定したマシンでは、`JAVA_HOME`をmiseが選択したJavaから設定します。Javaのshimを起動した子プロセスだけでなく、非対話のzshからも参照できます。
UbuntuのGhostty terminfoは同梱データから `tic -x` で `~/.local/share/terminfo` に生成します。Ghostty本体は導入しません。macOSではGhosttyアプリ同梱のterminfoを利用します。

移行用の `~/.zshenv.d/nix.zsh` は旧ファイルを上書きするため名前を残し、Nixを読み込まず、継承したNixのPATHと証明書変数を除きます。システムの `/etc/zshrc` が再追加したPATHも対話シェル側で除きます。Nix本体やプロファイルは削除しません。
Nixを指す `JAVA_HOME` とterminfoの検索先も除きます。Nix以外の証明書パスやterminfoの検索先は保持します。

Android SDKはAndroid Studioなどでローカルに導入したものをOS別に検出します。マシン固有設定と秘密情報はGit管理外の `~/.zshrc.local`、`~/.config/ghostty/local.config` に置きます。

## 企業プロキシの証明書

Netskopeなどの社内CAを標準パスから検出し、OSのCAと結合して `~/.local/share/netskope/ca-bundle.crt` を生成します。未検出の環境では何も生成せず、証明書の環境変数も設定しません。証明書はコミットしません。

`SSL_CERT_FILE`、`CURL_CA_BUNDLE`、`GIT_SSL_CAINFO`、`NODE_EXTRA_CA_CERTS`、`AWS_CA_BUNDLE`などへバンドルを渡します。NixのCAとdaemon設定には依存しません。
JavaのtruststoreはJDK本体を変更せず複製して生成し、初回のmise導入後にも再確認します。`JAVA_TOOL_OPTIONS`はstderrへのバナーを避けるため自動設定しません。

```sh
ssl-doctor          # 読み取り専用の診断
ssl-doctor reset    # 退避後にCAバンドルとJava truststoreを再生成
```

JDKの更新後にtruststoreを更新する場合も `ssl-doctor reset` を使います。必要なJavaアプリだけ、ローカル設定で指定します。

```sh
export JAVA_TOOL_OPTIONS="-Djavax.net.ssl.trustStore=$NETSKOPE_JAVA_TRUSTSTORE -Djavax.net.ssl.trustStorePassword=changeit"
```

社内CAが標準パス以外にある場合は、`NETSKOPE_CA_CERT`を設定してから `ssl-doctor reset` を実行します。`chezmoi apply`にも渡す場合は同じ環境変数をexportしてください。
HTTPプロキシ変数や証明書検証を無効化する変数は自動設定しません。
初回セットアップ中のapt/Homebrew自体が社内CAを必要とする場合は、先に組織の手順でOS・パッケージマネージャーの信頼設定を行ってください。ユーザー用のCAバンドルだけではsudo先のaptには適用されません。

## 検証と秘密情報検査

```sh
sh scripts/verify.sh
trivy fs --config trivy.yaml .
git diff --check
```

`verify.sh`はmacOS/Ubuntuのテンプレートを一時ディレクトリへ展開し、シェル構文、ShellCheck、非対話シェルの回帰テスト、Ghostty terminfoを確認します。実環境の設定やパッケージは変更しません。
GitHub ActionsはmacOSとUbuntuそれぞれで、共通の最小構成と任意ツールを追加した構成を導入し、一時ホームでコマンドとシェル起動を確認します。環境確認スクリプトは、有効なmise設定に含まれるツールだけを必須とします。ローカルでの展開確認だけでは、別OSの実行確認を代替できません。

Git hookは `chezmoi apply` の最後に有効化します。pre-commitはステージ済み内容、pre-pushはpush対象refをTrivyで検査し、Trivy未導入時も中止します。
誤検知の例外は `trivy-secret.yaml` に理由付きの限定ルールとして記録します。Markdownも検査対象です。

## 主なshell操作

- `tmux`: 必要なときに手動でセッションを開始する。シェル起動時には自動起動しない
- `ls`、`ll`、`la`: ezaによる一覧表示
- `Ctrl-R`: fzfによる履歴検索
- `Ctrl-T`: ファイル検索
- `Ctrl-G`: ghqリポジトリへ移動
- `Alt-C`: ディレクトリ検索
- `ff`: 選択したファイルをエディタで開く
- `fcd`: 選択したディレクトリへ移動する
- `rgf <pattern>`: ripgrepの検索結果をエディタで開く
- `gbs`: Gitブランチを選択して切り替える
- `gco-any`: 任意のコミットを選択してcheckoutする
- `prc`: GitHub Pull Requestを選択してcheckoutする
- `zfcd`: zoxideの履歴から移動する
- `pzkill`: プロセスを選択して終了する
- `fassume [options]`: AWSプロファイルをfzfで選択し、`assume-shell`で認証済みの子シェルを開く。例: `fassume --region ap-northeast-1`
- `assume-shell [profile] [options]`: Grantedで認証した対話zshを子プロセスとして開く。プロファイル省略時はGrantedで選択し、`exit`または`Ctrl-D`で元のシェルへ戻る。例: `assume-shell development --region ap-northeast-1`
- `shuffle_bg`: Ghosttyの背景画像をランダムに切り替える（macOSのみ）
