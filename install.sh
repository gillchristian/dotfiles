#!/bin/bash

DOTFILES_DIR="$HOME/dev/dotfiles"
XDG_CONFIG_HOME="$HOME/.config"

source "$DOTFILES_DIR/helpers.sh"

function install_PACKAGES {
  echo "Updating packages repository"
  sudo apt update
  echo ""

  echo "Installing packages ..."
  # general
  sudo apt install -y zip ubuntu-restricted-extras unzip rar zsh git-core indicator-multiload cmake
  sudo apt install -y bison curl make binutils gcc build-essential xclip silversearcher-ag asciinema
  sudo apt install -y jq git-extras tmux libtinfo-dev net-tools

  # docker
  sudo apt install -y apt-transport-https ca-certificates software-properties-common

  # vim
  sudo apt install -y cmake python3 python3-dev python-dev exuberant-ctags mercurial libmagic-dev

  # alacritty
  sudo apt-get install pkg-config libfreetype6-dev libfontconfig1-dev libxcb-xfixes0-dev libxkbcommon-dev

  # direnv
  curl -sfL https://direnv.net/install.sh | bash
    
  echo ""
}

function install_VIM {
  echo "Adding VIM config"
  link "$DOTFILES_DIR/vim" ~/.vim
  link "$DOTFILES_DIR/vim/vimrc" ~/.vimrc
  echo ""
}

function install_SSH {
  echo "Updating SSH and adding config"
  update openssh-client
  update openssh-server
  mkdir -p ~/.ssh/
  link "$DOTFILES_DIR/ssh/config" ~/.ssh/config
  echo ""
}

function install_GIT {
  echo "Adding Git config"
  link "$DOTFILES_DIR/git/gitconfig" ~/.gitconfig
  link "$DOTFILES_DIR/git/gitignore_global" ~/.gitignore_global
  echo ""
}

function install_TMUX {
  link "$DOTFILES_DIR/tmux/tmux.conf" "$HOME/.tmux.conf"
}

function install_ZSH {
  echo "Adding ZSH config"
  link "$DOTFILES_DIR/zsh" ~/.zsh
  link "$DOTFILES_DIR/zsh/zshrc" ~/.zshrc
  if [ "$SHELL" != "/usr/bin/zsh" ]; then
    echo "Setting ZSH as the default shell"
    chsh -s $(which zsh)
  fi
  echo ""
}

function main {
  install_PACKAGES

  install_SSH

  install_VIM

  install_GIT

  install_TMUX

  install_ZSH
}

main
