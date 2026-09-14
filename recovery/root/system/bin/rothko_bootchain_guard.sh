#!/system/bin/sh

TAG=ROTHKO_GUARD
BASE=/tmp/rothko_bootchain_guard
LOGFILE=/tmp/recovery.log
BLOCKDEV=/system/bin/blockdev
DD=/system/bin/busybox
SHA256SUM=/system/bin/sha256sum
STAT=/system/bin/stat
READLINK=/system/bin/readlink
AWK=/system/bin/awk

[ -n "$ROTHKO_GUARD_BASE" ] && BASE="$ROTHKO_GUARD_BASE"
[ -n "$ROTHKO_GUARD_LOG" ] && LOGFILE="$ROTHKO_GUARD_LOG"
[ -n "$ROTHKO_GUARD_BLOCKDEV" ] && BLOCKDEV="$ROTHKO_GUARD_BLOCKDEV"
[ -n "$ROTHKO_GUARD_DD" ] && DD="$ROTHKO_GUARD_DD"
[ -n "$ROTHKO_GUARD_SHA256SUM" ] && SHA256SUM="$ROTHKO_GUARD_SHA256SUM"
[ -n "$ROTHKO_GUARD_STAT" ] && STAT="$ROTHKO_GUARD_STAT"
[ -n "$ROTHKO_GUARD_READLINK" ] && READLINK="$ROTHKO_GUARD_READLINK"
[ -n "$ROTHKO_GUARD_AWK" ] && AWK="$ROTHKO_GUARD_AWK"

PRELOADER_A=/dev/block/sda
PRELOADER_B=/dev/block/sdb
LK_A=/dev/block/by-name/lk_a
LK_B=/dev/block/by-name/lk_b
[ -n "$ROTHKO_GUARD_PRELOADER_A" ] && PRELOADER_A="$ROTHKO_GUARD_PRELOADER_A"
[ -n "$ROTHKO_GUARD_PRELOADER_B" ] && PRELOADER_B="$ROTHKO_GUARD_PRELOADER_B"
[ -n "$ROTHKO_GUARD_LK_A" ] && LK_A="$ROTHKO_GUARD_LK_A"
[ -n "$ROTHKO_GUARD_LK_B" ] && LK_B="$ROTHKO_GUARD_LK_B"

SIZE_PRELOADER_A=4194304
SIZE_PRELOADER_B=4194304
SIZE_LK_A=16777216
SIZE_LK_B=16777216
[ -n "$ROTHKO_GUARD_SIZE_PRELOADER_A" ] && SIZE_PRELOADER_A="$ROTHKO_GUARD_SIZE_PRELOADER_A"
[ -n "$ROTHKO_GUARD_SIZE_PRELOADER_B" ] && SIZE_PRELOADER_B="$ROTHKO_GUARD_SIZE_PRELOADER_B"
[ -n "$ROTHKO_GUARD_SIZE_LK_A" ] && SIZE_LK_A="$ROTHKO_GUARD_SIZE_LK_A"
[ -n "$ROTHKO_GUARD_SIZE_LK_B" ] && SIZE_LK_B="$ROTHKO_GUARD_SIZE_LK_B"

TARGETS="preloader_a preloader_b lk_a lk_b"
BASELINE="$BASE/baseline"
MODE_FILE="$BASE/mode"
TAINT_FILE="$BASE/tainted"
ACTIVE_FILE="$BASE/package_active"
DEPTH_FILE="$BASE/package_depth"
LOCK_DIR="$BASE/lockdir"

log_msg() {
    line="$TAG: $*"
    echo "$line"
    # Recovery Exec_Cmd already copies stdout into recovery.log. Avoid adding
    # the same line directly when the caller declares that stdout is captured.
    if [ "${ROTHKO_GUARD_STDOUT_CAPTURED:-0}" != "1" ]; then
        echo "$line" >> "$LOGFILE" 2>/dev/null || true
    fi
    echo "$line" > /dev/kmsg 2>/dev/null || true
}

