#!/bin/bash

# default_modules="default one"

# modules=${MODULE:=$default_modules}


# for module in $modules
# do
#   echo "$module"
# done

function exists {
  hash "$1" 2>/dev/null;
}

if ! exists npm && ! exists yarn; then echo not; else echo yes; fi

function cask-exists {
  brew cask info "$1" &>/dev/null
}

if ! cask-exists docker && ! cask-exists alacritty; then echo no; else echo yes; fi
