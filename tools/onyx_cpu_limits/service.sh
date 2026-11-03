#!/system/bin/sh

MODDIR=${0%/*}
LOG_FILE="$MODDIR/limits.log"
POLICIES="0:0-1:1286400 2:2-4:1920000 5:5-6:1920000 7:7:2515200"

normalize_cpu_list() {
    printf '%s\n' "$1" | awk '
        {
            gsub(/,/, " ")
            count = split($0, items, /[[:space:]]+/)
            for (i = 1; i <= count; i++) {
                if (items[i] == "") continue
                dash = index(items[i], "-")
                if (dash) {
                    first = substr(items[i], 1, dash - 1)
                    last = substr(items[i], dash + 1)
                    for (cpu = first; cpu <= last; cpu++) print cpu
                } else print items[i]
            }
        }
    '
}

wait_for_policies() {
    attempt=0
    while [ "$attempt" -lt 60 ]; do
        ready=1
        for policy in 0 2 5 7; do
            [ -e "/sys/devices/system/cpu/cpufreq/policy$policy/scaling_max_freq" ] || ready=0
        done
        [ "$ready" -eq 1 ] && return 0
        sleep 2
        attempt=$((attempt + 1))
    done
    return 1
}

wait_for_policies || { echo "CPU policies unavailable" >> "$LOG_FILE"; exit 1; }

# Validate every cluster before writing any limit.
for item in $POLICIES; do
    policy=${item%%:*}
    rest=${item#*:}
    cpus=${rest%%:*}
    target=${rest##*:}
    path="/sys/devices/system/cpu/cpufreq/policy$policy"

    [ -r "$path/related_cpus" ] && [ -r "$path/scaling_available_frequencies" ] && \
        [ -r "$path/scaling_min_freq" ] && [ -r "$path/cpuinfo_max_freq" ] && \
        [ -w "$path/scaling_max_freq" ] || {
        echo "Missing cpufreq controls for policy$policy" >> "$LOG_FILE"
        exit 1
    }

    actual=$(normalize_cpu_list "$(cat "$path/related_cpus" 2>/dev/null)")
    expected=$(normalize_cpu_list "$cpus")
    [ "$actual" = "$expected" ] || {
        echo "Unexpected CPU topology for policy$policy" >> "$LOG_FILE"
        exit 1
    }

    available=$(cat "$path/scaling_available_frequencies" 2>/dev/null)
    supported=0
    for frequency in $available; do
        [ "$frequency" = "$target" ] && supported=1
    done
    [ "$supported" -eq 1 ] || {
        echo "${target} kHz unavailable for policy$policy" >> "$LOG_FILE"
        exit 1
    }

    minimum=$(cat "$path/scaling_min_freq" 2>/dev/null)
    [ -n "$minimum" ] && [ "$minimum" -le "$target" ] || {
        echo "Requested cap below minimum for policy$policy" >> "$LOG_FILE"
        exit 1
    }
    stock=$(cat "$path/cpuinfo_max_freq" 2>/dev/null)
    case "$stock" in
        ''|*[!0-9]*)
            echo "Invalid stock maximum for policy$policy" >> "$LOG_FILE"
            exit 1
            ;;
    esac
done

# Apply all caps. If a write fails, release any caps already applied to stock max.
restore_applied() {
    for done_policy in $applied; do
        done_path="/sys/devices/system/cpu/cpufreq/policy$done_policy"
        stock=$(cat "$done_path/cpuinfo_max_freq" 2>/dev/null)
        [ -n "$stock" ] && echo "$stock" > "$done_path/scaling_max_freq" 2>/dev/null
    done
}

applied=""
for item in $POLICIES; do
    policy=${item%%:*}
    rest=${item#*:}
    target=${rest##*:}
    path="/sys/devices/system/cpu/cpufreq/policy$policy"
    applied="$applied $policy"
    if ! echo "$target" > "$path/scaling_max_freq"; then
        echo "Write failed on policy$policy; restoring stock limits" >> "$LOG_FILE"
        restore_applied
        exit 1
    fi
    readback=$(cat "$path/scaling_max_freq" 2>/dev/null)
    case "$readback" in
        ''|*[!0-9]*)
            echo "Invalid readback on policy$policy; restoring stock limits" >> "$LOG_FILE"
            restore_applied
            exit 1
            ;;
    esac
    if [ "$readback" -gt "$target" ]; then
        echo "policy$policy exceeds requested cap; restoring stock limits" >> "$LOG_FILE"
        restore_applied
        exit 1
    fi
done

echo "Applied fixed CPU caps: CPUs 0-1 1286 MHz, CPUs 2-6 1920 MHz, CPU 7 2515 MHz" >> "$LOG_FILE"
