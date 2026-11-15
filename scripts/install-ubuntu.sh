#!/bin/sh
set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
# shellcheck disable=SC1091
. /etc/os-release
if [ "$ID" != ubuntu ] || [ "$(uname -m)" != x86_64 ]; then
  echo "This script requires x86_64 Ubuntu." >&2
  exit 1
fi
case "$VERSION_ID" in
  24.04|26.04) ;;
  *) echo "Supported Ubuntu releases: 24.04, 26.04." >&2; exit 1 ;;
esac

sudo apt-get update
# 一覧はリポジトリの固定ファイル。コメントと空行を除いて引数へ展開する。
# shellcheck disable=SC2046
set -- $(sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d' "$root/.chezmoitemplates/packages/ubuntu.txt")
sudo apt-get install -y --no-install-recommends "$@"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM
# 追加リポジトリはmiseとGoogle公式に限定し、それぞれ専用鍵へ紐付ける。
sudo install -d -m 755 /etc/apt/keyrings
curl -fsSL https://mise.jdx.dev/gpg-key.pub -o "$work/mise.asc"
gpg --batch --dearmor --output "$work/mise.gpg" "$work/mise.asc"
sudo install -m 644 "$work/mise.gpg" /etc/apt/keyrings/dotfiles-mise.gpg
printf '%s\n' 'deb [arch=amd64 signed-by=/etc/apt/keyrings/dotfiles-mise.gpg] https://mise.jdx.dev/deb stable main' > "$work/mise.list"
sudo install -m 644 "$work/mise.list" /etc/apt/sources.list.d/dotfiles-mise.list
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg -o "$work/google.asc"
gpg --batch --dearmor --output "$work/google.gpg" "$work/google.asc"
sudo install -m 644 "$work/google.gpg" /etc/apt/keyrings/dotfiles-google-cloud.gpg
printf '%s\n' 'deb [arch=amd64 signed-by=/etc/apt/keyrings/dotfiles-google-cloud.gpg] https://packages.cloud.google.com/apt cloud-sdk main' > "$work/google.list"
sudo install -m 644 "$work/google.list" /etc/apt/sources.list.d/dotfiles-google-cloud.list
sudo apt-get update
sudo apt-get install -y --no-install-recommends mise google-cloud-cli
