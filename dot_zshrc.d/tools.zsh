# Development tools interactive configuration

# Kiro terminal integration
if [[ "$TERM_PROGRAM" == "kiro" ]] && command -v kiro >/dev/null 2>&1; then
  . "$(kiro --locate-shell-integration-path zsh)"
fi

# mise (polyglot runtime manager)
if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi

# Added by Antigravity
export PATH="/Users/tadaair/.antigravity/antigravity/bin:$PATH"

# gpg
# Require gpg, pinentry-mac
export GPG_TTY=$(tty)