set_guard_property() {
    command -v setprop >/dev/null 2>&1 || return 0
    setprop "$1" "$2" 2>/dev/null || true
}

target_device() {
    case "$1" in
        preloader_a) echo "$PRELOADER_A" ;;
        preloader_b) echo "$PRELOADER_B" ;;
        lk_a) echo "$LK_A" ;;
        lk_b) echo "$LK_B" ;;
        *) return 1 ;;
    esac
}

target_expected_size() {
    case "$1" in
        preloader_a) echo "$SIZE_PRELOADER_A" ;;
        preloader_b) echo "$SIZE_PRELOADER_B" ;;
        lk_a) echo "$SIZE_LK_A" ;;
        lk_b) echo "$SIZE_LK_B" ;;
        *) return 1 ;;
    esac
}

resolve_device() {
    candidate=$(target_device "$1") || return 1
    [ -b "$candidate" ] || {
        log_msg "missing block device for $1: $candidate"
        return 1
    }
    resolved=$("$READLINK" -f "$candidate" 2>/dev/null)
    [ -n "$resolved" ] || resolved="$candidate"
    [ -b "$resolved" ] || return 1
    echo "$resolved"
}

device_size() {
    "$BLOCKDEV" --getsize64 "$1" 2>/dev/null
}

device_devt() {
    "$STAT" -Lc '%t:%T' "$1" 2>/dev/null
}

device_hash() {
    output=$("$SHA256SUM" "$1" 2>/dev/null) || return 1
    echo "$output" | "$AWK" '{print $1}'
}

backup_hash() {
    output=$("$SHA256SUM" "$1" 2>/dev/null) || return 1
    echo "$output" | "$AWK" '{print $1}'
}

storage_identity() {
    if [ -n "$ROTHKO_GUARD_STORAGE_ID" ]; then
        echo "$ROTHKO_GUARD_STORAGE_ID"
        return 0
    fi
    model=$(cat /sys/class/block/sdc/device/model 2>/dev/null | tr -d ' \r\n')
    rev=$(cat /sys/class/block/sdc/device/rev 2>/dev/null | tr -d ' \r\n')
    size=$(cat /sys/class/block/sdc/size 2>/dev/null | tr -d ' \r\n')
    [ -n "$model" ] && [ -n "$size" ] || return 1
    echo "$model:$rev:$size"
}

set_target_ro() {
    name="$1"
    attempts=0
    while [ "$attempts" -lt 15 ]; do
        dev=$(resolve_device "$name") || dev=
        if [ -n "$dev" ] && "$BLOCKDEV" --setro "$dev" >/dev/null 2>&1; then
            ro=$("$BLOCKDEV" --getro "$dev" 2>/dev/null) || ro=
            [ "$ro" = "1" ] && return 0
        fi
        attempts=$((attempts + 1))
        [ "$attempts" -lt 15 ] && sleep 1
    done
    log_msg "timed out setting $name read-only"
    return 1
}

set_target_rw() {
    dev=$(resolve_device "$1") || return 1
    "$BLOCKDEV" --setrw "$dev" >/dev/null 2>&1 || return 1
    ro=$("$BLOCKDEV" --getro "$dev" 2>/dev/null) || return 1
    [ "$ro" = "0" ] || return 1
}

set_all_ro() {
    failed=0
    for name in $TARGETS; do
        if ! set_target_ro "$name"; then
            log_msg "failed to set $name read-only"
            failed=1
        fi
    done
    [ "$failed" = "0" ]
}

set_all_rw() {
    failed=0
    for name in $TARGETS; do
        if ! set_target_rw "$name"; then
            log_msg "failed to set $name read-write"
            failed=1
        fi
    done
    [ "$failed" = "0" ]
}

meta_value() {
    key="$1"
    file="$2"
    sed -n "s/^$key=//p" "$file" | head -n 1
}

