# Shell aliases

# eza (ls alternative)
if command -v eza >/dev/null 2>&1; then
  alias ls='eza'
  alias ll='eza -lh --git'
  alias la='eza -lha --git'
fi

