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
| mise（両OS共通） | chezmoi、ghq、fzf、bat、fd、starship、Trivy、AWS CLI、Java 17、ランタイムと開発CLI |
| Homebrew Cask / Google公式apt | Google Cloud CLI |
| Homebrew Cask（macOSのみ） | Ghostty。その他の既存GUIアプリは引き続き各自で管理 |
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

設定適用時に上書き確認が出た場合は、ローカル変更を確認してから進めてください。GUIアプリを導入しない環境では `DOTFILES_SKIP_GUI=1 sh scripts/bootstrap.sh` とします（Google Cloud CLIは導入します）。

ターミナルを開き直して確認します。

```sh
cd "$(chezmoi source-path)"
sh scripts/check-environment.sh
```

AWS/GCPのログインやロール引き受けは行いません。必要に応じて利用者自身で確認します。

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

miseのリリース系列内の更新は明示的に行います。

```sh
mise outdated
mise upgrade
```

基盤CLIの更新はmacOSではHomebrew、Ubuntuではaptの通常の操作で行います。mise自身も同じ管理元から更新し、`mise self-update`は使いません。
更新時に古いツールを自動削除しません。miseの過去バージョン、brew/aptのキャッシュ整理は動作確認後の別操作です。

## シェルとJava・端末設定

`~/.zshenv.d`は環境変数とPATH、`~/.zshrc.d`は対話シェルの初期化を管理します。
非対話シェルではmiseのshims、対話シェルでは`mise activate zsh`を使います。`~/.local/bin`はPATH末尾に置き、補助ファイル`~/.local/bin/env`がなくても参照できます。

`JAVA_HOME`はmiseが選択したJavaから設定します。Javaのshimを起動した子プロセスだけでなく、非対話のzshからも参照できます。
UbuntuのGhostty terminfoは同梱データから `tic -x` で `~/.local/share/terminfo` に生成します。Ghostty本体は導入しません。macOSではGhosttyアプリ同梱のterminfoを利用します。

移行用の `~/.zshenv.d/nix.zsh` は旧ファイルを上書きするため名前を残し、Nixを読み込まず、継承したNixのPATHと証明書変数を除きます。システムの `/etc/zshrc` が再追加したPATHも対話シェル側で除きます。Nix本体やプロファイルは削除しません。

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
GitHub ActionsはmacOSとUbuntuで基盤パッケージとmiseツールを導入し、一時ホームでコマンドとシェル起動を確認します。ローカルでの展開確認だけでは、別OSの実行確認を代替できません。

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
