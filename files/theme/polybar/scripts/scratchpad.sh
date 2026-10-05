#!/bin/bash

# This script retrieves the list of floating windows in the i3 scratchpad,
# checks their window titles and classes, and displays an icon based on the match.

# Get the i3 tree and filter for windows in the scratchpad
i3-msg -t get_tree | jq -r '
  .. | objects
  | select(.name=="__i3_scratch")        # Select the scratchpad container
  | .floating_nodes[]?
  | .nodes[]?                            # Dive into possible nested containers
  | .window_properties
  | "\(.title) | \(.class)"              # Output title and class separated by pipe
' | while IFS="|" read -r title class; do
    # Convert to lowercase and trim whitespace
    title_clean="${title,,}"
    class_clean="${class,,}"
    program="${title_clean// /} | ${class_clean// /}"

    # Match the program string with known applications and print an icon
    case "$program" in
        *vim*)            echo -n " " ;;      # Neovim / Vim
        *ranger*)         echo -n " " ;;      # Ranger file manager
        *htop*)           echo -n " " ;;      # Htop system monitor
        *thunar*)         echo -n "󰝰 " ;;      # Thunar file manager
        *geany*)          echo -n " " ;;      # Geany editor
        *joplin*)         echo -n " " ;;      # Joplin notes
        *whatsapp*)       echo -n " " ;;      # WhatsApp
        *teams*)          echo -n "󰊻 " ;;      # Microsoft Teams
        *linkedin*)       echo -n " " ;;      # LinkedIn
        *transmission*)   echo -n "󰃘 " ;;      # Transmission torrent client
        *telegram*)       echo -n " " ;;      # Telegram
        *zen*)            echo -n " " ;;      # Zen browser (treated like Firefox)
        *thunar*)         echo -n "󰉌 " ;;      # Thunar file manager
        *keepassxc*)      echo -n "󰌋 " ;;      # Keepassword
        *spotify*)        echo -n "󰓇 " ;;      # Spotify
        *bitwarden*)      echo -n "󰞀 " ;;      # Bitwarden
        *alculat*)        echo -n "󱖦 " ;;      # Galculator
        *alacritty*)      echo -n " " ;;      # Alacritty terminal
        *chromium*)       echo -n " " ;;      # Chromium browser
        *)                echo -n " " ;;      # Default icon for unrecognized apps
    esac
done

# Print a newline after all icons
echo ""
