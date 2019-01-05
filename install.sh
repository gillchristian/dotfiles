#!/bin/bash

DOTFILES_DIR="$HOME/dev/dotfiles"
XDG_CONFIG_HOME="$HOME/.config"

source "$DOTFILES_DIR/helpers.sh"

function install_PACKAGES {
  echo "Updating packages repository"

  # vim 8 repository
  sudo add-apt-repository -y ppa:jonathonf/vim

  sudo apt update
  echo ""

  echo "Installing packages ..."
  # general
  sudo apt install -y zip ubuntu-restricted-extras unzip rar git vim vim-gnome zsh git-core indicator-multiload
  sudo apt install -y bison curl make binutils gcc build-essential xclip silversearcher-ag asciinema
  sudo apt install -y jq git-extras tmux

  # docker
  sudo apt install -y apt-transport-https ca-certificates software-properties-common

  # vim
  sudo apt install -y cmake python3-dev python-dev exuberant-ctags mercurial libmagic-dev

  # alacritty
  sudo apt install -y libfreetype6-dev libfontconfig1-dev
    
  echo ""
}

function install_HASKELL {
  # Install Haskell's Stack
  echo "Installing Haskell's Stack"
  curl -sSL https://get.haskellstack.org/ | sh

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

function install_ANTIBODY {
  echo "Installing Antibody and adding config"
  curl -sL git.io/antibody | sh -s
  echo ""

  echo "Installing plugins with antibody"
  antibody bundle < "$DOTFILES_DIR/zsh/antibodyrc" > ~/.antibody_plugins.sh
  antibody update
  echo ""
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

function install_TMUX {
  link "$DOTFILES_DIR/tmux/tmux.conf" "$HOME/.tmux.conf"
}


function install_CONFIG {
  install_ZSH

  install_ANTIBODY

  install_GIT

  install_SSH

  install_VIM

  install_GOLANG

  install_RUST

  install_HASKELL

  install_DOCKER

  install_TMUX
}

function main {
  install_PACKAGES

  install_CONFIG
}

install_RUST
