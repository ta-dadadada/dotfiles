# Development tools environment configuration

# Local bin
if [[ -f "$HOME/.local/bin/env" ]]; then
  . "$HOME/.local/bin/env"
fi

# Nix管理のCLIを優先しつつ、ユーザー用コマンドも解決する。
path=("${(@)path:#$HOME/.local/bin}" "$HOME/.local/bin")

# mise shims
# 非対話シェルでもmise管理ツールを解決する。対話シェルでは.zshrc.dのmise activateが
# 実体のパスをshimsより前に置く。miseを起動せずにmiseの既定と同じ場所を参照する。
mise_shims="${MISE_SHIMS_DIR:-${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}/shims}"
if [[ -d "$mise_shims" ]]; then
  path=("$mise_shims" "${(@)path:#$mise_shims}")
fi
unset mise_shims
