# Configure spaceship
export PURE_CMD_MAX_EXEC_TIME=1;
export PURE_GIT_PULL=1;
export PURE_GIT_UNTRACKED_DIRTY=1;
export PURE_PROMPT_SYMBOL='$';

# Google Cloud SDK fix
# @reference https://stackoverflow.com/questions/70551641/gcloud-failed-to-load-openssl-1-1-1-not-found
export LD_LIBRARY_PATH=/usr/local/lib

# Editor
export EDITOR=nvim

# Golang's GOPATH & bin
export GOPATH="$HOME/dev/go"

export GO_BIN="$GOPATH/bin:/usr/local/go/bin"

export GO111MODULE=on

# Caddy
export CADDY="$HOME/bin/caddy"

# ~/bin 
export MY_BIN="$HOME/bin"

# rust's cargo
export CARGO="$HOME/.cargo/bin/cargo"

# depot_tools
export DEPOT_TOOLS="$HOME/dev/depot_tools"

# deno
export DENO="$HOME/.deno/bin"

# fnm
export FNM_PATH="$HOME/.fnm"

# .local/bin
LOCAL_BIN="$HOME/.local/bin"

# yarn
export YARN_PATH_STUFF="$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin"

# Haskell's stack
STACK_TOOLS="$(stack path --compiler-tools-bin)"

# DotNET / F#
export DOTNET_ROOT="$HOME/.dotnet"
DOTNET_PATH="$DOTNET_ROOT:$DOTNET_ROOT/tools"

# Java =/
export JAVA_HOME="/usr/lib/jvm/java-8-openjdk-amd64"

FLYCTL_BIN="$HOME/.fly/bin"

# add stuff to PATH

export PATH="$DOTNET_PATH:$YARN_PATH_STUFF:$STACK_TOOLS:$FNM_PATH:$GO_BIN:$CADDY:$MY_BIN:$YARN:$CARGO:$DEPOT_TOOLS:$DENO:$LOCAL_BIN:$FLYCTL_BIN:$PATH"

# xdg config
export XDG_CONFIG_HOME="$HOME/.config"

export TERM=xterm-256color

# locales
export LANGUAGE=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# NVM
export NVM_DIR="$HOME/.config"

# FZF
export FZF_DEFAULT_COMMAND='fd --type f'

# OpenSSL fix for Cargo
export OPENSSL_DIR='/usr/local/ssl'
