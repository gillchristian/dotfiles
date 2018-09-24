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

# ##################################################

# review PR files one by one
function pr-review-files() {
  for i in $(git diff master --name-only)
  do
    GIT_PAGER=less git diff master -- $i
  done
}

# ##################################################

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

# ##################################################

# shrug
function shrug {
  SHRUG="¯\\_(ツ)_/¯"
  echo $SHRUG | c
  echo $SHRUG
}

# ##################################################

function lorem {
	local lines=${1-10}; 
	tr -dc a-z1-4 < /dev/urandom | tr 1-2 ' \n' | awk 'length==0 || length>50' | tr 3-4 ' ' | sed 's/^ *//' | cat -s | sed 's/ / /g' | fmt | head -n ${lines};
}

# ##################################################

# zsh on directoy change hook
add-zsh-hook chpwd wkon;

# ##################################################

# Openit right from CLI https://openit.io/
# 
# $ openit js/chimi

function openit() {
  xdg-open "http://openit.io/$1"
}

# ##################################################

# Git clone with openit
#
# $ clone js/chimi

function clone() {
  git clone $(curl -Ls -o /dev/null -w %{url_effective} https://openit.io/$1)
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
