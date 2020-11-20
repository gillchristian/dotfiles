# diff so fancy
function gdiff {
  git diff --color $@ | diff-so-fancy
}

# ##################################################

# git config switcher
function gconfig {
  if [ -z $1 ] || [ -z $2 ] ; then
    echo "user.name:  $(git config --global user.name)"
    echo "user.email: $(git config --global user.email)"
  else
    git config --global user.name $1
    git config --global user.email $2
    echo "user.name:  $(git config --global user.name)"
    echo "user.email: $(git config --global user.email)"
  fi
}

# ##################################################

# shrug
function shrug {
  SHRUG="¯\\_(ツ)_/¯"
  echo $SHRUG | c
  echo $SHRUG
}

# ##################################################

# replace, plz! \o/
function rplz {
  rg -l -e $1 $3 | xargs sed -i.bak -e "s/$1/$2/g"
}

# ##################################################

# NPM project bin
function nb {
  $(npm bin)/$1 ${@:2}
}

# ##################################################

# open vim with fuzzy search
function fim {
  vim $(fzf --preview 'bat --color=always --line-range :500 {}')
}

# ##################################################

# check the weather
function we {
  curl "wttr.in/$1"
}

# ##################################################

# find stuff in gillchristian/til repo
function til {
  cat til.md | rg '#' | cut -d ' ' -f 2- | rg -i $@
}

# ##################################################

# history top
function history-top {
  local count=${1:=20}
  history | awk '{print $2}' | sort | uniq -c | sort -rn | head -"$count" | cat -n
}

# ##################################################

# bundle again all antibody plugins
function antibody_bundle {
  antibody bundle < "$DOTFILES_DIR/zsh/antibodyrc" > ~/.antibody_plugins.sh
}

# ##################################################
#                                                  #
# LOADERS                                          #
#                                                  #
# You don't want to load these things eagerly if   #
# you rarely use them.                             #
# The faster zsh loads the better!                 #
#                                                  #
# ##################################################

function load {
  local supported=(
    "nvm"
    "rbenv"
  )
  case $1 in
    nvm)
      export NVM_DIR="$HOME/.nvm"
        [ -s "/usr/local/opt/nvm/nvm.sh" ] && . "/usr/local/opt/nvm/nvm.sh"  # This loads nvm
      ;;

    rbenv)
      eval "$(rbenv init -)"
      ;;
    "")
      echo "Lazy load programs to avoid slowing down shell initialization."
      echo ""
      echo "These are the supported programs:"
      for program in $supported
      do
        echo "  - $program"
      done
      return 1
      ;;
    *)
      echo "Lazy load programs to avoid slowing down shell initialization."
      echo ""
      echo "Lazy load for \"$1\" is not yet implemented."
      echo ""
      echo "These are the supported programs:"
      for program in $supported
      do
        echo "  - $program"
      done
      return 1
      ;;
  esac

  echo "Loaded $1"
}

# z - with fzf when no args are provided
unalias z 2> /dev/null
z() {
  [ $# -gt 0 ] && _z "$*" && return
  cd "$(_z -l 2>&1 | fzf --height 40% --nth 2.. --reverse --inline-info +s --tac --query "${*##-* }" | sed 's/^[0-9,.]* *//')"
}

# branch delete with fzf (skips the current one)
#
# use with care as it force deletes the branch
zbd() {
  git branch --list | \
    # deleting the current one doesn't work
    sed '/^\*/d' | \
    # probably don't want to delete master :)
    sed '/master/d' | \
    xargs -I{} echo {} | \
    fzf --preview='git log {} | head -100' --ansi | \
    xargs -I{} git branch -D {}
}

# checkout branch with fzf
zgo() {
  git branch --list | \
    # you wouldn't want to switch to the current branch, would you?
    sed '/^\*/d' | \
    xargs -I{} echo {} | \
    fzf --preview='git log {} | head -100' --ansi | \
    xargs -I{} git checkout {}
}
