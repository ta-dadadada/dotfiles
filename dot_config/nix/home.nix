{ pkgs, ... }:

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
  ];

  home.sessionVariables.JAVA_HOME = "${pkgs.jdk17}";

  programs.home-manager.enable = true;
}
