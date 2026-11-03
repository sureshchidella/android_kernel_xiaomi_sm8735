#!/system/bin/sh

MODDIR=${0%/*}
APPLY="$MODDIR/bin/profile.sh"
PROFILE_FILE="$MODDIR/profile"
current=$(cat "$PROFILE_FILE" 2>/dev/null)
case "$current" in
    battery) profile=gaming ;;
    gaming) profile=battery ;;
    *) profile=gaming ;;
esac
"$APPLY" "$profile"
