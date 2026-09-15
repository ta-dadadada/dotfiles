# AGENTS.md

## プロジェクト概要

このリポジトリは、chezmoi のソースディレクトリとして使う dotfiles 集である。
基盤 CLI は Nix と Home Manager、バージョン管理対象のランタイムと開発ツールは mise、ユーザー設定は chezmoi、GUI アプリなどは Homebrew で管理する。

対応環境は次の 2 種類に限定する。

- Apple Silicon macOS (`darwin/arm64`, Nix では `aarch64-darwin`)
- x86_64 Ubuntu (`linux/amd64`, Nix では `x86_64-linux`)

変更前に `README.md` と対象ファイルを読む。リポジトリ内のファイルは chezmoi のソース状態であり、展開先のホームディレクトリを直接編集しない。

## 主要な構成

- `dot_config/nix/`: Home Manager の Flake、パッケージ一覧、固定済み lock file
- `dot_config/mise/`: mise のグローバルツール設定
- `dot_zshenv`, `dot_zshenv.d/`: 環境変数と PATH。非対話シェルでも安全に読み込める内容にする
- `dot_zshrc`, `dot_zshrc.d/`: 対話シェルの初期化、エイリアス、補助関数
- `dot_config/ghostty/`, `dot_tmux.conf`, `dot_emacs`: 各アプリケーションの設定
- `run_onchange_after_20-apply-home-manager.sh.tmpl`: Home Manager の activation package をビルドして適用するスクリプト
- `run_onchange_after_25-install-mise-tools.sh.tmpl`: グローバル設定に指定されたmiseツールを導入するスクリプト
- `run_onchange_after_27-retire-volta.sh.tmpl`: miseの代替コマンドを確認してVoltaを退避するスクリプト
- `run_onchange_after_30-configure-git-hooks.sh.tmpl`: このリポジトリの Git hook を有効化するスクリプト
- `.githooks/pre-commit`: ステージ済みファイルに対する Trivy secret scan
- `.githooks/pre-push`: push対象refに対する Trivy secret scan
- `.github/workflows/nix.yml`: macOS と Ubuntu でテンプレート展開、秘密情報検査、Flake 検査、miseツール解決、Home Manager ビルドを行う CI

chezmoi の命名規則により、`dot_foo` は展開時に `.foo` になる。`.tmpl` は Go template であり、通常の設定ファイルとして扱わない。

## 設計上の境界

- Home Manager は CLI パッケージの導入に使う。zsh、Git、tmux などの設定ファイルを Home Manager から生成しない。
- Nix は mise 自身、chezmoi、Git、ghq などの基盤 CLI を管理する。
- mise は Node.js、pnpm、Bun、Python、uv、kubectl、Helm、Terraform、Granted など、バージョン固定やプロジェクト単位の切り替えが必要なツールを管理する。
- 同じコマンドを Nix、mise、Homebrew の複数から導入しない。割り当ての詳細は `docs/tool-management.md` に従う。
- Android SDK はリポジトリから導入せず、OS ごとのローカルインストール先を検出する。
- マシン固有の設定や秘密情報はコミットしない。必要な設定は `~/.zshrc.local` または `~/.config/ghostty/local.config` に置く。
- `home.stateVersion` は通常の依存更新では変更しない。

この境界を変える必要がある場合は、実装だけでなく `README.md` の管理範囲とセットアップ手順も更新する。

## 実装規約

### chezmoi テンプレート

- OS 差分は `.chezmoi.os`、CPU 差分は `.chezmoi.arch` で明示する。
- ユーザー名やホームディレクトリを固定値にしない。`.chezmoi.username`、`.chezmoi.homeDir`、`joinPath` を使う。
- シェルへ値を埋め込むときは `quote`、Nix 文字列へ埋め込むときは `toJson` など、対象言語に合うエスケープを行う。
- テンプレート変更後は、少なくとも現在のプラットフォームで展開結果を確認する。OS 分岐を変えた場合は CI の macOS と Ubuntu の両方を検証対象と考える。

### シェル設定とスクリプト

- `.zshenv.d` には環境変数と PATH、`.zshrc.d` には対話シェル専用の初期化を置く。
- 任意ツールの初期化は `command -v` やファイル存在確認で保護し、未導入環境でもシェル起動を壊さない。
- `run_*` と Git hook は POSIX `sh` を維持し、`set -eu` を使う。zsh 固有の構文を混ぜない。
- `run_onchange_after_*` の番号は適用順を表す。依存ファイルを変更したときに再実行されるよう、先頭のハッシュ用コメントも同期する。
- 既存の日本語コメントは簡潔に保ち、処理の理由や管理境界が分かる場合だけ追加する。

### Nix と依存更新

- CLI パッケージは `dot_config/nix/home.nix` の `home.packages` に追加する。
- mise 管理のツールは `dot_config/mise/config.toml` に互換性を保つリリース系列で追加し、Nix の `home.packages` には追加しない。配布制約がある場合だけ理由を文書化して正確なバージョンに固定する。
- unfree パッケージは必要なものだけ `allowUnfreePredicate` に列挙する。
- `dot_config/nix/flake.lock` は手編集しない。`README.md` の一時 Flake を使う手順で更新する。
- nixpkgs と Home Manager は同じ安定版系列にそろえる。
- GitHub Actions はリリースタグではなくコミット SHA で固定し、同じ行のバージョンコメントも更新する。

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

展開結果の `.config/nix/flake.nix`、OS 条件付き設定、変更した dotfile を確認する。一時ディレクトリは確認後に削除してよい。

### 秘密情報検査

```sh
trivy fs --config trivy.yaml .
```

Markdown も検査対象である。誤検知を除外するときは値を安易に許可せず、`trivy-secret.yaml` に理由が分かる限定的なルールを追加する。

### Nix の完全確認

テンプレートを一時ディレクトリへ展開した後、CI 相当の確認を行う。

```sh
nix flake check "$destination/.config/nix"
nix build "$destination/.config/nix#homeConfigurations.default.activationPackage"
```

ローカルに Nix または Trivy がない場合は、実行できなかった確認を明記し、GitHub Actions の macOS/Ubuntu 両ジョブで補完する。検証目的で `chezmoi apply` や Home Manager の activation を実環境へ適用しない。

## 変更時の注意

- 秘密情報、個人用パス、ユーザー名、端末固有の値を追加しない。
- 無関係なユーザー変更を巻き戻さない。作業前後に `git status --short` と `git diff` を確認する。
- 設定の管理主体、導入手順、日常操作が変わる場合は `README.md` を同じ変更で更新する。
- コミットメッセージは履歴に合わせ、`feat(scope): ...`、`fix(scope): ...`、`docs: ...` などの簡潔な形式を使う。
- 変更完了時は、変更したファイル、利用者への影響、実行した検証、未実行の検証を報告する。
