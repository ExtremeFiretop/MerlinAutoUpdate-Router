#!/bin/sh

source /usr/sbin/helper.sh

ADDON_NAME="MerlinAU"
ADDON_DIR="/jffs/addons/MerlinAU.d"
PAGE_FILE="$ADDON_DIR/MerlinAU.asp"
PAGE_NAME_FILE="$ADDON_DIR/am_page_name"

# Check if the firmware supports addons
nvram get rc_support | grep -q am_addons
if [ $? != 0 ]; then
    logger "$ADDON_NAME" "This firmware does not support addons!"
    exit 5
fi

# Obtain the first available mount point in $am_webui_page
am_get_webui_page $PAGE_FILE

if [ "$am_webui_page" = "none" ]; then
    logger "$ADDON_NAME" "Unable to install $ADDON_NAME"
    exit 5
fi

logger "$ADDON_NAME" "Mounting $ADDON_NAME as $am_webui_page"

# Store the page name for later use (e.g., in uninstall scripts)
echo "$am_webui_page" > "$PAGE_NAME_FILE"

# Copy custom page to the user's WebUI directory
cp "$PAGE_FILE" "/www/user/$am_webui_page"

# Copy menuTree.js if not already copied, so we can modify it
if [ ! -f /tmp/menuTree.js ]; then
    cp /www/require/modules/menuTree.js /tmp/
    mount -o bind /tmp/menuTree.js /www/require/modules/menuTree.js
fi

# Insert link at the end of the Tools menu
sed -i "/url: \"Advanced_FirmwareUpgrade_Content.asp\", tabName:/a {url: \"$am_webui_page\", tabName: \"$ADDON_NAME\"}," /tmp/menuTree.js

# Remount menuTree.js to apply changes
umount /www/require/modules/menuTree.js
mount -o bind /tmp/menuTree.js /www/require/modules/menuTree.js