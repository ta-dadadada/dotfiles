# ghq: Git repository management

if command -v ghq >/dev/null 2>&1; then
  # ghq-cd: Select repository with fzf and cd
  ghq-cd() {
    local repo
    repo=$(ghq list | fzf --prompt="repo❯ " --preview="ls -la $(ghq root)/{}" --preview-window=right:60%) || return
    local dir=$(ghq root)/$repo
    if [[ -d "$dir" ]]; then
      cd "$dir"
      zle reset-prompt
    fi
  }
  zle -N ghq-cd
  bindkey '^G' ghq-cd
fi
