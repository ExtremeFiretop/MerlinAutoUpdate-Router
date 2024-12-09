#!/bin/sh

source /usr/sbin/helper.sh

ADDON_NAME="MerlinAU"
ADDON_DIR="/jffs/addons/MerlinAU.d"
PAGE_FILE="$ADDON_DIR/MerlinAU.asp"
PAGE_NAME_FILE="$ADDON_DIR/am_page_name"

# Load the page name we stored during install
if [ -f "$PAGE_NAME_FILE" ]; then
    am_webui_page=$(cat "$PAGE_NAME_FILE")
else
    # If not stored, try to re-derive it (not ideal)
    am_get_webui_page $PAGE_FILE
fi

if [ -z "$am_webui_page" ] || [ "$am_webui_page" = "none" ]; then
    logger "$ADDON_NAME" "No assigned page found to uninstall."
    exit 1
fi

logger "$ADDON_NAME" "Uninstalling $ADDON_NAME mounted as $am_webui_page"

# Remove just our entry from menuTree.js, but do not unmount it if others may depend on it
if [ -f /tmp/menuTree.js ]; then
    sed -i "/url: \"$am_webui_page\", tabName: \"$ADDON_NAME\"/d" /tmp/menuTree.js
    # Don't umount here if other add-ons need it. 
fi

# Remove our custom page (only if still mounted and safe to do so)
if [ -f "/www/user/$am_webui_page" ]; then
    rm -f "/www/user/$am_webui_page"
fi

rm -f "$PAGE_NAME_FILE"

# Remount menuTree.js to apply changes
umount /www/require/modules/menuTree.js
mount -o bind /tmp/menuTree.js /www/require/modules/menuTree.js

logger "$ADDON_NAME" "Uninstalled successfully (preserving other add-ons' entries)."
