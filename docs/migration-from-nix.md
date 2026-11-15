# Nix / Home Managerからの移行

## 対象と順序

Apple Silicon macOSとx86_64 Ubuntuを、OSの基盤パッケージ＋mise＋chezmoiへ移す。
**代替環境の導入と確認を済ませてから、Nixを削除する。** セットアップスクリプトはNix、Home Managerの世代、旧パッケージを自動削除しない。

この手順はNix公式インストーラーの導入を基本とする。Determinate NixやLixなど別のインストーラーを使った場合は、そのインストーラーのアンインストール手順を優先し、下記の手動削除と併用しない。

## 1. 旧環境を記録する

作業前に、Nixを利用するプロセスと別プロジェクトを確認する。`flake.nix`、`shell.nix`、`use nix`、`use flake`、nix-direnv、devboxなどを使うプロジェクトはdotfilesとは別に移行が必要。
共有UbuntuのNixは他の利用者も使っている場合があるため、管理者と利用状況を確認する。

旧dotfilesのコミットと、ローカル変更を含む設定をリポジトリ外へ退避する。退避先には個人設定が含まれるため共有・コミットしない。

```sh
cd "$(chezmoi source-path)"
git status --short
umask 077
backup="$HOME/.local/state/dotfiles-migration/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup"
git rev-parse HEAD > "$backup/dotfiles-commit"
git diff HEAD > "$backup/dotfiles-working-tree.patch"
git ls-files --others --exclude-standard > "$backup/dotfiles-untracked.txt"
for item in .zshenv .zshrc .zshenv.d .zshrc.d .config/mise .config/nix; do
  if [ -e "$HOME/$item" ]; then
    mkdir -p "$backup/$(dirname "$item")"
    cp -R "$HOME/$item" "$backup/$item"
  fi
done
```

未追跡ファイルは一覧だけでは復元できないため、必要なものを別途退避する。

Nix Storeの丸ごとコピーは不要だが、世代とプロファイルは撤去まで残す。コマンドがPATHにない場合は `/nix/var/nix/profiles/default/bin/` や `~/.nix-profile/bin/` の実体を利用できるか確認する。

```sh
home-manager generations > "$backup/home-manager-generations.txt"
mise ls > "$backup/mise-tools.txt"
# macOSのみ
brew list --formula > "$backup/brew-formulae.txt"
brew list --cask > "$backup/brew-casks.txt"
```

使えないコマンドの記録だけ省略してよい。上の `dotfiles-commit` は更新前のコミットを記録する。既に更新済みなら、Git履歴から移行前のコミットを別途控える。

## 2. 新しい構成を導入する

このバージョンのcheckoutを用意する。通常の `chezmoi update` で先に適用せず、ソースだけ更新してからセットアップする。未コミット変更がある場合は保存・確認し、強制リセットしない。

macOSはXcode Command Line ToolsとHomebrew、Ubuntuはgitとsudoが必要。企業プロキシ内ではOSとapt/Homebrewの証明書信頼を先に整える。
既存のHomebrew版miseがある場合は、先に `brew update` と `brew upgrade mise` で更新する。bootstrapは既存のbrewパッケージを更新しない。Ubuntuはbootstrapでmise公式aptのパッケージを導入・更新する。
mise 2026.5.12ではローカル設定による共通ツールの版の上書きが効かない挙動を確認しているため、OSの配布元の最新版を使う。2026.11.8でローカル設定の優先を検証済み。

共通のmise設定はchezmoi、ghq、fzf、bat、fd、starship、Trivyの7種類へ絞っている。これまでグローバルで使っていたNode.js、Python、Java、クラウドCLIなどを引き続き使うマシンでは、適用前に `~/.config/mise/config.local.toml` へ必要な項目を移す。[任意ツールの設定例](../examples/mise/config.local.toml)から必要な行だけを使い、既存のローカル設定を上書きしない。
グローバルは原則 `latest`、Javaは `temurin` とし、プロジェクトで要求される版は各リポジトリで固定する。項目を外しても旧バイナリは自動削除しないが、設定がなくなるとmiseのshimから選択されなくなる。

```sh
cd "$(chezmoi source-path)"
sh scripts/bootstrap.sh
```

