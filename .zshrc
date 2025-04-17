export GOPATH=$HOME/.local/share/go
export PATH=/usr/local/bin:$HOME/.local/share/go/bin:$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"

zstyle ':omz:update' frequency 1

if command -v eza &> /dev/null; then
  plugins=(git golang zsh-syntax-highlighting zsh-autosuggestions zsh-eza)
else
  plugins=(git golang zsh-syntax-highlighting zsh-autosuggestions)
fi

source $ZSH/oh-my-zsh.sh

function gi() { curl -sLw "\n" https://www.toptal.com/developers/gitignore/api/$@ ;}
function Resume {
  fg
  zle push-input
  BUFFER=""
  zle accept-line
}
zle -N Resume
bindkey "^Z" Resume

eval "$(starship init zsh)"
