# shimsは呼び出したプロセスにだけ環境を渡すため、非対話シェルにもJAVA_HOMEを設定する。
if command -v mise >/dev/null 2>&1; then
  mise_java_home=$(mise where java 2>/dev/null) || mise_java_home=""
  if [[ -n "$mise_java_home" && -x "$mise_java_home/bin/java" ]]; then
    export JAVA_HOME="$mise_java_home"
  fi
  unset mise_java_home
fi

# Ubuntuではユーザー領域のGhostty terminfoを参照する。
if [[ -d "$HOME/.local/share/terminfo" ]]; then
  typeset -aU terminfo_dirs
  terminfo_dirs=("$HOME/.local/share/terminfo" "${(@s.:.)TERMINFO_DIRS}" /etc/terminfo /lib/terminfo /usr/share/terminfo)
  terminfo_dirs=("${(@)terminfo_dirs:#/nix/*}")
  terminfo_dirs=("${(@)terminfo_dirs:#$HOME/.nix-profile/*}")
  export TERMINFO_DIRS="${(j.:.)terminfo_dirs}"
  unset terminfo_dirs
fi