- macOSはHomebrewの基盤パッケージを導入する。Google Cloud CLIとGhostty本体は任意導入とする。
- Ubuntuはaptの基盤パッケージとmise公式リポジトリを設定する。Ubuntu標準リポジトリのuniverseが必要。
- 共通CLIとローカル設定で選んだ任意ツールをmiseへ導入する。ローカル設定は初回の適用から読み込み、その後も保持する。
- 設定の競合は内容を見て解決する。マシン固有の設定と認証情報を上書きしない。
- 旧Google Cloud SDK、旧miseバイナリ、重複するbrewパッケージはまだ削除しない。

必要なマシンでは `sh scripts/install-google-cloud.sh`、macOSのGhostty本体は `brew install --cask ghostty` で明示的に導入する。

Ubuntuで同じ公式リポジトリを別のファイル・鍵で登録済みの場合は、重複したsourceと `Signed-By` を確認する。既存の管理者設定を自動削除せず、同じ配布元の設定を一つに整理してから再実行する。

## 3. Nixなしで動くことを確認する

新しいターミナルを開く。UbuntuへのSSH接続も張り直す。古いシェルのPATHやHome Managerの環境変数を引き継いだだけの状態で判断しない。

```sh
cd "$(chezmoi source-path)"
sh scripts/check-environment.sh
zsh -c 'command -v ghq chezmoi; fzf --zsh >/dev/null'
zsh -i -c 'command -v ghq chezmoi; fzf --zsh >/dev/null'
```

確認スクリプトはOSの基盤、有効な共通・ローカル設定で選択されたmiseツール、fzfのシェル連携、UbuntuのGhostty terminfoを検査する。Javaを選んだマシンではJDKと `JAVA_HOME` も確認する。実際の認証やネットワーク接続の成否は別に確認する。
シェル初期化はNixを指す証明書・JDK・terminfoのパスを解除し、Nix以外のローカル設定は保持する。社内CAの生成がない環境でも、旧Nixの証明書パスを継承しない。

- GhosttyからUbuntuへ接続してtmuxを起動できる。
- 普段使うプロジェクトでビルド・テストを実行できる。
- 利用する場合はAWS/GCPのログインとGrantedのロール引き受けを確認する。
- 社内プロキシ環境では `ssl-doctor` を実行する。必要なら `ssl-doctor reset` で新しいJDK用truststoreを再生成する。
- `~/.zshrc.local`、IDE、エディタ、cron、systemdのユーザーサービスにある `/nix/store/...`、`~/.nix-profile` の固定参照を置き換える。

## 4. 重複する導入を整理する

代替コマンドの起動と管理元を確認してから、直接導入した旧パッケージだけを個別に削除する。

macOSでmiseへ移した候補は `chezmoi`、`ghq`、`fzf`、`bat`、`fd`、`starship`、`trivy`、`awscli`。まず `brew list --formula` と `brew uses --installed <formula>` を確認し、該当するものだけ `brew uninstall <formula>` で削除する。依存関係を無視する強制削除や `brew bundle cleanup --force` は使わない。

Ubuntuで旧apt版のbat/fd/fzf等があっても、他パッケージの依存なら強制削除しない。開発用コマンドがmiseを選ぶことを確認する。

`~/.local/bin/mise` の単体版は、macOSで `/opt/homebrew/bin/mise`、Ubuntuで `/usr/bin/mise` が起動することを確認してから退避できる。miseのデータディレクトリは共有して使うため削除しない。
旧 `~/google-cloud-sdk` も、新しい `gcloud` の実体と起動を確認してから退避・削除する。認証情報のある `~/.config/gcloud` は削除しない。

## 5. Nixを撤去する

