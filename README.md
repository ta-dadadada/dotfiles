# dotfiles

CLI環境をNix、Home Manager、mise、個人設定をchezmoiで管理するdotfilesです。

## 管理範囲

| 管理ツール | 対象 |
| --- | --- |
| Nix / Home Manager | 基盤CLI、クラウドCLI、mise、chezmoi |
| mise | ランタイム、バージョン切り替え対象のCLI、Granted、npm製CLI |
| chezmoi | zsh、mise、tmux、Ghostty、Emacsなどの個人設定 |
| Homebrew | macOSのGUIアプリとNixで扱わないパッケージ |

Home Managerはパッケージの導入だけに使用します。zsh、Git、tmuxなどの設定ファイルはHome Managerで生成しません。
詳しい責務分担と移行・ロールバック方法は[ツール管理方針](docs/tool-management.md)を参照してください。

## 対応環境

- Apple Silicon Mac (`aarch64-darwin`)
- Ubuntu x86_64 (`x86_64-linux`)

ユーザー名とホームディレクトリはchezmoiがセットアップ対象から検出します。固定のユーザー名や標準ホームディレクトリは前提にしません。

## 初回セットアップ

最初に[Nix公式手順](https://nixos.org/download/)でNixを導入します。

```sh
sh <(curl -L https://nixos.org/nix/install)
```

ターミナルを再起動してから、chezmoiを初期化します。

```sh
nix --extra-experimental-features 'nix-command flakes' \
  run 'nixpkgs#chezmoi' -- init --apply ta-dadadada
```

Nixインストーラーが既存の`~/.zshenv`へ初期化処理を追加している場合、chezmoiから上書き確認が表示されます。管理下の`.zshenv.d/nix.zsh`がNixとHome Managerの初期化を引き継ぐため、上書きして構いません。

すでにchezmoiを利用している環境では、Nix導入前に`chezmoi apply`を実行しても構いません。その場合、Nix設定は配置されますがHome Managerの適用は保留されます。Nix導入後にターミナルを再起動し、再度適用します。

```sh
chezmoi apply
```

`run_onchange_after`が`flake.lock`で固定されたHome Managerのactivation packageをビルドしてCLI環境を有効化し、続けてmiseのグローバル設定に指定されたツールを導入します。Nixまたはmise未導入時の実行状態もスクリプト内容に含まれるため、導入後の`chezmoi apply`で再実行されます。

## 管理するCLI

- 基本ツール: Git、tmux、fzf、ripgrep、fd、bat、jq、eza
- 開発支援: gh、ghq、zoxide、starship、direnv、Java 17、mise、chezmoi
- クラウド: kubectl、Helm、Terraform、AWS CLI、Google Cloud SDK

Node.js、pnpm、Bun、Python、uv、Granted、npm製CLI、Yarn、kubectl、Helm、Terraformはmiseで管理し、Nixとの二重管理を避けます。グローバル既定値は互換性を保つリリース系列で指定し、プロジェクト固有のバージョンは各リポジトリの`mise.toml`で上書きします。Grantedだけは対応プラットフォームに配布物がある正確なバージョンへ固定します。

Android SDKはAndroid Studioなどでローカルに導入し、chezmoiがOS別の標準パスを検出して`ANDROID_SDK_ROOT`とPATHを設定します。

## 通常の更新

dotfilesを更新して適用します。

```sh
chezmoi update
```

Home Managerだけを手動で再適用する場合は次を実行します。

```sh
home-manager switch --flake ~/.config/nix#default
```

miseで管理するツールだけを手動で再適用する場合は次を実行します。

```sh
mise install
```

設定したリリース系列内の最新版へ更新する場合は、更新後のバージョンを確認してからアップグレードします。

```sh
mise outdated
mise upgrade
```

NixpkgsとHome Managerを更新する場合は、chezmoiのソースディレクトリでロックファイルを更新します。

```sh
chezmoi cd
tmpdir=$(mktemp -d)
chezmoi execute-template -f dot_config/nix/flake.nix.tmpl > "$tmpdir/flake.nix"
cp dot_config/nix/home.nix dot_config/nix/flake.lock "$tmpdir/"
nix flake update --flake "$tmpdir"
cp "$tmpdir/flake.lock" dot_config/nix/flake.lock
rm -rf "$tmpdir"
```

実際のFlakeはchezmoiテンプレートのため、一時ディレクトリへ展開してロックファイルを更新します。半年ごとにnixpkgsとHome Managerを同じ安定版系列へ更新します。`home.stateVersion`は変更しません。

GitHub Actionsはリリースタグに対応するコミットSHAで固定しています。Dependabotが毎週更新を確認し、SHAと同じ行にあるバージョンコメントも更新します。Nix入力はDependabotの対象外のため、上記の`flake.lock`更新手順で管理します。

## 企業プロキシ (TLS傍受) 対応

Netskopeなどの企業プロキシはTLSを傍受し、社内CAで再署名します。このCAを信頼しないCLIはSSL証明書の検証エラーで失敗します。

`chezmoi apply`時に社内CAを標準パスから自動検出し、**システムCAと結合したバンドル**を`~/.local/share/netskope/ca-bundle.crt`へ生成します。Java用のtruststoreも同じディレクトリに作ります。`.zshenv.d/ssl.zsh`が`SSL_CERT_FILE`、`CURL_CA_BUNDLE`、`GIT_SSL_CAINFO`、`NODE_EXTRA_CA_CERTS`などへこのバンドルを渡します。

社内CAを検出できない環境では何も生成せず、環境変数も設定しません。証明書はリポジトリにコミットしません。

バンドルは検出できたシステムCA（macOSの`/etc/ssl/cert.pem`とNixのバンドルなど）をすべて結合し、フィンガープリントで重複を除いたうえで社内CAを加えます。いずれか1つだけを基準にすると、そのバンドルに収録されていないルートを信頼できなくなるためです。結果として既存のシステムルートの上位集合になり、VPN外やプロキシ無効時でも通常の証明書検証は壊れません。

### nix-daemonの設定 (Nix利用時は必須)

マルチユーザーモードのNixは、ソースの取得をrootで動作するdaemonが行うため、シェルの環境変数が効きません。`curl`は成功するのに`nix build`だけ失敗する形で現れます。root権限とホームディレクトリ外の変更が必要なため自動化していません。次を手動で実行します。

```sh
echo "ssl-cert-file = $HOME/.local/share/netskope/ca-bundle.crt" | sudo tee -a /etc/nix/nix.conf
sudo launchctl kickstart -k system/org.nixos.nix-daemon
```

### SSLエラーが出たときは

`ssl-doctor`で原因を切り分けます。傍受の有無、バンドルの整合性と有効期限、環境変数とnix-daemon、各ツールの実接続を診断します。読み取り専用で副作用はありません。

```sh
ssl-doctor          # 診断
ssl-doctor reset    # バンドルを作り直して再診断
```

| 症状 | 対処 |
| --- | --- |
| プロキシ更新後にSSLエラー | `ssl-doctor`で原因を確認し、`ssl-doctor reset` |
| `nix build`だけ失敗 | `ssl-doctor`が指摘するnix-daemonの手順を実行 |
| 特定のツールだけ失敗 | `ssl-doctor`の接続テストで対象を特定 |
| 元に戻したい | `rm -rf ~/.local/share/netskope`で無効化 (下記の注意を参照) |

`ssl-doctor reset`は既存バンドルを退避してから作り直し、失敗時は書き戻します。証明書がローテーションされた場合は`chezmoi apply`でも再生成されます。

`rm -rf ~/.local/share/netskope`による無効化は恒久的ではありません。社内CAがローテーションされると`chezmoi apply`が再生成を検知して作り直します。恒久的に止める場合は`~/.zshrc.local`で証明書変数を`unset`するか、社内CAを検出できない状態にします。

### Java

Nix Storeは読み取り専用でJDKの`cacerts`を変更できないため、複製した`~/.local/share/netskope/cacerts`を生成し、パスを`NETSKOPE_JAVA_TRUSTSTORE`で公開します。`JAVA_TOOL_OPTIONS`はJVM起動ごとにstderrへメッセージを出力し、出力を解析するスクリプトを壊すため既定では設定しません。必要な場合は`~/.zshrc.local`に追加します。

```sh
export JAVA_TOOL_OPTIONS="-Djavax.net.ssl.trustStore=$NETSKOPE_JAVA_TRUSTSTORE -Djavax.net.ssl.trustStorePassword=changeit"
```

GradleやMavenは`~/.gradle/gradle.properties`や`MAVEN_OPTS`で個別に指定します。

### 証明書のパスとプロキシ変数

社内CAが標準以外のパスにある場合や暗号化されている場合は、`~/.zshrc.local`で明示します。

```sh
export NETSKOPE_CA_CERT="$HOME/.config/certs/corp-ca.pem"
```

`HTTP_PROXY`などのプロキシ変数は設定しません。Netskopeは既定で透過的に動作し、明示設定はlocalhostや内部通信を壊すためです。必要な場合は`~/.zshrc.local`に置き、`NO_PROXY`へ`localhost,127.0.0.1,::1,.local`を含めます。

`GIT_SSL_NO_VERIFY`、`NODE_TLS_REJECT_UNAUTHORIZED=0`、`PYTHONHTTPSVERIFY=0`は証明書検証自体を無効化するため使いません。

## 秘密情報の検査

Trivyのsecret scannerをコミット前、push前、GitHub Actionsで実行します。Home Managerの適用時に、このリポジトリの`core.hooksPath`が`.githooks`へ設定されます。

pre-commit hookはGit indexを一時ディレクトリへ展開し、ステージ済みのコミット対象だけを検査します。検出時またはTrivy未導入時はコミットを中止します。
pre-push hookはpush対象refの内容を一時ディレクトリへ展開して検査します。削除だけのpushでは検査を省略し、秘密情報の検出時またはTrivy未導入時はpushを中止します。

リポジトリ全体を手動で検査する場合は次を実行します。

```sh
trivy fs --config trivy.yaml .
```

誤検知を除外する場合は、値自体を安易に許可せず、`trivy-secret.yaml`のallow ruleを理由付きで追加します。Markdownも秘密情報の検査対象です。

## ロールバック

利用可能な世代を確認します。

```sh
home-manager generations
```

戻したい世代のNix Storeパスにある`activate`を実行します。

```sh
/nix/store/<generation>-home-manager-generation/activate
```

## Homebrewからの段階移行

Nix版とmise版のCLIが正常に動作することを確認してから、重複するHomebrewパッケージを個別に削除します。GUIアプリとHomebrew Caskは今回の移行対象外です。

```sh
command -v git tmux fzf rg fd bat jq eza gh ghq zoxide starship direnv java gcloud mise chezmoi
command -v node npm npx pnpm yarn yarnpkg bun python uv granted assume devcontainer gemini kubectl helm terraform
```

Voltaからの移行時は、上記の代替コマンドをmiseで確認した後、`~/.volta`を`~/.volta.retired`へ自動的に退避します。退避先は自動削除しません。`pnpx`は廃止し、必要な場合は`pnpm dlx`を使用します。

## zsh設定

`~/.zshenv.d`は環境変数とPATH、`~/.zshrc.d`は対話シェルの設定を管理します。任意ツールの初期化はコマンドが存在する場合だけ行います。

macOSではGhosttyアプリに同梱されたterminfoを利用します。UbuntuではHome ManagerがGhosttyのterminfoだけを導入して`TERMINFO_DIRS`へ追加するため、Ghosttyから接続したシェルでも`TERM=xterm-ghostty`のままtmuxを起動できます。Ghostty本体はUbuntuへ導入しません。

マシン固有の設定はGit管理外の次のファイルへ記述します。

- `~/.zshrc.local`
- `~/.config/ghostty/local.config`

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

## `.zshrc.local`からの移行

Java、Android SDK、Google Cloud SDK、Ghostty背景設定はリポジトリへ取り込み済みです。Node.js、pnpm、Bun、Python、uv、Yarn、kubectl、Helm、Terraformはmiseへ移行済みです。既存の`~/.zshrc.local`に同じ設定が残っている場合は、Nix、mise、chezmoiの適用を確認してから該当部分を削除してください。
