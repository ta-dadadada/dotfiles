# FZF-powered utility functions

# Preview function for fzf
_fzf_preview() {
  local p="$1"
  if [[ -d "$p" ]]; then
    command ls -la "$p" 2>/dev/null | head -200
  elif command -v bat >/dev/null 2>&1 && [[ "$(file -b --mime-type "$p")" == text/* ]]; then
    bat --style=numbers --color=always --line-range=:500 "$p" 2>/dev/null
  else
    file -b "$p"
    head -c 200000 "$p" 2>/dev/null
  fi
}

# ff: Select files and open in editor (multi-select)
ff() {
  local picks
  picks=$(eval "$FZF_DEFAULT_COMMAND" | fzf --multi --preview "_fzf_preview {}") || return
  [[ -n "$picks" ]] && xargs -r -n1 ${EDITOR:-code} <<<"$picks"
}

# fcd: Select directory and cd
fcd() {
  local dir
  dir=$(eval "$FZF_ALT_C_COMMAND" | fzf) || return
  cd "$dir"
}

# rgf: Ripgrep search and jump to line in editor
# Usage: rgf <pattern>
rgf() {
  [[ -z "$1" ]] && { echo "usage: rgf <pattern>"; return 1; }
  local pick file line
  pick=$(rg --line-number --no-heading --color=never "$1" | fzf --preview "_fzf_preview {1}") || return
  file=$(cut -d: -f1 <<<"$pick")
  line=$(cut -d: -f2 <<<"$pick")
  [[ -n "$file" ]] && ${EDITOR:-code} --goto "$file:$line"
}

# hist-select: Select from history with fzf
hist-select() {
  local cmd
  cmd=$(fc -l -n 1 | tac | fzf --tac --no-sort --prompt="history❯ " --preview="echo {}") || return
  LBUFFER="$cmd"
  zle redisplay
}
zle -N hist-select
bindkey '^R' hist-select

# gbs: Git branch switch with fzf
gbs() {
  git rev-parse --git-dir >/dev/null 2>&1 || { echo "not a git repo"; return 1; }
  local b
  b=$(git for-each-ref --format='%(refname:short)' refs/heads refs/remotes \
      | sed 's#^remotes/origin/##' | sort -u | fzf --prompt="branch❯ " \
      --preview="git log --oneline --decorate -n 30 -- {}") || return
  git switch "$b"
}

# gco-any: Select any commit and checkout (detached)
gco-any() {
  git rev-parse --git-dir >/dev/null 2>&1 || { echo "not a git repo"; return 1; }
  local c
  c=$(git log --oneline --decorate | fzf --preview="git show --color=always {1}" | awk '{print $1}') || return
  git checkout "$c"
}

# prc: GitHub PR checkout with gh CLI
prc() {
  command -v gh >/dev/null 2>&1 || { echo "gh not found"; return 1; }
  local num
  num=$(gh pr list --limit 200 --json number,title,headRefName \
        --template '{{range .}}{{printf "%6d  %-30s  %s\n" .number .headRefName .title}}{{"\n"}}{{end}}' \
        | fzf --prompt="PR❯ " --preview="gh pr view {1}") || return
  gh pr checkout "$(awk '{print $1}' <<<"$num")"
}

# pzkill: Select process and kill -9
pzkill() {
  local line pid
  line=$(ps -Ao pid,ppid,stat,user,%cpu,%mem,command | sed 1d | fzf --prompt="kill❯ " --preview="echo {}") || return
  pid=$(awk '{print $1}' <<<"$line")
  [[ -n $pid ]] && kill -9 "$pid"
}
