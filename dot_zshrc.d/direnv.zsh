# direnvが利用可能な場合だけプロジェクト別環境を読み込む。
if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi
