# Development tools interactive configuration

# Kiro terminal integration
if [[ "$TERM_PROGRAM" == "kiro" ]] && command -v kiro >/dev/null 2>&1; then
  . "$(kiro --locate-shell-integration-path zsh)"
fi

# mise (polyglot runtime manager)
if [[ -x "$HOME/.nix-profile/bin/mise" ]]; then
  eval "$("$HOME/.nix-profile/bin/mise" activate zsh)"
elif command -v mise >/dev/null 2>&1; then
  eval "$(command mise activate zsh)"
fi

# Antigravity
if [[ -d "$HOME/.antigravity/antigravity/bin" ]]; then
  export PATH="$HOME/.antigravity/antigravity/bin:$PATH"
fi

# gpg
# Require gpg, pinentry-mac
export GPG_TTY=$(tty)
