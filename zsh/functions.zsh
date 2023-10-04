# diff so fancy
function gdiff {
  git diff --color $@ | diff-so-fancy
}

# html2purs shortcut
function 2purs {
  local out="$(twpurs html2purs | awk '{print "  " $0}')"
  echo "module Temp where\n\ntmp =\n$out" |  purty - | tail -n +4 | sed 's/^  //'
}
function 2pursC {
  twpurs classnames $@ | tee >(c)
}
function 2pursS {
  twpurs classnames --single-line $@ | tee >(c)
}

# ##################################################

function runrustc {
  local name=$(basename $1 .rs)
  rustc $@ && ./$name && rm $name
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
  rg -l -e $1 $3 | xargs -I{} sed -i.bak -e "s/$1/$2/g" "{}"
}

# ##################################################

# NPM project bin
function nb {
  $(npm bin)/$1 ${@:2}
}

# ##################################################

# open vim with fuzzy search
function fim {
  vim $(fzf --preview 'bat {} | head -200')
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
    "direnv"
  )
  case $1 in
    nvm)
      [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
      ;;
    direnv)
      eval "$(direnv hook zsh)"
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

# Clean iOS shitty automatic quotes

function clean-ios-quotes {
  sd ” '"' **/*.md
  sd “ '"' **/*.md
  sd ’ "'" **/*.md
}

# Direnv hook
function denv {
  case $1 in
    toggle)
      if [ "$(cat ~/.direnvswitch)" = "On" ]; then
        direnv-off
      else
        direnv-on
      fi;
      ;;
    status)
      cat ~/.direnvswitch
      ;;
    on)
      echo "On" > ~/.direnvswitch
      eval "$(direnv hook zsh)"
      ;;
    off)
      echo "Off" > ~/.direnvswitch
      ;;
    "")
      echo "Manage direnv hook."
      echo ""
      echo "$ denv on"
      echo "$ denv off"
      echo "$ denv toggle"
      echo "$ denv status"
      ;;
    *)
      echo "Manage direnv hook."
      echo ""
      echo "$ denv on"
      echo "$ denv off"
      echo "$ denv toggle"
      echo "$ denv status"
      ;;
  esac
}

# Sym links made easier
function slink {
  if [ "$1" = "--help" ]; then
    echo 'Usage'
    echo '$ link "/full/origin/path" "/full/target/path"'
    echo ''
    echo 'Example:'
    echo '$ link "$DOTFILES_DIR/tool/tool.toml" ~/.tool.toml'
  else
    if [[ -e "$2" ]]; then
      echo "$2 already exists, if it is a symlink it will be deleted"
      if [[ -h "$2" ]]; then
        rm -rf "$2"
        ln -s $1 $2
      else
        echo "Not a symlink, renaming and linking"
        mv -f "$2" "$2_old"
        ln -s $1 $2
      fi
    else
      ln -s $1 $2
    fi
  fi
}

# List all scripts
function lss {
  if [[ -e "package.json" ]]; then
    local output=$(bat package.json | jq '.scripts | to_entries | map("- \(.key): \(.value)") | join("\n")' | sd '"' '')
    printf "$output\n"
  else
    echo "No package.json in this directory"
  fi
}
