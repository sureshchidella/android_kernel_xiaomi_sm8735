# Onyx CPU Limits

Simple KernelSU/BakaSU module for POCO F7 (onyx). At boot it applies one fixed set of CPU maximums:

- CPUs 0–1: 1286 MHz
- CPUs 2–6: 1920 MHz
- CPU 7: 2515 MHz

The same fixed limits are applied at every boot. They remain active during games, including BGMI, and may reduce peak performance. The module validates the expected CPU topology, available frequencies, and minimum frequencies before applying any cap. It records status and errors in `limits.log`.

Removing the module restores each policy's hardware maximum when the uninstall script runs. If the module is disabled, reboot to clear any live limits. Android thermal controls can still lower frequencies. A separate CPU manager may overwrite these settings.
