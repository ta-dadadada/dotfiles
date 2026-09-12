# Grantedが現在のシェルへ一時認証情報を反映できるようにする。
alias assume='source assume'
alias assume-shell='assume --exec "env GRANTED_SUBSHELL=1 zsh -i"'
export GRANTED_ALIAS_CONFIGURED='true'
