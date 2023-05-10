# NeoVim -> Vim
alias vim=nvim

# zoom-meeting-parser
alias zum='xclip -o -sel clip | zoom-meeting-parser | xclip -sel clip'

# copy
alias c='xclip -sel c'

# paste
alias p='xclip -sel c -o'

# pull translations
alias i18n="load rbenv && bundle exec rake translations:pull && bundle exec rake i18n:js:export"

# -- GIT --- #
#
# pretty logs
alias gplg="git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
#
# put all in wip
alias wip='ga . && gc --no-verify -m wip'
#
# go back one commit
alias rollback='git reset HEAD~'
#
# ---------- #

# docker-compose
alias dc='docker-compose'

# purge docker images with no tag
alias docker-purge='docker rmi $(docker images | grep "^<none>" | awk "{print $3}")'

# -- #

# bat, a cat clone with wings
# screw pagination
alias bat='bat --paging=never --theme=Monokai\ Extended\ Bright'

# standup - show in screen and copy
alias standup='td standup | tee /dev/tty | c'

# `less`-less list branches
alias gbls='git branch --list | xargs -I{} echo {}'

# better ls
alias l='exa -la --group-directories-first'

# TODO: add to dir_alias
alias aliasf='bat .aliasfile' # TODO apply it to all the .aliasfile's

# list ports (on Linux)
alias ports='netstat -tulpn'

# psql on Mac
#
# @link https://gist.github.com/ibraheem4/ce5ccd3e4d7a65589ce84f2a3b7c23a3
#
alias pg_start='launchctl load ~/Library/LaunchAgents/homebrew.mxcl.postgresql.plist'
alias pg_stop='launchctl unload ~/Library/LaunchAgents/homebrew.mxcl.postgresql.plist'

# get my public IP
alias my-ip='curl ipecho.net/plain ; echo'

# zettelkasten
alias zet='neuron -d ~/dev/zettelkasten/zettels'

# Fourmolu
alias fmt-hs="git ls-files -z '*.hs' | xargs -0 fourmolu --mode inplace"
