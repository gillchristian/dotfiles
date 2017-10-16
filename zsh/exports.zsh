# Configure spaceship
export SPACESHIP_KUBECONTEXT_SHOW=false;
export SPACESHIP_RUBY_SHOW=false;
export SPACESHIP_PROMPT_SYMBOL=$;
export SPACESHIP_PREFIX_SHOW=false;
export SPACESHIP_PREFIX_ENV_DEFAULT=' ';

# Editor
export EDITOR=vim

# Golang's GOPATH & bin
export GOPATH="$HOME/dev/go"

GO_BIN="$GOPATH/bin:/usr/local/go/bin"

# Caddy
CADDY="$HOME/bin/caddy"

# ~/bin 
MY_BIN="$HOME/bin"

# yarn
YARN="$HOME/.yarn/bin"

# rust's cargo
CARGO="$HOME/.cargo/bin"

# add stuff to PATH
export PATH="$GO_BIN:$CADDY:$MY_BIN:$YARN:$CARGO:$PATH"
