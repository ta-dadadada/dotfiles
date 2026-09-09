# スタンドアロンHome Managerが生成した環境変数を読み込む。
if [[ -r "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" ]]; then
  . "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh"
fi
