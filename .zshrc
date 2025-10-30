eval "$(oh-my-posh init zsh --config $HOME/.config/ohmyposh/config.toml)"
eval "$(zoxide init --cmd cd zsh)"

# History
HISTSIZE=5000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_ignore_dups
setopt hist_find_no_dups

# PATH
export PATH="$HOME/.local/bin:$PATH"

# aliasses
alias ls='ls --color=auto'
alias op='open_pdf.sh'
alias github="open_github.sh"

# Shell integrations
eval "$(fzf --zsh)"
