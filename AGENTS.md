# AGENTS.md

## プロジェクト概要

このリポジトリは、chezmoi のソースディレクトリとして使う dotfiles 集である。
macOSの基盤CLIはHomebrew、Ubuntuの基盤CLIはapt、共通CLIとランタイムはmise、ユーザー設定はchezmoiで管理する。NixとHome Managerは使用しない。

対応環境は次の 2 種類に限定する。

- Apple Silicon macOS (`darwin/arm64`)
- x86_64 Ubuntu (`linux/amd64`)

変更前に `README.md` と対象ファイルを読む。リポジトリ内のファイルは chezmoi のソース状態であり、展開先のホームディレクトリを直接編集しない。

## 主要な構成

- `.chezmoitemplates/packages/`: macOSのBrewfileとUbuntuのaptパッケージ一覧
- `scripts/bootstrap.sh`: OSパッケージ、mise経由のchezmoi、設定適用の入口
- `scripts/check-environment.sh`: 移行後のコマンド・JDK・端末設定の確認
- `scripts/verify.sh`: 両OSの一時展開とシェル・回帰テスト
- `assets/terminfo/`: Ghostty terminfoのソースと配布元・ライセンス
- `dot_config/mise/`: mise のグローバルツール設定
- `dot_zshenv`, `dot_zshenv.d/`: 環境変数と PATH。非対話シェルでも安全に読み込める内容にする
- `dot_zshrc`, `dot_zshrc.d/`: 対話シェルの初期化、エイリアス、補助関数
- `dot_config/ghostty/`, `dot_tmux.conf`, `dot_emacs`: 各アプリケーションの設定
- `dot_local/bin/executable_ssl-doctor.tmpl`: 企業プロキシ環境の証明書設定を診断し、CA バンドルを再生成するコマンド
- `run_onchange_after_15-build-ca-bundle.sh.tmpl`: 企業プロキシの CA を検出し、システム CA と結合したバンドルと Java truststore を生成するスクリプト
- `run_onchange_after_20-install-terminfo.sh.tmpl`: UbuntuのGhostty terminfoをユーザー領域へ導入するスクリプト
- `run_onchange_after_28-refresh-java-truststore.sh.tmpl`: mise導入後にJava truststoreを再確認するスクリプト
- `run_onchange_after_25-install-mise-tools.sh.tmpl`: グローバル設定に指定されたmiseツールを導入するスクリプト
- `run_onchange_after_27-retire-volta.sh.tmpl`: miseの代替コマンドを確認してVoltaを退避するスクリプト
- `run_onchange_after_30-configure-git-hooks.sh.tmpl`: このリポジトリの Git hook を有効化するスクリプト
- `.githooks/pre-commit`: ステージ済みファイルに対する Trivy secret scan
- `.githooks/pre-push`: push対象refに対する Trivy secret scan
- `.github/workflows/environment.yml`: macOSとUbuntuでOSパッケージ・miseツールの導入、一時展開、シェル起動と秘密情報を検査するCI

chezmoi の命名規則により、`dot_foo` は展開時に `.foo` になる。`.tmpl` は Go template であり、通常の設定ファイルとして扱わない。

## 設計上の境界

- OSの基盤はmacOSでHomebrew、Ubuntuでaptを使う。UbuntuへHomebrewを導入しない。
- mise自身はOSパッケージから導入する。chezmoi、共通CLI、Java、ランタイムと開発ツールはmiseで管理する。
- 同じコマンドの直接の管理元は一つにする。OSパッケージの依存として入るランタイムは強制削除せず、開発用コマンドはmiseを優先する。
- `chezmoi apply`でsudoやOSパッケージの更新を実行しない。明示的なbootstrap操作に分ける。
- 割り当ての詳細は `docs/tool-management.md`、既存環境の移行は `docs/migration-from-nix.md` に従う。
- Android SDK はリポジトリから導入せず、OS ごとのローカルインストール先を検出する。
- マシン固有の設定や秘密情報はコミットしない。必要な設定は `~/.zshrc.local` または `~/.config/ghostty/local.config` に置く。
- 企業プロキシの CA 証明書はリポジトリに含めず、標準パスから検出する。検出できない環境では何も生成せず、環境変数も設定しない。