snapshot_target() {
    name="$1"
    outdir="$2"
    dev=$(resolve_device "$name") || return 1
    expected_size=$(target_expected_size "$name") || return 1
    actual_size=$(device_size "$dev") || return 1
    [ "$actual_size" = "$expected_size" ] || {
        log_msg "$name size mismatch: expected=$expected_size actual=$actual_size"
        return 1
    }

    set_target_ro "$name" || return 1
    backup="$outdir/$name.img"
    blocks=$((expected_size / 1048576))
    "$DD" dd if="$dev" of="$backup" bs=1048576 count="$blocks" iflag=fullblock conv=fsync status=none 2>/dev/null || return 1
    copied=$("$STAT" -Lc '%s' "$backup" 2>/dev/null) || return 1
    [ "$copied" = "$expected_size" ] || return 1

    gold_hash=$(backup_hash "$backup") || return 1
    verify_hash=$(device_hash "$dev") || return 1
    [ "$gold_hash" = "$verify_hash" ] || {
        log_msg "$name changed while creating baseline"
        return 1
    }

    devt=$(device_devt "$dev") || return 1
    {
        echo "name=$name"
        echo "device=$dev"
        echo "devt=$devt"
        echo "size=$expected_size"
        echo "sha256=$gold_hash"
    } > "$outdir/$name.meta"
    chmod 0400 "$backup" "$outdir/$name.meta"
    log_msg "baseline $name size=$expected_size sha256=$gold_hash device=$dev devt=$devt"
}

snapshot_all() {
    identity=$(storage_identity) || {
        log_msg "unable to identify UFS storage"
        return 1
    }
    next="$BASE/baseline.new.$$"
    old="$BASE/baseline.old.$$"
    mkdir -p "$next" || return 1
    chmod 0700 "$next"

    for name in $TARGETS; do
        if ! snapshot_target "$name" "$next"; then
            rm -rf "$next"
            return 1
        fi
    done
    echo "$identity" > "$next/storage_identity"
    chmod 0400 "$next/storage_identity"

    if [ -d "$BASELINE" ]; then
        mv "$BASELINE" "$old" || {
            rm -rf "$next"
            return 1
        }
    fi
    mv "$next" "$BASELINE" || {
        [ -d "$old" ] && mv "$old" "$BASELINE"
        return 1
    }
    [ -d "$old" ] && rm -rf "$old"
    rm -f "$TAINT_FILE"
    set_guard_property sys.rothko.guard.tainted 0
    log_msg "new per-device boot-chain baseline is ready"
}

baseline_valid() {
    [ -r "$BASELINE/storage_identity" ] || return 1
    for name in $TARGETS; do
        [ -r "$BASELINE/$name.img" ] || return 1
        [ -r "$BASELINE/$name.meta" ] || return 1
    done
}

validate_identity() {
    saved=$(cat "$BASELINE/storage_identity" 2>/dev/null) || return 1
    current=$(storage_identity) || return 1
    [ "$saved" = "$current" ] || {
        log_msg "storage identity mismatch: saved=$saved current=$current"
        return 1
    }
}

repair_target() {
    name="$1"
    meta="$BASELINE/$name.meta"
    backup="$BASELINE/$name.img"
    dev=$(resolve_device "$name") || return 1

    saved_dev=$(meta_value device "$meta")
    saved_devt=$(meta_value devt "$meta")
    saved_size=$(meta_value size "$meta")
    saved_hash=$(meta_value sha256 "$meta")
    current_devt=$(device_devt "$dev") || return 1
    current_size=$(device_size "$dev") || return 1
    actual_backup_hash=$(backup_hash "$backup") || return 1

    [ "$dev" = "$saved_dev" ] || return 1
    [ "$current_devt" = "$saved_devt" ] || return 1
    [ "$current_size" = "$saved_size" ] || return 1
    [ "$actual_backup_hash" = "$saved_hash" ] || return 1

    first=$(device_hash "$dev") || return 1
    second=$(device_hash "$dev") || return 1
    [ "$first" = "$second" ] || {
        log_msg "$name produced unstable hashes; refusing automatic write"
        return 1
    }

    log_msg "restoring $name from verified session baseline"
    set_target_rw "$name" || return 1
    blocks=$((saved_size / 1048576))
    if ! "$DD" dd if="$backup" of="$dev" bs=1048576 count="$blocks" iflag=fullblock conv=fsync status=none 2>/dev/null; then
        set_target_ro "$name" >/dev/null 2>&1 || true
        return 1
    fi
    "$BLOCKDEV" --flushbufs "$dev" >/dev/null 2>&1 || true
    set_target_ro "$name" || return 1
    restored=$(device_hash "$dev") || return 1
    [ "$restored" = "$saved_hash" ] || return 1
    log_msg "restored and verified $name sha256=$restored"
}

