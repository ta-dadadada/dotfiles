{ pkgs, ... }:

{
  home.packages = with pkgs; [
    awscli2
    bat
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
    kubectl
    kubernetes-helm
    ripgrep
    starship
    terraform
    tmux
    trivy
    uv
    zoxide
  ];

  home.sessionVariables.JAVA_HOME = "${pkgs.jdk17}";

  programs.home-manager.enable = true;
}
