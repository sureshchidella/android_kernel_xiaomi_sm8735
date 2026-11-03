#!/system/bin/sh

MODDIR=${0%/*/*}
PROFILE_FILE="$MODDIR/profile"

# Onyx SM8735 policies: policy0=CPU0-1, policy2=CPU2-4,
# policy5=CPU5-6, policy7=CPU7.
POLICIES="0:0-1:1286400 2:2-4:1920000 5:5-6:1920000 7:7:2515200"

normalize_cpu_list() {
    printf '%s\n' "$1" | awk '
        {
            gsub(/,/, " ")
            count = split($0, items, /[[:space:]]+/)
            for (i = 1; i <= count; i++) {
                if (items[i] == "")
                    continue
                dash = index(items[i], "-")
                if (dash) {
                    first = substr(items[i], 1, dash - 1)
                    last = substr(items[i], dash + 1)
                    for (cpu = first; cpu <= last; cpu++)
                        print cpu
                } else {
                    print items[i]
                }
            }
        }
    '
}

matches_policy() {
    path="$1"
    expected="$2"
    actual_cpus=$(normalize_cpu_list "$(cat "$path/related_cpus" 2>/dev/null)")
    expected_cpus=$(normalize_cpu_list "$expected")
    [ "$actual_cpus" = "$expected_cpus" ]
}

frequency_supported() {
    path="$1"
    target="$2"
    available=$(cat "$path/scaling_available_frequencies" 2>/dev/null)
    for frequency in $available; do
        [ "$frequency" = "$target" ] && return 0
    done
    return 1
}

stock_max() {
    cat "$1/cpuinfo_max_freq" 2>/dev/null
}

previous_profile=$(cat "$PROFILE_FILE" 2>/dev/null)
case "$previous_profile" in
    battery|gaming) ;;
    *) previous_profile=gaming ;;
esac

restore_previous_profile() {
    for item in $POLICIES; do
        policy=${item%%:*}
        rest=${item#*:}
        target=${rest##*:}
        path="/sys/devices/system/cpu/cpufreq/policy$policy"
        if [ "$previous_profile" = gaming ]; then
            target=$(stock_max "$path")
        fi
        [ -n "$target" ] && echo "$target" > "$path/scaling_max_freq" 2>/dev/null
    done
}

profile="$1"
case "$profile" in
    battery|gaming) ;;
    status)
        case "$previous_profile" in battery) label=Battery ;; *) label=Gaming ;; esac
        printf '{"profile":"%s","label":"%s"}\n' "$previous_profile" "$label"
        exit 0
        ;;
    *) echo "Usage: profile.sh {battery|gaming|status}" >&2; exit 2 ;;
esac

# Validate all policies before changing any of them.
for item in $POLICIES; do
    policy=${item%%:*}
    rest=${item#*:}
    cpus=${rest%%:*}
    path="/sys/devices/system/cpu/cpufreq/policy$policy"
    [ -r "$path/related_cpus" ] && [ -r "$path/cpuinfo_max_freq" ] && \
        [ -w "$path/scaling_max_freq" ] || {
        echo "Missing or inaccessible cpufreq controls for policy$policy" >&2
        exit 1
    }
    matches_policy "$path" "$cpus" || {
        echo "Unexpected CPU topology for policy$policy; no change applied" >&2
        exit 1
    }
done

if [ "$profile" = battery ]; then
    for item in $POLICIES; do
        policy=${item%%:*}
        rest=${item#*:}
        target=${rest##*:}
        path="/sys/devices/system/cpu/cpufreq/policy$policy"
        frequency_supported "$path" "$target" || {
            echo "Requested ${target} kHz is unavailable on policy$policy; no change applied" >&2
            exit 1
        }
        minimum=$(cat "$path/scaling_min_freq" 2>/dev/null)
        [ -n "$minimum" ] && [ "$minimum" -le "$target" ] || {
            echo "Requested cap is below policy$policy minimum; no change applied" >&2
            exit 1
        }
    done
fi

# Write each policy maximum. Preserve the prior selected profile for rollback;
# scaling_max_freq can show a lower effective limit while thermal QoS is active.
new_values=""
for item in $POLICIES; do
    policy=${item%%:*}
    rest=${item#*:}
    target=${rest##*:}
    path="/sys/devices/system/cpu/cpufreq/policy$policy"
    if [ "$profile" = gaming ]; then
        target=$(stock_max "$path")
        [ -n "$target" ] || { echo "Could not read stock max for policy$policy" >&2; exit 1; }
    fi
    new_values="$new_values $policy:$target"
done

for entry in $new_values; do
    policy=${entry%%:*}
    value=${entry#*:}
    path="/sys/devices/system/cpu/cpufreq/policy$policy/scaling_max_freq"
    if ! echo "$value" > "$path"; then
        echo "Write failed on policy$policy; restoring $previous_profile profile" >&2
        restore_previous_profile
        exit 1
    fi
    readback=$(cat "$path" 2>/dev/null)
    case "$readback" in
        ''|*[!0-9]*)
            echo "Could not verify policy$policy; restoring $previous_profile profile" >&2
            restore_previous_profile
            exit 1
            ;;
    esac
    if [ "$readback" -gt "$value" ]; then
        echo "policy$policy exceeds requested limit; restoring $previous_profile profile" >&2
        restore_previous_profile
        exit 1
    fi
done

# Persist only after all four policies accept limits at or below the request.
printf '%s\n' "$profile" > "$PROFILE_FILE.tmp" && mv "$PROFILE_FILE.tmp" "$PROFILE_FILE" || {
    echo "Could not save selected profile; restoring $previous_profile profile" >&2
    restore_previous_profile
    exit 1
}
case "$profile" in
    battery) echo "Battery profile applied: CPU0-1 1286 MHz, CPU2-6 1920 MHz, CPU7 2515 MHz." ;;
    gaming) echo "Gaming profile applied: restored each policy's cpuinfo_max_freq ceiling." ;;
esac
