#!/bin/bash

DOTFILES_DIR="$HOME/dev/dotfiles"

source "$DOTFILES_DIR/helpers.sh"

function install_NODE_ENV {
  echo "Installing node, nvm & yarn"
  # TODO: this doesn't work (nvm is not defined)
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
    ./install.sh 'FiraCode'
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

function install_HASKELL {
  # Install Haskell's Stack
  echo "Installing Haskell's Stack"
  curl -sSL https://get.haskellstack.org/ | sh

  link "$DOTFILES_DIR/haskell/ghci" ~/.ghci
  mkdir -p ~/.stack/global-project
  link "$DOTFILES_DIR/haskell/global-stack.yml" ~/.stack/global-project/stack.yaml

  chmod go-w ~/.ghci

  stack install hlint hfmt

  echo ""
}

function install_RUST {
  # Install Rust
  echo "Installing Rust"
  curl https://sh.rustup.rs -sSf | sh
  echo ""

  # https://github.com/BurntSushi/ripgrep
  # https://github.com/sharkdp/fd
  # https://github.com/sharkdp/bat
  # https://github.com/dalance/amber
  cargo install ripgrep fd-find bat amber
  cargo install --git https://github.com/jwilm/alacritty
  link "$DOTFILES_DIR/alacritty/alacritty.yml" "$XDG_CONFIG_HOME/alacritty.yml"
  # is 60 enough ?
  sudo update-alternatives --install $(which x-terminal-emulator) x-terminal-emulator $(which alacritty) 60

  echo ""
}

function install_GOLANG {
  # Install Golang
  echo "Installing Go"
  git clone https://github.com/udhos/update-golang ~/dev/update-golang
  cd ~/dev/update-golang
  sudo ./update-golang.sh
  gitUsername=$(git config --global user.name)
  if [ ! -z "$gitUsername" ] ;then
    echo "Creating your Github's go directory"
    mkdir -p $GOPATH/src/github.com/$gitUsername
  fi

  mkdir -p ~/dev/go
  GOPATH="$HOME/dev/go"
  export GO_BIN="$GOPATH/bin:/usr/local/go/bin"

  goinstall "Find Unleashed" github.com/kbrgl/fu
  goinstall gocode github.com/mdempsky/gocode

  # only install td if fetching todos-data is succesful
  # since it's a private repo, so only would work for me
  git clone git@github.com:gillchristian/todos-data.git ~/.todos
  if [ $? -eq 0 ]; then
    goinstall Todos github.com/gillchristian/todos/cmd/td
  fi
}

function install_DOCKER_COMPOSE {
  # TODO: prompt version
  echo "Installing docker-compose"
  sudo touch /usr/local/bin/docker-compose
  touch /tmp/docker-compose-binary
  curl -L "https://github.com/docker/compose/releases/download/1.23.1/docker-compose-$(uname -s)-$(uname -m)" > /tmp/docker-compose-binary
  sudo mv /tmp/docker-compose-binary /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
  echo ""
}

function install_DOCKER {
  echo "Installing Docker"
  sudo apt remove docker docker-engine docker.io
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  echo "Verifying fingerprint"
  sudo apt-key fingerprint 0EBFCD88
  sudo add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) \
    stable"
  sudo apt update
  sudo apt install docker-ce
  echo "Verifying Docker installation"
  sudo docker run hello-world
  sudo groupadd docker
  sudo usermod -aG docker $USER
  sudo systemctl enable docker

  install_DOCKER_COMPOSE

  echo "After the installation restart the computer and run \`\$ docker run hello-world\`"
  echo ""
}

function install_ANTIBODY {
  echo "Installing Antibody and adding config"
  curl -sL git.io/antibody | sh -s
  echo ""

  echo "Installing plugins with antibody"
  antibody bundle < "$DOTFILES_DIR/zsh/antibodyrc" > ~/.antibody_plugins.sh
  antibody update
  echo ""
}

function main {
  install_NODE_ENV

  install_VIM_PLUGINS

  install_HASKELL

  install_GOLANG

  install_DOCKER

  install_RUST
 
  # after calling sed to remove something from the
  # file that is symlinked the symlink gets broken
  echo "Relinking ~/.zsrc"
  link "$DOTFILES_DIR/zsh" ~/.zsh
  echo "All done!"
  echo ""
}

main
