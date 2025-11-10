# Please note that it's essential that this script is sourced and not executed directly
# Executing it directly won't work because the directory will only be changed for the shell the script is ran in
# Which will terminate when the script exits, so the main shell won't be affected.
#
# Just alias it, something like:
# alias -s co="source ~/.local/bin/scripts/open_dir.fish"
# *please note that the full path needs to be specified here, 
# the $PATH variable doesn't seemingly affect the source command

# Only searches with a depth of 1 so you'll need to specify all the dirs where projects could be located
set selected (
find ~/uni/pogramaermethodeiken/ ~/uni/maths ~/uni/physics ~/coding ~/.dotfiles/.config ~/.dotfiles/.local/bin -mindepth 1 -maxdepth 1 -type d -not -name '.*'|
	sed "s|^$HOME/||" |
	fzf
)

# check if the path selected path is empty, (user did not select anything)
if not test -n "$selected"
	exit 1
end

# Add home path back
set selected "$HOME/$selected"

cd $selected
