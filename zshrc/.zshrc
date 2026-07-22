export AWS_CLI_AUTO_PROMPT=on-partial
export AWS_PROFILE=ww-sandbox
export PATH="$HOME/.local/bin:$PATH"
export ZSH="$HOME/.oh-my-zsh"

# Path to nvm directory
export NVM_DIR="$HOME/.nvm"
[ -s "$HOMEBREW_PREFIX/opt/nvm/nvm.sh" ] && \. "$HOMEBREW_PREFIX/opt/nvm/nvm.sh"
[ -s "$HOMEBREW_PREFIX/opt/nvm/etc/bash_completion.d/nvm" ] && \. "$HOMEBREW_PREFIX/opt/nvm/etc/bash_completion.d/nvm"

ZSH_THEME="agnoster"

eval $(thefuck --alias)

plugins=(git)

source $ZSH/oh-my-zsh.sh

alias development="export AWS_PROFILE=ww-development-power && aws sso login"
alias prod="export AWS_PROFILE=ww-prod && aws sso login"
alias production="export AWS_PROFILE=ww-production && aws sso login"
alias proof="export AWS_PROFILE=ww-proof && aws sso login"
alias sandbox="export AWS_PROFILE=ww-sandbox && aws sso login"
alias staging="export AWS_PROFILE=ww-staging && aws sso login"

alias gfp="git fetch && git pull"

alias c="cursor ."
alias d="cd $HOME/src/personal/dotfiles"
alias z="source $HOME/.zshrc"

alias nm_check="find . -name 'node_modules' -type d -prune"
alias nm_delete="find . -name 'node_modules' -type d -prune -exec rm -rf '{}' +"