この境界を変える必要がある場合は、実装だけでなく `README.md` の管理範囲とセットアップ手順も更新する。

## 実装規約

### chezmoi テンプレート

- OS 差分は `.chezmoi.os`、CPU 差分は `.chezmoi.arch` で明示する。
- ユーザー名やホームディレクトリを固定値にしない。`.chezmoi.username`、`.chezmoi.homeDir`、`joinPath` を使う。
- シェルへ値を埋め込むときは `quote`、その他の文字列も対象言語に合うエスケープを行う。
- テンプレート変更後は、少なくとも現在のプラットフォームで展開結果を確認する。OS 分岐を変えた場合は CI の macOS と Ubuntu の両方を検証対象と考える。

### シェル設定とスクリプト

- `.zshenv.d` には環境変数と PATH、`.zshrc.d` には対話シェル専用の初期化を置く。
- 任意ツールの初期化は `command -v` やファイル存在確認で保護し、未導入環境でもシェル起動を壊さない。
- `run_*` と Git hook は POSIX `sh` を維持し、`set -eu` を使う。zsh 固有の構文を混ぜない。
- `run_onchange_after_*` の番号は適用順を表す。依存ファイルを変更したときに再実行されるよう、先頭のハッシュ用コメントも同期する。
- 既存の日本語コメントは簡潔に保ち、処理の理由や管理境界が分かる場合だけ追加する。

### パッケージと依存更新

- macOSの基盤CLIは `.chezmoitemplates/packages/Brewfile`、Ubuntuは `.chezmoitemplates/packages/ubuntu.txt` に追加する。
- 共通CLIとランタイムは `dot_config/mise/config.toml` に互換性を保つリリース系列で追加する。0.xはminor系列を使い、配布制約がある場合だけ理由付きで正確なバージョンへ固定する。
- Ubuntuの追加aptリポジトリはmiseとGoogle公式を基本とし、専用の署名鍵で対象を限定する。
- 古いツールやキャッシュの削除は更新と分ける。Nixの実環境への適用や撤去を検証に使わない。
- GitHub ActionsはコミットSHAで固定し、同じ行のバージョンコメントも更新する。

## 検証

変更範囲に応じて、以下を実行する。

### 基本確認

```sh
git diff --check
shellcheck .githooks/pre-commit .githooks/pre-push
```

シェルファイルを変更した場合は、対象に応じて `sh -n` または `zsh -n` も実行する。テンプレートファイルはそのまま構文検査せず、展開後のファイルを検査する。

### chezmoi の展開確認

CI と同様に、ホームディレクトリではない一時ディレクトリへ展開する。

```sh
destination=$(mktemp -d)
chezmoi --source "$PWD" --destination "$destination" --no-tty apply --exclude scripts
```

展開結果のmise設定、OS条件付き設定、変更したdotfileを確認する。一時ディレクトリは確認後に削除してよい。

### 秘密情報検査

```sh
trivy fs --config trivy.yaml .
```

Markdown も検査対象である。誤検知を除外するときは値を安易に許可せず、`trivy-secret.yaml` に理由が分かる限定的なルールを追加する。

### 両OSの確認

```sh
sh scripts/verify.sh
```

一時展開、展開後のShellCheckと構文検査、非対話シェルの回帰テスト、Ghostty terminfoを確認する。
OSパッケージの実導入と共通CLIの起動はGitHub ActionsのmacOS/Ubuntu両ジョブで確認する。ローカルで実行できなかった検証は明記する。
検証目的でbootstrapを実環境へ適用しない。別OSのテンプレート展開だけで実行確認済みとは扱わない。

## 変更時の注意

- 秘密情報、個人用パス、ユーザー名、端末固有の値を追加しない。
- 無関係なユーザー変更を巻き戻さない。作業前後に `git status --short` と `git diff` を確認する。
- 設定の管理主体、導入手順、日常操作が変わる場合は `README.md` を同じ変更で更新する。
- コミットメッセージは履歴に合わせ、`feat(scope): ...`、`fix(scope): ...`、`docs: ...` などの簡潔な形式を使う。
- 変更完了時は、変更したファイル、利用者への影響、実行した検証、未実行の検証を報告する。
