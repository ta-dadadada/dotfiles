if command -v "uv" &> /dev/null; then
    export UV_SYSTEM_CERTS=true
    eval "$(uv generate-shell-completion zsh)"
fi
