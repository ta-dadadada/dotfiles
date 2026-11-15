# 移行前の親シェルやシステム初期化から引き継いだNixのPATHを除く。
# 旧ファイルを上書きするため名前を維持する。Nix本体やプロファイルは削除しない。
path=("${(@)path:#/nix/*}")
path=("${(@)path:#$HOME/.nix-profile/bin}")
path=("${(@)path:#$HOME/.local/state/nix/profiles/*/bin}")
# Nix撤去後に存在しないCAやJDKを参照しない。独自の設定は維持する。
for nix_var in JAVA_HOME SSL_CERT_FILE SSL_CERT_DIR CURL_CA_BUNDLE GIT_SSL_CAINFO \
  REQUESTS_CA_BUNDLE PIP_CERT NODE_EXTRA_CA_CERTS AWS_CA_BUNDLE \
  CARGO_HTTP_CAINFO GRPC_DEFAULT_SSL_ROOTS_FILE_PATH; do
  case "${(P)nix_var:-}" in
    /nix/*|"$HOME"/.nix-profile/*|"$HOME"/.local/state/nix/*)
      unset "$nix_var"
      ;;
  esac
done
unset nix_var
unset NIX_SSL_CERT_FILE

# 新しいterminfoの導入前でも旧パスを除く。空要素は既定の検索先を表す。
if [[ -n "${TERMINFO_DIRS:-}" ]]; then
  nix_terminfo_dirs=("${(@s.:.)TERMINFO_DIRS}")
  nix_terminfo_dirs=("${(@)nix_terminfo_dirs:#/nix/*}")
  nix_terminfo_dirs=("${(@)nix_terminfo_dirs:#$HOME/.nix-profile/*}")
  nix_terminfo_dirs=("${(@)nix_terminfo_dirs:#$HOME/.local/state/nix/*}")
  export TERMINFO_DIRS="${(j.:.)nix_terminfo_dirs}"
  unset nix_terminfo_dirs
fi
