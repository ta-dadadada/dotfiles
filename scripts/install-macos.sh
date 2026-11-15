#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
if [ "$(uname -s)/$(uname -m)" != Darwin/arm64 ]; then
  echo "This script requires Apple Silicon macOS." >&2
  exit 1
fi
if [ ! -x /opt/homebrew/bin/brew ]; then
  echo "Install Homebrew from https://brew.sh, then rerun scripts/bootstrap.sh." >&2
  exit 1
fi
# 導入時に既存パッケージを一括更新しない。
/opt/homebrew/bin/brew bundle install --no-upgrade --file="$root/.chezmoitemplates/packages/Brewfile"
