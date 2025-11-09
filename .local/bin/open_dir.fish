#Only searches with a depth of 1 so you'll need to specify all the dirs where projects could be located
set selected (
find ~/uni/pogramaermethodeiken/ ~/uni/maths ~/uni/physics ~/coding ~/.dotfiles/.config -mindepth 1 -maxdepth 1 -type d -not -name '.*'|
	sed "s|^$HOME/||" |
	fzf
)

# Add home path back
set selected "$HOME/$selected"

if not test -n "$selected"
	exit 1
end

cd $selected
