#!/bin/bash

# Get the PID of the focused Zathura window via hyprctl
PID=$(hyprctl activewindow -j | jq -r '.pid')

# Query DBus for the current page number
# Zathura uses org.pwmt.zathura.PID-[number]
RAW_PAGE=$(dbus-send --print-reply --dest=org.pwmt.zathura.PID-$PID \
    /org/pwmt/zathura \
    org.freedesktop.DBus.Properties.Get \
    string:org.pwmt.zathura \
    string:pagenumber 2>/dev/null)

# Extract the integer
PAGE=$(echo "$RAW_PAGE" | grep "uint32" | awk '{print $3}')

# Launch at that page (DBus 0-index -> Zathura 1-index)
if [ -z "$PAGE" ]; then
    zathura "$1" &
else
    zathura -P $((PAGE + 1)) "$1" &
fi
