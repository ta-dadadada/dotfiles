#!/bin/sh
# 必要なマシンでだけ明示的に実行する。通常のbootstrapやchezmoi applyからは呼ばない。
set -eu
case "$(uname -s)/$(uname -m)" in
  Darwin/arm64)
    /opt/homebrew/bin/brew install --cask gcloud-cli
    ;;
  Linux/x86_64)
    # shellcheck disable=SC1091
    . /etc/os-release
    [ "$ID" = ubuntu ] || { echo "This script requires Ubuntu." >&2; exit 1; }
    sudo apt-get update
    sudo apt-get install -y --no-install-recommends ca-certificates curl gnupg
    work=$(mktemp -d)
    trap 'rm -rf "$work"' EXIT HUP INT TERM
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg -o "$work/google.asc"
    gpg --batch --dearmor --output "$work/google.gpg" "$work/google.asc"
    sudo install -d -m 755 /etc/apt/keyrings
    sudo install -m 644 "$work/google.gpg" /etc/apt/keyrings/dotfiles-google-cloud.gpg
    printf '%s\n' 'deb [arch=amd64 signed-by=/etc/apt/keyrings/dotfiles-google-cloud.gpg] https://packages.cloud.google.com/apt cloud-sdk main' > "$work/google.list"
    sudo install -m 644 "$work/google.list" /etc/apt/sources.list.d/dotfiles-google-cloud.list
    sudo apt-get update
    sudo apt-get install -y --no-install-recommends google-cloud-cli
    ;;
  *) echo "Unsupported platform." >&2; exit 1 ;;
esac
