#!/usr/bin/bash

if [[ $# -eq 1 ]]; then
    selected=$1
else
    selected=$(find $dir ~/uni/books ~/uni/lecture-notes ~/Downloads -mindepth 1 -maxdepth 1 "-name" "*.pdf" | sed "s|^$HOME/||" | fzf)
	    # Add home path back
    if [[ -n "$selected" ]]; then
        selected="$HOME/$selected"
    fi
fi

if [[ -z $selected ]]; then
    exit 1
fi

# hyprctl eval "hl.exec_cmd('sioyek --new-window \"$selected\"')"

lektra $selected
