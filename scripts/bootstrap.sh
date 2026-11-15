#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
case "${1:-}" in
  ""|--base-only) ;;
  *) echo "usage: scripts/bootstrap.sh [--base-only]" >&2; exit 2 ;;
esac
case "$(uname -s)/$(uname -m)" in
  Darwin/arm64)
    sh "$root/scripts/install-macos.sh"
    mise_bin=/opt/homebrew/bin/mise
    PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
    ;;
  Linux/x86_64)
    sh "$root/scripts/install-ubuntu.sh"
    mise_bin=/usr/bin/mise
    PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
    ;;
  *) echo "Unsupported platform: $(uname -s)/$(uname -m)" >&2; exit 1 ;;
esac
[ "${1:-}" != --base-only ] || exit 0

# 旧Nix版や既存のmise設定に依存せず、このcheckoutの設定でchezmoiを起動する。
export PATH
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM
# 初回適用前のグローバル設定を混ぜず、実行するcheckoutだけを信頼する。
export MISE_CONFIG_DIR="$work/config"
export MISE_TRUSTED_CONFIG_PATHS="$root"
export MISE_GLOBAL_CONFIG_FILE="$root/dot_config/mise/config.toml"
export MISE_GLOBAL_CONFIG_ROOT="$root"
cd "$work"
"$mise_bin" install --yes chezmoi
chezmoi_bin=$("$mise_bin" which chezmoi)
PATH="$(dirname "$chezmoi_bin"):$PATH"
export PATH
"$chezmoi_bin" --source "$root" apply
printf '%s\n' 'Setup complete. Open a new terminal, then run scripts/check-environment.sh.'