verify_target() {
    name="$1"
    repair="$2"
    meta="$BASELINE/$name.meta"
    backup="$BASELINE/$name.img"
    [ -r "$meta" ] && [ -r "$backup" ] || return 1

    dev=$(resolve_device "$name") || return 1
    saved_dev=$(meta_value device "$meta")
    saved_devt=$(meta_value devt "$meta")
    saved_size=$(meta_value size "$meta")
    saved_hash=$(meta_value sha256 "$meta")
    current_devt=$(device_devt "$dev") || return 1
    current_size=$(device_size "$dev") || return 1
    actual_backup_hash=$(backup_hash "$backup") || return 1

    [ "$dev" = "$saved_dev" ] || return 1
    [ "$current_devt" = "$saved_devt" ] || return 1
    [ "$current_size" = "$saved_size" ] || return 1
    [ "$actual_backup_hash" = "$saved_hash" ] || {
        log_msg "$name baseline backup hash mismatch"
        return 1
    }

    current_hash=$(device_hash "$dev") || return 1
    if [ "$current_hash" = "$saved_hash" ]; then
        log_msg "verified $name sha256=$current_hash"
        return 0
    fi

    log_msg "integrity mismatch $name expected=$saved_hash actual=$current_hash"
    [ "$repair" = "1" ] || return 1
    repair_target "$name"
}

verify_all() {
    repair="$1"
    baseline_valid || {
        log_msg "baseline is missing or incomplete"
        return 1
    }
    validate_identity || return 1
    failed=0
    for name in $TARGETS; do
        verify_target "$name" "$repair" || failed=1
    done
    if [ "$failed" = "0" ]; then
        rm -f "$TAINT_FILE"
        set_guard_property sys.rothko.guard.tainted 0
        return 0
    fi
    echo 1 > "$TAINT_FILE"
    set_guard_property sys.rothko.guard.tainted 1
    log_msg "boot-chain verification failed; reboot must be avoided"
    return 1
}

mode_get() {
    mode=$(cat "$MODE_FILE" 2>/dev/null)
    [ "$mode" = "disabled" ] && echo disabled || echo enabled
}

mode_set() {
    echo "$1" > "$MODE_FILE"
    if [ "$1" = "enabled" ]; then
        set_guard_property sys.rothko.guard.enabled 1
    else
        set_guard_property sys.rothko.guard.enabled 0
    fi
}

guard_init() {
    set_all_ro || return 1
    snapshot_all || return 1
    mode_set enabled
    set_guard_property sys.rothko.guard.ready 1
    log_msg "protection enabled for sda, sdb, lk_a and lk_b"
}

guard_enable() {
    [ ! -e "$ACTIVE_FILE" ] || return 1
    set_all_ro || return 1
    snapshot_all || return 1
    mode_set enabled
    set_guard_property sys.rothko.guard.ready 1
    log_msg "protection enabled for all writers and baseline refreshed"
}

guard_disable() {
    [ ! -e "$ACTIVE_FILE" ] || {
        log_msg "cannot disable protection during package installation"
        return 1
    }
    baseline_valid || return 1
    set_all_ro || return 1
    verify_all 1 || return 1
    set_all_rw || return 1
    mode_set disabled
    log_msg "protection disabled; manual, ZIP, payload and OTA writes are allowed for this Recovery session"
}

