# dotfiles

CLI環境をNixとHome Manager、個人設定をchezmoiで管理するdotfilesです。

## 管理範囲

| 管理ツール | 対象 |
| --- | --- |
| Nix / Home Manager | CLIツール、クラウドCLI |
| chezmoi | zsh、tmux、Ghostty、Emacsなどの個人設定 |
| Volta | Node.js、pnpm |
| Homebrew | macOSのGUIアプリとNixで扱わないパッケージ |

Home Managerはパッケージの導入だけに使用します。zsh、Git、tmuxなどの設定ファイルはHome Managerで生成しません。

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
  run nixpkgs#chezmoi -- init --apply ta-dadadada
```

すでにchezmoiを利用している環境では、Nix導入前に`chezmoi apply`を実行しても構いません。その場合、Nix設定は配置されますがHome Managerの適用は保留されます。Nix導入後にターミナルを再起動し、再度適用します。

```sh
chezmoi apply
```

`run_onchange_after`が`flake.lock`で固定されたHome Managerのactivation packageをビルドし、CLI環境を有効化します。Nix未導入時の実行状態もスクリプト内容に含まれるため、Nix導入後の`chezmoi apply`で再実行されます。

## 管理するCLI

- 基本ツール: Git、tmux、fzf、ripgrep、fd、bat、jq、eza
- 開発支援: gh、ghq、zoxide、starship、uv、direnv、Java 17
- クラウド: kubectl、Helm、Terraform、AWS CLI、Google Cloud SDK

Node.jsとpnpmはVoltaで管理し、Nixとの二重管理を避けます。プロジェクト固有の環境は、各リポジトリのFlakeとdirenvへ段階的に移行します。

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

## 秘密情報の検査

Trivyのsecret scannerをコミット前とGitHub Actionsで実行します。Home Managerの適用時に、このリポジトリの`core.hooksPath`が`.githooks`へ設定されます。

pre-commit hookはGit indexを一時ディレクトリへ展開し、ステージ済みのコミット対象だけを検査します。検出時またはTrivy未導入時はコミットを中止します。

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

Nix版のCLIが正常に動作することを確認してから、重複するHomebrewパッケージを個別に削除します。GUIアプリとHomebrew Caskは今回の移行対象外です。

```sh
command -v git tmux fzf rg fd bat jq eza gh ghq zoxide starship uv direnv java gcloud
```

## zsh設定

`~/.zshenv.d`は環境変数とPATH、`~/.zshrc.d`は対話シェルの設定を管理します。任意ツールの初期化はコマンドが存在する場合だけ行います。

マシン固有の設定はGit管理外の次のファイルへ記述します。

- `~/.zshrc.local`
- `~/.config/ghostty/local.config`

## 主なshell操作

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
- `shuffle_bg`: Ghosttyの背景画像をランダムに切り替える（macOSのみ）

## `.zshrc.local`からの移行

Java、Android SDK、Google Cloud SDK、Ghostty背景設定はリポジトリへ取り込み済みです。既存の`~/.zshrc.local`に同じ設定が残っている場合は、Nixとchezmoiの適用を確認してから該当部分を削除してください。
