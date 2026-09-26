{ config, lib, pkgs, ... }:

{
  home.packages = with pkgs; [
    awscli2
    bat
    chezmoi
    direnv
    eza
    fd
    fzf
    gh
    ghq
    git
    google-cloud-sdk
    jq
    jdk17
    mise
    ripgrep
    starship
    tmux
    trivy
    zoxide
  ] ++ lib.optionals pkgs.stdenv.isLinux [
    pkgs.ghostty.terminfo
  ];

  home.sessionVariables = {
    JAVA_HOME = "${pkgs.jdk17}";
  } // lib.optionalAttrs pkgs.stdenv.isLinux {
    # systemdを経由しない対話シェルでもHome Managerのterminfoを参照する。
    TERMINFO_DIRS = "${config.home.profileDirectory}/share/terminfo:$TERMINFO_DIRS\${TERMINFO_DIRS:+:}/etc/terminfo:/lib/terminfo:/usr/share/terminfo";
  };

  programs.home-manager.enable = true;
}
