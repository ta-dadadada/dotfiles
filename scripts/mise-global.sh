#!/bin/sh
# 共通設定とマシン固有設定を通常どおり結合し、作業中のプロジェクトだけを除外する。
set -eu
mise_bin=$(command -v mise)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM
cd "$work"
"$mise_bin" "$@"
