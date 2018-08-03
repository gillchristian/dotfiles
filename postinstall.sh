#!/bin/bash

DOTFILES_DIR="$HOME/dev/dotfiles"

source "$DOTFILES_DIR/helpers.sh"

function install_NODE_ENV {
  echo "Installing node, nvm & yarn"
  nvm install 8
  nvm alias default 8
  curl -o- -L https://yarnpkg.com/install.sh | bash
  # yarn adds itself to the $PATH when being installed
  # but yarn path is already exported in ~/.zsh/exports.zsh
  # the following line removes that from ~/.zshrc
  sed -i -e "/export\sPATH=\"\$HOME\/\.yarn\/bin:\$PATH/d" "$DOTFILES_DIR/zsh/zshrc"
  echo ""
}

function install_VIM_PLUGINS {
  # only run if npm is installed
  if hash npm 2>/dev/null; then
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
    npm install
    npm install -g typescript livedown
    echo ""

    echo "Installing vim-elm dependencies"
    npm install -g elm elm-test elm-oracle elm-format
    echo ""

    echo "Installing nerd-fonts"
    git clone --depth 1 git@github.com:ryanoasis/nerd-fonts.git ~/dev
    cd ~/dev/nerd-fonts
    ./install.sh 'Go Mono'
    cd ~
    echo ""

    # TODO: move this from here, it's not vim related
    echo "Installing other programs from npm"
    npm install -g tldr npm-ls-scripts
    echo ""
  else
    echo "In order to install vim packages you first need node & npm installed"
  fi
}

function install_DOCKER_COMPOSE {
  echo "Installing docker-compose"
  sudo touch /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
  touch /temp/docker-compose-binary
  curl -L "https://github.com/docker/compose/releases/download/1.16.1/docker-compose-$(uname -s)-$(uname -m)" > /temp/docker-compose-binary
  sudo mv /temp/docker-compose-binary /usr/local/bin/docker-compose
  echo ""
}

function install_DOCKER {
  echo "Installing Docker"
  sudo apt-get remove docker docker-engine docker.io
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  echo "Verifying fingerprint"
  sudo apt-key fingerprint 0EBFCD88
  sudo add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) \
    stable"
  sudo apt-get update
  sudo apt-get install docker-ce
  echo "Verifying Docker installation"
  sudo docker run hello-world
  sudo groupadd docker
  sudo usermod -aG docker $USER
  sudo systemctl enable docker

 install_DOCKER_COMPOSE 

  echo "After the installation restart the computer and run \`\$ docker run hello-world\`"
  echo ""
}

function main {
  install_NODE_ENV
  install_VIM_PLUGINS
  install_DOCKER 

  # after calling sed to remove something from the
  # file that is symlinked the symlink gets broken
  echo "Relinking ~/.zsrc"
  link "$DOTFILES_DIR/zsh" ~/.zsh
  echo "All done!"
  echo ""
}
