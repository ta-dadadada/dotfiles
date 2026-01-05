if command -v "uv" &> /dev/null; then
    export UV_NATIVE_TLS=true
    eval "$(uv generate-shell-completion zsh)"
fi
