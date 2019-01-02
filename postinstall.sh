#!/bin/bash

DOTFILES_DIR="$HOME/dev/dotfiles"

source "$DOTFILES_DIR/helpers.sh"

function install_NODE_ENV {
  echo "Installing node, nvm & yarn"
  nvm install 10
  nvm alias default 10
  curl -o- -L https://yarnpkg.com/install.sh | bash
  # yarn adds itself to the $PATH when being installed
  # but yarn path is already exported in ~/.zsh/exports.zsh
  # the following line removes that from ~/.zshrc
  sed -i -e "/export\sPATH=\"\$HOME\/\.yarn\/bin:\$PATH/d" "$DOTFILES_DIR/zsh/zshrc"
  echo ""
}

function install_VIM_PLUGINS {
  # only run if yarn & npm are installed
  if hash npm 2>/dev/null && hash yarn 2>/dev/null; then
    echo "Installing vim plugins"
    vim +PlugInstall +qall
    # fzf adds a a call to source fzf to the ~/.zshrc, since it's already in
    # ~/.zsh/sources.zsh the following lines removes that from ~/.zshrc
    sed -i -e "/\n\[\s-f\s~\/\.fzf\.zsh\s\]\s&&\ssource\s~\/\.fzf\.zsh/d" "$DOTFILES_DIR/zsh/zshrc"

    echo ""

    echo "Installing YouCompleteMe (for Go, JS, TS), tern_for_vim and typescript"
    cd ~/.vim/bundle/YouCompleteMe
    ./install.py --gocode-completer --tern-completer --clang-completer --rust-completer
    cd ~/.vim/bundle/tern_for_vim
    yarn
    yarn global add typescript livedown
    echo ""

    echo "Installing vim-elm dependencies"
    yarn global add elm elm-test elm-oracle elm-format create-elm-app
    echo ""

    echo "Installing nerd-fonts"
    git clone --depth 1 git@github.com:ryanoasis/nerd-fonts.git ~/dev/nerd-fonts
    cd ~/dev/nerd-fonts
    ./install.sh 'Go-Mono'
    cd ~
    echo ""

    # TODO: move this from here, it's not vim related
    echo "Installing other programs from npm"
    yarn global add npm-ls-scripts bs-platform serve diff-so-fancy
    echo ""

    echo "Installing vim-go dependencies"
    vim +GoInstallBinaries +qall
    echo ""
  else
    echo "In order to install vim packages you first need node & npm installed"
  fi
}

function main {
  install_NODE_ENV

  install_VIM_PLUGINS
 
  # after calling sed to remove something from the
  # file that is symlinked the symlink gets broken
  echo "Relinking ~/.zsrc"
  link "$DOTFILES_DIR/zsh" ~/.zsh
  echo "All done!"
  echo ""
}

main
