# Configure spaceship
export PURE_CMD_MAX_EXEC_TIME=1;
export PURE_GIT_PULL=1;
export PURE_GIT_UNTRACKED_DIRTY=1;
export PURE_PROMPT_SYMBOL='$';

# Google Cloud SDK fix
# @reference https://stackoverflow.com/questions/70551641/gcloud-failed-to-load-openssl-1-1-1-not-found
export LD_LIBRARY_PATH=/usr/local/lib

# Editor
export EDITOR=vim

# Golang's GOPATH & bin
export GOPATH="$HOME/.go"

export GOBIN="$GOPATH/bin"

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

NVIM_BIN="$LOCAL_BIN/nvim/bin"

# yarn
export YARN_PATH_STUFF="$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin"

# Haskell's stack
STACK_TOOLS="$(stack-tools-path '8.10.7' '9.2.5' '9.8.2' '9.6.4')"

# DotNET & F#
# export DOTNET_ROOT="$HOME/.dotnet"
# DOTNET_PATH="$DOTNET_ROOT:$DOTNET_ROOT/tools:/opt/homebrew/opt/dotnet@6/bin"
DOTNET_PATH="/opt/homebrew/opt/dotnet@6/bin"

# Java =/
# export JAVA_HOME="/usr/lib/jvm/java-8-openjdk-amd64"

FLYCTL_BIN="$HOME/.fly/bin"

# Racket
export RACKET_BIN="$HOME/racket/bin"

# OpenVPN (brew)
OPEN_VPN_PATH="$(brew --prefix openvpn)/sbin"

# CommandLineTools ?
CLT_PATH="/Library/Developer/CommandLineTools/usr/bin"

# C/C++ Libs: Postgres, libpq, LLVM, libiconv
ICONV_PATH="/opt/homebrew/opt/libiconv/bin"
ICONV_LD="-L/opt/homebrew/opt/libiconv/lib"
ICONV_CPP="-I/opt/homebrew/opt/libiconv/include"

LIBPG_PATH="/opt/homebrew/opt/postgresql@16/bin"
LIBPG_LD="-L/opt/homebrew/opt/postgresql@16/lib"
LIBPG_CPP="-I/opt/homebrew/opt/postgresql@16/include"

LLVM_PATH="/opt/homebrew/opt/llvm@12/bin"
LLVM_LD="-L/opt/homebrew/opt/llvm@12/lib/c++ -Wl,-rpath,/opt/homebrew/opt/llvm@12/lib/c++"
LLVM_CPP="-I/opt/homebrew/opt/llvm@12/include"

LIBPQ_PATH="/opt/homebrew/opt/libpq/bin"
LIBPQ_LD="-L/opt/homebrew/opt/libpq/lib"
LIBPQ_CPP="-I/opt/homebrew/opt/libpq/include"

export LDFLAGS="$ICONV_LD $LIBPG_LD $LLVM_LD $LIBPQ_LD"
export CPPFLAGS="$ICONV_CPP $LIBPG_CPP $LLVM_CPP $LIBPQ_CPP"

# add stuff to PATH

export PATH="$ICONV_PATH:$LLVM_PATH:$CLT_PATH:$OPEN_VPN_PATH:$PG_PATH:$LIBPQ_PATH:$NVIM_BIN:$RACKET_BIN:$DOTNET_PATH:$YARN_PATH_STUFF:$STACK_TOOLS:$FNM_PATH:$GOBIN:$CADDY:$MY_BIN:$YARN:$CARGO:$DEPOT_TOOLS:$DENO:$LOCAL_BIN:$FLYCTL_BIN:$PATH"

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
export OPENSSL_DIR=/opt/homebrew/opt/openssl@1.1
export OPENSSL_LIB_DIR=$OPENSSL_DIR/lib
export OPENSSL_INCLUDE_DIR=$OPENSSL_DIR/include
