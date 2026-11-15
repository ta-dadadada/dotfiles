#!/bin/sh
# 新しいシェルで実行する。設定されたツールだけを検査し、認証や更新は行わない。
set -eu
root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
status=0
for tool in git tmux jq rg direnv gh eza zoxide mise; do
  if resolved=$(command -v "$tool"); then
    case "$resolved" in
      /nix/*|"$HOME"/.nix-profile/*|"$HOME"/.local/state/nix/*)
        echo "FAIL $tool still resolves to Nix: $resolved"; status=1 ;;
      *) printf 'OK   %s: %s\n' "$tool" "$resolved" ;;
    esac
  else
    echo "FAIL missing command: $tool"; status=1
  fi
done
[ "$status" -eq 0 ] || exit "$status"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT HUP INT TERM
sh "$root/scripts/mise-global.sh" ls --current --json > "$work/tools.json"
jq -r 'to_entries[] | .key as $tool | .value[] | [$tool, (.installed | tostring), .install_path] | @tsv' \
  "$work/tools.json" > "$work/tools.tsv"
while IFS="$(printf '\t')" read -r tool installed install_path; do
  if [ "$installed" != true ] || [ ! -d "$install_path" ]; then
    echo "FAIL configured tool is not installed: $tool"; status=1
  else
    case "$install_path" in
      /nix/*|"$HOME"/.nix-profile/*|"$HOME"/.local/state/nix/*)
        echo "FAIL $tool still uses Nix: $install_path"; status=1 ;;
      *) printf 'OK   %s: %s\n' "$tool" "$install_path" ;;
    esac
  fi
done < "$work/tools.tsv"
selected() {
  jq -e --arg tool "$1" 'has($tool)' "$work/tools.json" >/dev/null
}
for tool in chezmoi ghq fzf bat fd starship trivy; do
  if selected "$tool" && ! sh "$root/scripts/mise-global.sh" exec -- "$tool" --version >/dev/null 2>&1; then
    echo "FAIL $tool --version"; status=1
  fi
done
if selected fzf && ! sh "$root/scripts/mise-global.sh" exec -- fzf --zsh >/dev/null 2>&1; then
  echo "FAIL fzf --zsh"; status=1
fi
if selected java; then
  java_home=$(sh "$root/scripts/mise-global.sh" where java) || java_home=""
  if [ -z "$java_home" ] || [ "${JAVA_HOME:-}" != "$java_home" ] \
    || [ ! -x "$java_home/bin/javac" ] || ! "$java_home/bin/java" -version >/dev/null 2>&1; then
    echo "FAIL selected JDK or JAVA_HOME"; status=1
  fi
fi
if selected aws-cli && ! sh "$root/scripts/mise-global.sh" exec -- aws --version >/dev/null 2>&1; then
  echo "FAIL aws --version"; status=1
fi
if selected granted; then
  for tool in granted assume assumego; do
    if ! sh "$root/scripts/mise-global.sh" which "$tool" >/dev/null 2>&1; then
      echo "FAIL Granted command: $tool"; status=1
    fi
  done
fi
# OSから任意導入したGoogle Cloud CLIは存在する場合だけ検査する。
if command -v gcloud >/dev/null 2>&1 && ! gcloud --version >/dev/null 2>&1; then
  echo "FAIL gcloud --version"; status=1
fi
if [ "$(uname -s)" = Linux ] && ! infocmp -x xterm-ghostty >/dev/null 2>&1; then
  echo "FAIL Ghostty terminfo is unavailable"; status=1
fi
exit "$status"
