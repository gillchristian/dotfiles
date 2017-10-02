#!/bin/bash 

function link {
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
}

function update {
  sudo apt-get install -y "$@"
}

function goinstall {
  echo "Installing $1 from $2"
  go get -u $2
  echo ""
}
