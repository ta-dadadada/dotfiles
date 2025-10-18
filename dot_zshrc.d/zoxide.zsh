# zoxide: Learning smart cd

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"

  # zfcd: Select from zoxide history with fzf and cd
  zfcd() {
    local d
    d=$(zoxide query -l | fzf --prompt="zoxide❯ " --preview="command ls -la {} | head -200") || return
    cd "$d"
  }
fi
