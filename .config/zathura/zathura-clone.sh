#!/bin/bash

# 1. Get the PID of the focused Zathura window based on your WM
if [ "$XDG_CURRENT_DESKTOP" = "Hyprland" ]; then
    PID=$(hyprctl activewindow -j | jq -r '.pid')
elif [ "$XDG_CURRENT_DESKTOP" = "sway" ]; then
    PID=$(swaymsg -t get_tree | jq '.. | select(.focused? == true) | .pid')
else
    # Fallback for other Wayland compositors using generic tools
    PID=$(gdbus call --session --dest org.gnome.Shell --object-path /org/gnome/Shell --method org.gnome.Shell.Eval "global.get_window_actors().find(a => a.meta_window.has_focus()).meta_window.get_pid()" | sed "s/.* //;s/'.*//")
fi

# 2. Query DBus for the current page number
# Zathura uses org.pwmt.zathura.PID-[number]
RAW_PAGE=$(dbus-send --print-reply --dest=org.pwmt.zathura.PID-$PID \
    /org/pwmt/zathura \
    org.freedesktop.DBus.Properties.Get \
    string:org.pwmt.zathura \
    string:pagenumber 2>/dev/null)

# 3. Extract the integer
PAGE=$(echo "$RAW_PAGE" | grep "uint32" | awk '{print $3}')

# 4. Launch at that page (DBus 0-index -> Zathura 1-index)
if [ -z "$PAGE" ]; then
    zathura "$1" &
else
    zathura -P $((PAGE + 1)) "$1" &
fi
