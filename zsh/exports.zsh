# Configure spaceship
export PURE_CMD_MAX_EXEC_TIME=1;
export PURE_GIT_PULL=1;
export PURE_GIT_UNTRACKED_DIRTY=1;
export PURE_PROMPT_SYMBOL='$';

# Editor
export EDITOR=vim

# Golang's GOPATH & bin
export GOPATH="$HOME/dev/go"

export GO_BIN="$GOPATH/bin:/usr/local/go/bin"

export GO111MODULE=on

# Caddy
export CADDY="$HOME/bin/caddy"

# ~/bin 
export MY_BIN="$HOME/bin"

# rust's cargo
export CARGO="$HOME/.cargo/bin"

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

# add stuff to PATH
export PATH="$YARN_PATH_STUFF:$FNM_PATH:$GO_BIN:$CADDY:$MY_BIN:$YARN:$CARGO:$DEPOT_TOOLS:$DENO:$LOCAL_BIN:$PATH"

export JAVA_HOME="/usr/lib/jvm/java-8-oracle"

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
