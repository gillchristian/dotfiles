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
  rg -l -e $1 $3 | xargs sed -ri.bak -e "s/$1/$2/g"
}

# ##################################################

# NPM project bin
function nb {
  $(npm bin)/$1 ${@:2}
}

# ##################################################

# open vim with fuzzy search
function fim {
  vim $(fzf)
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
  echo "Loading $1 ..."
  case $1 in
    nvm)
      [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
      ;;
    rbenv)
      eval "$(rbenv init -)"
      ;;
  esac
}
