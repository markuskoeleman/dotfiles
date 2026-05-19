#!/usr/bin/bash

TABLET="xp-pen-star-g640"
STATE_FILE="/tmp/tablet_ultrawide_side"

# 1. Parse JSON to find the port hosting the 3440x1440 resolution
ULTRAWIDE_PORT=$(hyprctl monitors -j | jq -r '.[] | select(.width == 3440 and .height == 1440) | .name')

# 2. Parse JSON to find the port that currently has cursor/window focus
CURRENT_PORT=$(hyprctl monitors -j | jq -r '.[] | select(.focused == true) | .name')

# 3. Decision Logic
if [ -n "$ULTRAWIDE_PORT" ]; then
    # THE ULTRAWIDE IS CONNECTED
    LAST_STATE=$(cat "$STATE_FILE" 2>/dev/null || echo "left")

    if [ "$LAST_STATE" = "left" ]; then
        hyprctl eval "hl.device({
            name = '$TABLET',
            output = '$ULTRAWIDE_PORT',
            region_size = {2304, 1440},
            region_position = {1136, 0},
        })"
        echo "right" > "$STATE_FILE"
        notify-send "Tablet Profile" "Ultrawide: Right-Aligned Workspace"
    else
        hyprctl eval "hl.device({
            name = '$TABLET',
            output = '$ULTRAWIDE_PORT',
            region_size = {2304, 1440},
            region_position = {0, 0},
        })"
        echo "left" > "$STATE_FILE"
        notify-send "Tablet Profile" "Ultrawide: Left-Aligned Workspace"
    fi
else
    # 4. UNIVERSAL 16:9 FALLBACK
    hyprctl eval "hl.device({
        name = '$TABLET',
        output = '$CURRENT_PORT',
        active_area_size = {160, 90},
        active_area_position = {0, 5}
    })"
    notify-send "Tablet Profile" "Standard 16:9 Aspect Ratio Mode"
fi
