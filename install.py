#!/usr/bin/env python3

import os.path
import os
import sys
import re
import subprocess

def with_home(path):
    return os.path.expanduser(os.path.join('~', path))

def with_dotfiles(path = ''):
    return os.path.expanduser(os.path.join('~', with_home('dev/dotfiles'), path))


default_modules = 'brew git zsh utils fonts purs alacritty vim tmux docker rust node haskell go erlang'
modules = os.getenv('MODULES', default_modules).split(' ')

def yes_no(msg):
    answer = ''
    while not re.search('y|n|yes|no', answer, re.IGNORECASE):
        answer = input('{} y/n '.format(msg))
    return bool(re.search('y|yes', answer, re.IGNORECASE))

def exists(program):
    return 0 == subprocess.run(['which', program], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode

def install_brew():
    if exits('brew'):
        return
    curl = subprocess.run(
        ['curl', '-fsSL', 'https://raw.githubusercontent.com/Homebrew/install/master/install'],
        text=True,
        capture_output=True,
        check=True
    )
    subprocess.run(['/usr/bin/ruby', '-e', curl.stdout], check=True)

def setup_dotfiles():
    if not os.path.isdir(with_dotfiles()):
        os.mkdir(with_dotfiles())

# print ('''
# home: {}
# args: {}

# modules: {}

# should install Purs: {}'''.format(home, sys.argv, modules, yes_no('Install Purs? (It requires installing Rust, which I will do as well)')))

warning = """
# ############################################################################ #
#                                                                              #
# WARNING: This is a generated file. Do not edit by hand!!!                    #
#                                                                              #
# dotfiles: https:/github.com/gillchristian/dotfiles                           #
#                                                                              #
# ############################################################################ #
"""

compinit = """
# ############################################################################ #
#                                                                              #
# Load antibody plugins                                                        #
#                                                                              #
# Completion needs to load before some plugins                                 #
#                                                                              #
# By default 'compinit' checks ~/.zcompdump on every load.                     #
# This changes it to use chage and only do the check once every day. Which     #
# reduces the startup time significantly.                                      #
#                                                                              #
# From:  https://gist.github.com/ctechols/ca1035271ad134841284                 #
# Addapted by:  https://carlosbecker.com/posts/speeding-up-zsh/                #
#                                                                              #
# ############################################################################ #
autoload -Uz compinit
if [ $(date +'%j') != $(stat -f '%Sm' -t '%j' ~/.zcompdump) ]; then
  compinit
else
  compinit -C
fi
"""

antibody = "source ~/.antibody_plugins.sh"

prompt_cleanup = """
# clenup promp to not see the flash of oh-my-zsh prompt before Purs loads
PROMPT=""
"""

bindkeys = """
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
"""

purs_setup = """
# ################################################ #
#                                                  #
# Purs prompt (https://github.com/xcambar/purs)    #
#                                                  #
# ################################################ #

function zle-line-init zle-keymap-select {
  PROMPT=`purs prompt -k "$KEYMAP" -r "$?" --venv "${${VIRTUAL_ENV:t}%-*}"`
  zle reset-prompt
}
zle -N zle-line-init
zle -N zle-keymap-select

autoload -Uz add-zsh-hook

function _prompt_purs_precmd() {
  purs precmd
}
add-zsh-hook precmd _prompt_purs_precmd
"""

sources = """
# ##################################################

export DOTFILES_DIR="$HOME/dev/dotfiles"

source ~/.zsh/aliases.zsh
source ~/.zsh/functions.zsh
source ~/.zsh/exports.zsh
# Functions, aliases & exports that shouldn't be in Git
if [ -f "$HOME/.zsh/private.zsh" ]; then source ~/.zsh/private.zsh; fi
"""

dependencies = """
# ############################################################################ #
#                                                                              #
# Depdendencies configuration                                                  #
#                                                                              #
# Sadly some programs want to have stuff in ~/.zshrc                           #
# (Instead of letting you place it in the file you want)                       #
# This is the "safe" space for that \o/                                        #
# Don't manually change anything after this line :)                            #
#                                                                              #
# ############################################################################ #

# Load fnm
eval "$(fnm env --multi)"

# The next line updates PATH for the Google Cloud SDK.
if [ -f "$HOME/google-cloud-sdk/path.zsh.inc" ]; then . "$HOME/google-cloud-sdk/path.zsh.inc"; fi

# BEGIN CW-CLI MANAGED BLOCK
if [ -f /Users/cw0072/projects/cw-cli/.env ] ; then source /Users/cw0072/projects/cw-cli/.env ; fi
# END CW-CLI MANAGED BLOCK

# Load fzf
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
"""

def generate():
    file_content = "\n\n".join(
        map(
            lambda str: str.strip(),
            [warning, compinit, antibody, prompt_cleanup, bindkeys, purs_setup, sources, dependencies]
        )
    )
    return file_content

