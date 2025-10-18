# Setup fzf
# ---------
if [[ ! "$PATH" == */opt/homebrew/opt/fzf/bin* ]]; then
  PATH="${PATH:+${PATH}:}/opt/homebrew/opt/fzf/bin"
fi

source <(fzf --zsh)

# FZF configuration
# Use fd for file search (includes hidden files, excludes .git)
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

# Use fd for directory search
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'

# FZF display options
export FZF_DEFAULT_OPTS='
  --height 40%
  --reverse
  --border
  --info=inline
  --prompt="❯ "
  --marker="✓ "
  --preview-window=right:60%:wrap
'

# Ctrl-T: File preview
export FZF_CTRL_T_OPTS='--preview="_fzf_preview {}"'

# Alt-C: Directory preview
export FZF_ALT_C_OPTS='--preview="command ls -la {} | head -200"'
