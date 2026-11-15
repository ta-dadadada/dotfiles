#!/bin/sh
# 新しいシェルで実行する。読み取りだけで、認証やパッケージ更新は行わない。
set -eu
status=0
for tool in git tmux jq rg direnv gh eza zoxide mise chezmoi ghq fzf bat fd \
  starship trivy aws java javac gcloud node npm npx pnpm yarn yarnpkg bun \
  python uv granted assume assumego devcontainer gemini kubectl helm terraform; do
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
# コマンドが存在するだけのJavaランチャーや、未導入ツールのshimも検出する。
for tool in chezmoi ghq fzf bat fd starship trivy; do
  if ! "$tool" --version >/dev/null 2>&1; then
    echo "FAIL $tool --version"; status=1
  fi
done
for tool in aws gcloud; do
  if ! "$tool" --version >/dev/null 2>&1; then
    echo "FAIL $tool --version"; status=1
  fi
done
if ! java -version >/dev/null 2>&1 || ! javac -version >/dev/null 2>&1; then
  echo "FAIL JDK cannot start"; status=1
fi
if [ -z "${JAVA_HOME:-}" ] || [ ! -x "$JAVA_HOME/bin/javac" ]; then
  echo "FAIL JAVA_HOME does not point to a JDK"; status=1
else
  case "$JAVA_HOME" in /nix/*) echo "FAIL JAVA_HOME still points to Nix"; status=1 ;; esac
fi
if ! fzf --zsh >/dev/null 2>&1; then
  echo "FAIL fzf --zsh"; status=1
fi
if [ "$(uname -s)" = Linux ] && ! infocmp -x xterm-ghostty >/dev/null 2>&1; then
  echo "FAIL Ghostty terminfo is unavailable"; status=1
fi
exit "$status"
