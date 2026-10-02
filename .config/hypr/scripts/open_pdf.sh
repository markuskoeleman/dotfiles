#!/usr/bin/bash

if [[ $# -eq 1 ]]; then
    selected=$1
else
    selected=$(find ~/uni/books ~/uni/lecture-notes ~/Downloads ~/uni/problems -mindepth 1 -maxdepth 4 "-name" "*.pdf" | sed "s|^$HOME/||" | fzf)
	    # Add home path back
    if [[ -n "$selected" ]]; then
        selected="$HOME/$selected"
    fi
fi

if [[ -z $selected ]]; then
    exit 1
fi

lektra "$selected"
