fish_add_path ~/.local/bin/scripts
zoxide init fish --cmd cd | source
set -gx MANPAGER "nvim +Man!"
abbr -a origin open_repo_origin.sh
abbr -a restow restow.sh

# ZVM
set -gx ZVM_INSTALL "$HOME/.zvm/self"
set -gx PATH $PATH "$HOME/.zvm/bin"
set -gx PATH $PATH "$ZVM_INSTALL/"
