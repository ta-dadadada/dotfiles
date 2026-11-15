#!/bin/sh
# 実環境へ適用せず、両OSのテンプレートとシェルを検査する。
set -eu
root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM
chezmoi_bin=${CHEZMOI_BIN:-chezmoi}
for platform in darwin linux; do
  case "$platform" in darwin) arch=arm64 ;; linux) arch=amd64 ;; esac
  destination="$work/$platform"
  mkdir -p "$destination"
  data=$(printf '{"chezmoi":{"os":"%s","arch":"%s","homeDir":"%s"}}' "$platform" "$arch" "$destination")
  "$chezmoi_bin" --source "$root" --destination "$destination" \
    --config /dev/null --config-format toml --persistent-state "$work/state-$platform.boltdb" \
    --override-data "$data" --no-tty apply --exclude scripts
  for file in "$destination/.zshenv" "$destination/.zshrc" "$destination/.fzf.zsh" \
    "$destination/.zshenv.d/"*.zsh "$destination/.zshrc.d/"*.zsh; do
    zsh -n "$file"
  done
  for file in run_*.tmpl dot_local/bin/executable_*.tmpl; do
    rendered="$work/$(basename "$file").$platform.sh"
    "$chezmoi_bin" --source "$root" --destination "$destination" \
      --config /dev/null --config-format toml --override-data "$data" execute-template -f "$file" > "$rendered"
    sh -n "$rendered"
    shellcheck -s sh "$rendered"
  done
  test ! -e "$destination/scripts"
  test ! -e "$destination/assets"
  test ! -e "$destination/.config/nix"
  if [ "$platform" = linux ]; then
    sh "$work/run_onchange_after_20-install-terminfo.sh.tmpl.linux.sh"
    TERMINFO_DIRS="$destination/.local/share/terminfo:" infocmp -x xterm-ghostty >/dev/null
  fi
done
shellcheck scripts/*.sh .githooks/pre-commit .githooks/pre-push
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -v
