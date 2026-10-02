#!/usr/bin/bash

if [[ $# -eq 1 ]]; then
    selected=$1
else
    selected=$(find ~/uni/rnote -mindepth 1 -maxdepth 4 "-name" "*.rnote" | sed "s|^$HOME/||" | fzf)
	    # Add home path back
    if [[ -n "$selected" ]]; then
        selected="$HOME/$selected"
    fi
fi

if [[ -z $selected ]]; then
    exit 1
fi

if pgrep -x rnote >/dev/null 2>&1; then
    # Rnote already exists -> make another window
    gapplication action com.github.flxzt.rnote new-window
    # sleep 0.1 # small delay incase it keeps opening the file in the old window

    rnote "$selected"
else
    # Rnote doesn't exist -> start it independently of the terminal
    systemd-run --user --no-block --collect rnote "$selected"
fi

