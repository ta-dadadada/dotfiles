# 移行前の親シェルやシステム初期化から引き継いだNixのPATHを除く。
# 旧ファイルを上書きするため名前を維持する。Nix本体やプロファイルは削除しない。
path=("${(@)path:#/nix/*}")
path=("${(@)path:#$HOME/.nix-profile/bin}")
path=("${(@)path:#$HOME/.local/state/nix/profiles/*/bin}")
if [[ "${JAVA_HOME:-}" == /nix/* ]]; then
  unset JAVA_HOME
fi
unset NIX_SSL_CERT_FILE
