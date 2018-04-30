# Configure spaceship
export SPACESHIP_KUBECONTEXT_SHOW=false;
export SPACESHIP_RUBY_SHOW=false;
export SPACESHIP_CHAR_SYMBOL='$ ';
export SPACESHIP_PROMPT_PREFIXES_SHOW=false;
export SPACESHIP_PROMPT_DEFAULT_PREFIX=' ';

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
