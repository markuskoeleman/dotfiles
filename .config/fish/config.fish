fish_add_path ~/.local/bin/scripts
zoxide init fish --cmd cd | source
set -gx MANPAGER "nvim +Man!"
abbr -a origin open_repo_origin.sh
abbr -a restow restow.sh


