#!/bin/bash

# Reference: https://github.com/HeroCC/dotfiles

DOTFILES_DIR="$HOME/dev/dotfiles"

function link {
  if [[ -e "$2" ]]; then
    echo "$2 already exists, if it is a symlink it will be deleted"
    if [[ -h "$2" ]]; then
      rm -rf "$2"
      ln -s $1 $2
    else
      echo "Not a symlink, renaming and linking"
      mv -f "$2" "$2_old"
      ln -s $1 $2
    fi
  else
    ln -s $1 $2
  fi
}

function update {
  sudo apt-get install -y "$@"
}

function installConfig {
  # ZSH
  echo "Updating and installing ZSH config"
  update zsh
  link $DOTFILE_DIR/zsh ~/.zsh
  link $DOTFILE_DIR/zsh/zshrc ~/.zshrc
  if [ "$SHELL" != "/usr/bin/zsh" ]; then
    chsh -s $(which zsh)
  fi
  echo ""

  # Antigen 
  echo "Installing antigen"
  mkdir ~/antigen
  curl -L git.io/antigen > ~/antigen/antigen.zsh
  link $DOTFILES_DIR/zsh/antigenrc ~/.antigenrc
  echo ""

  # Git
  update git
  echo "Installing Git Config"
  link $DOTFILE_DIR/git/gitconfig ~/.gitconfig
  link $DOTFILE_DIR/git/gitignore_global ~/.gitignore_global
  echo ""

  # SSH
  echo "Updating and installing SSH Config"
  update openssh-client
  update openssh-server
  mkdir -p ~/.ssh/
  link $DOTFILE_DIR/ssh/config ~/.ssh/config
  echo ""

  # VIM
  # TODO: add installation of dependencies
  #   Node
  #   CMake
  #   python-dev
  #   exuberant-ctags
  #   vim-plug
  #   YouCompletMe
  #   tern_for_vim
  echo "Updating and installing VIM config"
  update vim
  link $DOTFILE_DIR/vim ~/.vim
  link $DOTFILE_DIR/vim/vimrc ~/.vimrc
  echo ""
}

installConfig
