# Onyx CPU Profiles

KernelSU/BakaSU module for POCO F7 (onyx), with two manual profiles:

- **Battery:** caps CPUs 0–1 at 1,286 MHz, CPUs 2–6 at 1,920 MHz, and CPU 7 at 2,515 MHz.
- **Gaming:** removes this module’s caps by restoring each CPU policy’s hardware maximum. Android, Power HAL and thermal limits remain active.

After installing the module, open its WebUI. Choose Battery for everyday use, then choose Gaming before starting BGMI at Balanced + 90 FPS. Changes apply live; a restart is normally unnecessary. The last selection is applied again after boot. The default is Gaming/stock until you explicitly choose Battery.

The module checks that all four onyx CPU policies are present and have the expected CPU mapping. Before applying Battery, it also confirms that each requested frequency is available and is not below the policy minimum. If a write fails, it restores the previously selected profile. The module changes CPU maximums only; it does not alter minimums, governors, GPU, scheduler or thermal settings.

This is a device-specific tuning profile, not a battery-life or frame-rate guarantee. Do not use another CPU manager to set policy maximums at the same time. If you disable or remove the module, reboot to clear its runtime limits.
