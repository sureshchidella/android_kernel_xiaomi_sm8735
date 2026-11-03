#!/system/bin/sh

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

POLICIES="0:0-1 2:2-4 5:5-6 7:7"
for policy in 0 2 5 7; do
    path="/sys/devices/system/cpu/cpufreq/policy$policy"
    expected=""
    for item in $POLICIES; do
        [ "${item%%:*}" = "$policy" ] && expected=${item#*:}
    done
    actual=$(normalize_cpu_list "$(cat "$path/related_cpus" 2>/dev/null)")
    expected=$(normalize_cpu_list "$expected")
    [ -n "$expected" ] && [ "$actual" = "$expected" ] || continue
    stock=$(cat "$path/cpuinfo_max_freq" 2>/dev/null)
    case "$stock" in
        ''|*[!0-9]*) continue ;;
    esac
    echo "$stock" > "$path/scaling_max_freq" 2>/dev/null
done
