#!/system/bin/sh

# Route reboot targets through the standard bootloader_message stored at the
# start of misc. rothko's boot chain may ignore restart2("target"), while it
# does honour these BCB commands. Never write past the 2048-byte
# bootloader_message: A/B slot metadata follows it.

MISC=/dev/block/by-name/misc
TARGET="${1:-system}"
TAG=ROTHKO_BCB

log_msg() {
    echo "$TAG: $*" > /dev/kmsg 2>/dev/null || true
    echo "$TAG: $*"
}

GUARD=/system/bin/rothko_bootchain_guard.sh
if [ -f "$GUARD" ]; then
    /system/bin/sh "$GUARD" verify-reboot || {
        log_msg "boot-chain verification failed; refusing to prepare reboot target=$TARGET"
        exit 1
    }
fi

if [ ! -b "$MISC" ]; then
    log_msg "missing $MISC; target=$TARGET"
    exit 1
fi

# Clear stale recovery commands for every path first. This also makes an
# ordinary reboot leave recovery instead of looping back into it.
dd if=/dev/zero of="$MISC" bs=2048 count=1 2>/dev/null || {
    log_msg "failed to clear bootloader_message; target=$TARGET"
    exit 1
}

write_at() {
    # Do not let dd truncate a block device after the short write.
    printf '%s' "$1" | dd of="$MISC" bs=1 seek="$2" conv=notrunc 2>/dev/null
}

case "$TARGET" in
    system|clear|poweroff)
        ;;
    recovery)
        write_at 'boot-recovery' 0 || exit 1
        write_at 'recovery
' 64 || exit 1
        ;;
    bootloader)
        write_at 'bootonce-bootloader' 0 || exit 1
        ;;
    fastboot|fastbootd)
        write_at 'boot-recovery' 0 || exit 1
        write_at 'recovery
--fastboot
' 64 || exit 1
        ;;
    sideload)
        write_at 'boot-recovery' 0 || exit 1
        write_at 'recovery
--sideload
' 64 || exit 1
        ;;
    sideload-auto-reboot)
        write_at 'boot-recovery' 0 || exit 1
        write_at 'recovery
--sideload_auto_reboot
' 64 || exit 1
        ;;
    rescue)
        write_at 'boot-recovery' 0 || exit 1
        write_at 'recovery
--rescue
' 64 || exit 1
        ;;
    *)
        log_msg "unsupported target=$TARGET; BCB was cleared"
        sync
        exit 2
        ;;
esac

sync
log_msg "prepared target=$TARGET"
exit 0