package_begin() {
    if [ -e "$ACTIVE_FILE" ]; then
        depth=$(cat "$DEPTH_FILE" 2>/dev/null)
        [ -n "$depth" ] || depth=1
        echo $((depth + 1)) > "$DEPTH_FILE"
        return 0
    fi

    if [ "$(mode_get)" = "disabled" ]; then
        log_msg "package transaction is unprotected because protection is disabled"
        return 0
    fi

    set_all_ro || return 1
    if baseline_valid; then
        verify_all 1 || return 1
    else
        snapshot_all || return 1
    fi

    echo 1 > "$DEPTH_FILE"
    echo 1 > "$ACTIVE_FILE"
    set_guard_property sys.rothko.guard.package 1
    log_msg "package transaction started with LK/preloader protection enabled"
}

package_end() {
    [ -e "$ACTIVE_FILE" ] || return 0
    depth=$(cat "$DEPTH_FILE" 2>/dev/null)
    [ -n "$depth" ] || depth=1
    if [ "$depth" -gt 1 ]; then
        echo $((depth - 1)) > "$DEPTH_FILE"
        return 0
    fi

    set_all_ro || true
    result=0
    verify_all 1 || result=1

    rm -f "$ACTIVE_FILE" "$DEPTH_FILE"
    set_guard_property sys.rothko.guard.package 0
    mode_set enabled

    [ "$result" = "0" ] || {
        set_all_ro >/dev/null 2>&1 || true
        mode_set enabled
        return 1
    }
    log_msg "package transaction ended; protected partitions are intact"
}

guard_verify() {
    mode=$(mode_get)
    if [ "$mode" = "disabled" ]; then
        set_all_ro || return 1
        snapshot_all || return 1
        set_all_rw || return 1
        log_msg "disabled-mode baseline refreshed without changing protection state"
        return 0
    fi
    set_all_ro || return 1
    verify_all 1
}

verify_reboot() {
    if [ -e "$ACTIVE_FILE" ]; then
        set_all_ro || return 1
        verify_all 1
        return $?
    fi
    if [ "$(mode_get)" = "enabled" ]; then
        set_all_ro || return 1
        verify_all 1
        return $?
    fi
    log_msg "reboot verification skipped because manual-write protection is disabled"
    return 0
}

guard_status() {
    if [ -e "$TAINT_FILE" ]; then
        log_msg "status=tainted"
        return 3
    fi
    if [ "$(mode_get)" = "disabled" ]; then
        log_msg "status=disabled"
        return 0
    fi
    baseline_valid || {
        log_msg "status=not-ready"
        return 1
    }
    log_msg "status=enabled"
    return 0
}

mkdir -p "$BASE" || exit 1
chmod 0700 "$BASE"

lock_tries=0
while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    lock_pid=$(cat "$LOCK_DIR/pid" 2>/dev/null)
    if [ -n "$lock_pid" ] && ! kill -0 "$lock_pid" 2>/dev/null; then
        rm -f "$LOCK_DIR/pid"
        rmdir "$LOCK_DIR" 2>/dev/null || true
        continue
    fi
    lock_tries=$((lock_tries + 1))
    if [ "$lock_tries" -ge 30 ]; then
        log_msg "timed out waiting for guard lock"
        exit 1
    fi
    sleep 1
done
echo $$ > "$LOCK_DIR/pid"
release_lock() {
    rm -f "$LOCK_DIR/pid"
    rmdir "$LOCK_DIR" 2>/dev/null || true
}
trap release_lock EXIT INT TERM

CMD=status
[ "$#" -gt 0 ] && CMD="$1"

case "$CMD" in
    init) guard_init ;;
    enable) guard_enable ;;
    disable) guard_disable ;;
    package-begin) package_begin ;;
    package-end) package_end ;;
    verify) guard_verify ;;
    verify-reboot) verify_reboot ;;
    status) guard_status ;;
    *)
        log_msg "unknown command: $CMD"
        exit 2
        ;;
esac
exit $?
