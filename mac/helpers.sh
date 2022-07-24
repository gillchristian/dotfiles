#!/bin/bash 

function link {
  # paths cannot be relative
  local origin="$1"
  local target="$2"

  if [[ -e "$target" ]]; then
    echo "$target already exists, if it is a symlink it will be deleted"
    if [[ -h "$target" ]]; then
      rm -rf "$target"
      ln -s "$origin" "$target"
    else
      echo "Not a symlink, renaming and linking"
      mv -f "$target" "$target"_old
      ln -s "$origin" "$target"
    fi
  else
    ln -s "$origin" "$target"
  fi
}

# Checks if a program is installed. Ignores aliases
# 
# if exists prog-a && exists prog-b; then
#   echo "Both programs exist"
# else
#   echo "Either one or both programs don't exist"
# fi
function exists {
  hash "$1" 2>/dev/null;
}

# Checks if a brew cask is installed.
#
# @link: https://stackoverflow.com/a/33107009/4530566
#
# if exists cask-a && exists cask-b; then
#   echo "Both casks exist"
# else
#   echo "Either one or both casks don't exist"
# fi
function cask-exists {
  brew cask info "$1" &>/dev/null
}
