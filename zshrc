# load antigen before all yo!
source ~/antigen/antigen.zsh
antigen init ~/.antigenrc

bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# configure spaceship
# export SPACESHIP_RUBY_SHOW=false;
export SPACESHIP_PROMPT_SYMBOL=$;
export SPACESHIP_PREFIX_SHOW=false;
export SPACESHIP_PREFIX_ENV_DEFAULT=' ';

# my aliases & helper functions

# 'cuz aliases
#
# copy
alias c='xclip -selection c'
# ¯\_(ツ)_/¯
alias pelis='~/bin/stremio/Stremio.sh '
# dog, a better cat
alias dog='pygmentize -g'
# vim =/
alias :wq="exit"
# go back one commit
alias rollback="git reset HEAD~"
# pretty git log
alias gplg="git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
# docker-compose
alias dc="docker-compose"

# ----- FUNCTIONS -----

# diff so fancy :D
function gdiff {
  git diff --color $@ | diff-so-fancy
}

# git config switcher
function gconfig {
  if [ -z $1 ] || [ -z $2 ] ; then
    echo "user.name: $(git config --global user.name)"
    echo "user.email: $(git config --global user.email)"
  else
    git config --global user.name $1
    git config --global user.email $2
    echo "user.name: $(git config --global user.name)"
    echo "user.email: $(git config --global user.email)"
  fi
}

# le wifi password
function lewifi {
  RED=$(tput setaf 1)
  GREEN=$(tput setaf 2)
  BOLD=$(tput bold)

  LE_PASS="L7YL7OYFL1TR";
  echo $LE_PASS | c;
  echo "${GREEN}Home password: ${RED}${LE_PASS}";
  echo "${BOLD}${GREEN}Copied to clipboard!!!";
}

# review PR files one by one
function pr-review-files() {
  for i in $(git diff master --name-only)
  do
    GIT_PAGER=less git diff master -- $i
  done
}

# review-pr <pr-number>
function pr-review() {
  if [ $# -eq 0 ]
  then
    echo "Missing PR number"
    return 1
  fi

  local cyan='\e[36m'
  local reset='\e[0m'

  echo "${cyan}Update master branch${reset}"
  git fetch || (echo "The directory is not in a git repository" && return 1) || return 1
  git checkout master
  git merge

  echo "${cyan}Get PR branch${reset}"
  git fetch origin pull/$1/head > /dev/null 2>&1
  git checkout FETCH_HEAD > /dev/null 2>&1
  local branch=`git branch -ra --contains FETCH_HEAD --sort=committerdate | grep remotes | sed 's/remotes\/origin\///' | head -n 1 | tr -d '[:space:]'`
  git checkout $branch
  git merge

  echo "${cyan}Merge master into branch${reset}"
  git merge --no-edit master
}

# shrug
function shrug {
  SHRUG="¯\\_(ツ)_/¯"
  echo $SHRUG | c
  echo $SHRUG
}

# what you are working on! 
#
# I could just use cat I know
function wkon {
  file="WORKING-ON.txt";

  # -d, --delete flag
  if [ "$1" == "-d" ] || [ "$1" == "--delete" ] ; then
    printf "removing %s ...\n" "$file";

    rm $file;
    return;
  fi

  # -h, --help flag
  if [ "$1" == "-h" ] || [ "$1" == "--help" ] ; then
    printf "wkon: easy keep track of what you are working on\n\n";
    printf "USAGE:\n";
    printf "  $ wkon [message] # appends [message] to %s and displays it's content\n\n" "$file";
    printf "OPTIONS:\n";
    printf "  -h, --help    show help\n";
    printf "  -d, --delete  remove %s\n" "$file";

    return;
  fi

  # add content and create file if necessary
  # this must come after flags, as they are params also
  if [ ! -z ${1+x} ]; then
    echo "$@" >> $file;
  fi

  # only show content if file exists and has content
  if [ -f $file ] && [ -s $file ]; then
    echo "----- WORKING ON -----\n";
    cat $file;
  fi
}

# zsh on directoy change hook
add-zsh-hook chpwd wkon;

# replace, plz! \o/
function rplz {
  pt -l $1 | xargs sed -ri.bak -e "s/$1/$2/g"
}

# NPM project bin
function nb {
  $(npm bin)/$1 ${@:2}
}

# ----- ENVIRONMENT -----

# NVM
export NVM_DIR="/home/gillchristian/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"  # This loads nvm

[[ -s "/home/gillchristian/.gvm/scripts/gvm" ]] && source "/home/gillchristian/.gvm/scripts/gvm"

# editor
export EDITOR=vim

# golang's GOPATH
export PATH=$PATH:/usr/local/go/bin
export GOPATH="$HOME/dev/go"
export PATH="$PATH:$GOPATH/bin"

# caddy
export PATH="$HOME/bin/caddy:$PATH"

# dir colors
# eval $(dircolors -b $HOME/.dircolors)

# ~/bin 
export PATH="$HOME/bin:$PATH"

# yarn
export PATH="$HOME/.yarn/bin:$PATH"

# rust
export PATH="$HOME/.cargo/bin:$PATH"

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
