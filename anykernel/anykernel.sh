properties() { '
kernel.string=ZoroKernel
do.devicecheck=1
do.modules=0
do.systemless=0
do.cleanup=1
do.cleanuponabort=1
device.name1=onyx
device.name2=poco_onyx
device.name3=
device.name4=
device.name5=
supported.versions=
supported.patchlevels=
supported.vendorpatchlevels=
'; }

block=boot
is_slot_device=auto
ramdisk_compression=auto
patch_vbmeta_flag=auto
no_magisk_check=1

. tools/ak3-core.sh

ui_print "Flashing ZoroKernel..."

# Check module storage first. Stage Smooth outside the module scan path and
# activate it only after the kernel has been written successfully.
mount /data 2>/dev/null || true
modules_dir=/data/adb/modules
module_dir="$modules_dir/onyx_cpu_limits"
staged_module=/data/local/tmp/zorokernel_cpu_limits_stage
if [ ! -d "$modules_dir" ] || [ ! -w "$modules_dir" ]; then
    abort "Cannot update ZoroKernel CPU limits: /data/adb/modules is unavailable"
fi
if [ -d onyx_cpu_limits ]; then
    rm -rf "$staged_module"
    mkdir -p "$staged_module" || abort "Cannot stage Smooth CPU limits"
    cp -af onyx_cpu_limits/. "$staged_module/" || abort "Failed to stage Smooth CPU limits"
    chmod 0755 "$staged_module/service.sh" "$staged_module/uninstall.sh" || abort "Cannot set Smooth CPU limits permissions"
fi


if [ -L "/dev/block/bootdevice/by-name/init_boot_a" ] || [ -L "/dev/block/by-name/init_boot_a" ]; then
    split_boot
    flash_boot
else
    dump_boot
    write_boot
fi

# Both variants update only this kernel's own BakaSU CPU cap module. Smooth
# activates the caps; Performance removes them so the packages switch cleanly.
if [ -d onyx_cpu_limits ]; then
    rm -rf "$module_dir"
    mv "$staged_module" "$module_dir" || abort "Failed to activate Smooth CPU limits"
    ui_print "Installed Smooth CPU limits module"
else
    rm -rf "$module_dir" "$staged_module"
    ui_print "Removed Smooth CPU limits; Performance clocks selected"
fi

exit 0
