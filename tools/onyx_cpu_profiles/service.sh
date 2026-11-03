#!/system/bin/sh

MODDIR=${0%/*}
PROFILE_FILE="$MODDIR/profile"
LOG_FILE="$MODDIR/profile.log"
APPLY="$MODDIR/bin/profile.sh"

# Wait briefly for the device cpufreq policies to become available. The helper
# performs topology and frequency validation before applying any limits.
for attempt in $(seq 1 60); do
    ready=1
    for policy in 0 2 5 7; do
        [ -e "/sys/devices/system/cpu/cpufreq/policy$policy/scaling_max_freq" ] || ready=0
    done
    [ "$ready" -eq 1 ] && break
    sleep 2
done

profile=$(cat "$PROFILE_FILE" 2>/dev/null)
case "$profile" in
    battery|gaming) ;;
    *) profile=gaming ;;
esac

"$APPLY" "$profile" >> "$LOG_FILE" 2>&1
