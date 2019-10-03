# copy
alias c='xclip -selection c'

# -- GIT --- #
#
# pretty logs
alias gplg="git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"
#
# put all in wip
alias wip="ga . && gc --no-verify -m wip"
#
# go back one commit
alias rollback="git reset HEAD~"
#
# ---------- #

# docker-compose
alias dc="docker-compose"

# purge docker images with no tag
alias docker-purge='docker rmi $(docker images | grep "^<none>" | awk "{print $3}")'

# bat, a cat clone with wings
# screw pagination
alias bat='bat --paging=never --theme=Monokai\ Extended\ Bright'
alias batjs='bat -l js' # doesn't support ts so I use JS for that

# standup - show in screen and copy
alias standup='td standup | tee /dev/tty | c'

# list branches without `less`
alias gbls='git branch --list | xargs -I{} echo {}'

# better ls
alias l='exa -la --group-directories-first --git'