この段階以降は旧世代へそのまま戻せなくなる。Nixを使うプロセス・サービスを止め、必要な作業が新環境で動くことを確認する。
公式手順: [Uninstalling Nix](https://nix.dev/manual/nix/stable/installation/uninstall.html)

### macOS（公式マルチユーザーインストール）

1. `/etc/zshrc`、`/etc/bashrc`、`/etc/bash.bashrc` を確認し、Nixインストーラーが追加した `nix-daemon.sh` の読み込みブロックだけを除く。導入時のバックアップで丸ごと戻す場合は、その後の変更がないことを確認する。
2. 存在するNixのLaunchDaemonを停止し、対応するplistを削除する。

   ```sh
   sudo launchctl bootout system /Library/LaunchDaemons/org.nixos.nix-daemon.plist
   sudo launchctl bootout system /Library/LaunchDaemons/org.nixos.darwin-store.plist
   ```

   存在しない・既に停止済みのサービスは状態を確認して省略する。plist削除は対象を確認してから行う。

3. `sudo vifs` で `/nix` をマウントする行だけを削除する。`/etc/synthetic.conf` の `nix` 行だけを除く。他のボリューム設定は残す。
4. `dscl . -list /Users` と `dscl . -read /Groups/nixbld` でNix専用ビルドユーザーとグループを確認し、公式手順に従って対象だけを削除する。
5. `diskutil info /nix` と `diskutil apfs list` で、Nix StoreのAPFSボリュームを特定する。確認したNix Storeだけを削除する。

   ```sh
   sudo diskutil apfs deleteVolume /nix
   ```

   `/nix` が既にアンマウントされている場合は、公式手順に従い確認済みのボリューム識別子を指定する。`sudo rm -rf /nix` で代用しない。使用中の場合はプロセスを止め、必要に応じて再起動する。

6. Nix専用の `/etc/nix`、rootのプロファイルと、次のユーザー用ファイルを整理する。

### Ubuntu（公式マルチユーザーインストール）

1. daemonとsocketを停止・無効化する。

   ```sh
   sudo systemctl stop nix-daemon.socket nix-daemon.service
   sudo systemctl disable nix-daemon.socket nix-daemon.service
   ```

2. `/etc/profile.d/nix.sh` とシステムのシェル設定からNixの初期化を除く。`systemctl cat nix-daemon.service nix-daemon.socket` で確認し、Nixインストーラー由来のunit・リンクを整理する。ディストリビューションのパッケージで導入したものはaptで撤去する。
3. Nix専用の `/etc/nix`、`/etc/tmpfiles.d/nix-daemon.conf`、rootのNixプロファイルを整理する。
4. 他の利用者とNix依存プロセスがないことを確認してからStoreを削除する。

   ```sh
   sudo rm -rf /nix
   sudo systemctl daemon-reload
   ```

5. `getent passwd` と `getent group nixbld` でNix専用ビルドユーザー・グループを確認し、該当するものだけ `userdel` / `groupdel` で削除する。人数は固定しない。

### 単一ユーザーインストール

daemonやビルドユーザーがなければ、マルチユーザー用の停止・削除操作は不要。ユーザーのシェルからNix初期化を除き、公式手順に従って自分のStoreとプロファイルを整理する。
macOSでは実際のStoreがAPFSボリュームかどうかを確認し、該当するボリュームの手順に従う。

### 両OS共通のユーザーファイル

Nix撤去後、次のうちNix専用のものを削除できる。`XDG_DATA_HOME`、`XDG_STATE_HOME`、`XDG_CACHE_HOME`を変更している場合は実際の配置先を確認する。

```sh
rm -rf "$HOME/.nix-profile" "$HOME/.nix-defexpr" "$HOME/.nix-channels" \
  "$HOME/.local/share/nix" "$HOME/.local/state/nix" "$HOME/.cache/nix"
```

旧 `~/.config/nix` と `~/.config/home-manager` は新しいchezmoiでは管理しない。他用途の設定がないことを確認し、必要なら退避してから削除する。
旧 `~/.zshenv.d/nix.zsh` は新構成の移行用ファイルで上書きされるため、削除しなくてよい。

## 6. 撤去後の確認

再ログインまたは再起動後に `scripts/check-environment.sh` を再実行する。OSの更新、Git hook、プロキシ環境での接続も確認する。
`du -sh /nix/store` や `df -h` を撤去前後で比較する。APFSは他ボリュームと空き容量を共有するため、測定値をそのまま削減保証とはしない。

## 復旧

Nix撤去前なら、記録した旧dotfilesのcheckoutと退避した設定へ戻し、旧Home Manager世代を再適用できる。新構成で導入したツールの削除は復旧と分け、PATHの重複を確認する。
Nix撤去後はStoreと旧世代が失われるため、Nixの再インストールと旧checkoutからの再構築が必要。設定バックアップだけではStoreを復元できない。
