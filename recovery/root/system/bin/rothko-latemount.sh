#!/system/bin/sh
# rothko-latemount.sh - FBE decryption orchestration for OrangeFox (rothko)
# Mounts vendor/odm/vendor_dlkm, loads the NXP Secure Element modules
# from the LIVE vendor_dlkm (OTA-safe vermagic), then starts the
# TEE -> keymint -> keystore2 chain in strict dependency order.
# The eSE HAL -> omapi -> weaver chain is NOT started here; see
# rothko-weaver.sh.

exec > /dev/kmsg 2>&1
set -x
setenforce 0

SLOT=$(getprop ro.boot.slot_suffix)
echo "rothko-latemount: SLOT=[$SLOT]"

# --- 1. Wait for the logical partitions to be mapped (up to 30 s) ----
i=0
while [ $i -lt 30 ]; do
    [ -e /dev/block/mapper/vendor$SLOT ] && \
    [ -e /dev/block/mapper/odm$SLOT ] && \
    [ -e /dev/block/mapper/vendor_dlkm$SLOT ] && break
    sleep 1
    i=$((i+1))
done

# --- 2. Mount /vendor, /odm, /vendor_dlkm (erofs first, ext4 fallback)
mount_part() {
    grep -q " $1 " /proc/mounts && return 0
    mount -t erofs -o ro /dev/block/mapper/$(basename $1)$SLOT $1 2>/dev/null || \
    mount -t ext4  -o ro /dev/block/mapper/$(basename $1)$SLOT $1 2>/dev/null
    grep -q " $1 " /proc/mounts
}

mkdir -p /vendor /odm /vendor_dlkm /system_root
i=0
while [ $i -lt 60 ]; do
    mount_part /vendor
    mount_part /odm
    mount_part /vendor_dlkm
    [ -x /vendor/bin/tee-supplicant ] && [ -e /vendor_dlkm/lib/modules/p73.ko ] && break
    sleep 1
    i=$((i+1))
done

echo "--- mounts ---"
grep -E " /vendor | /odm | /vendor_dlkm " /proc/mounts
[ -x /vendor/bin/tee-supplicant ] || { echo "FATAL: /vendor not mounted"; exit 0; }

# --- 3. Hide StrongBox VINTF manifests: keystore2 blocks forever ---
# --- waiting on declared instances it can never get in recovery ------
for m in /vendor/etc/vintf/manifest/*strongbox*.xml /odm/etc/vintf/manifest/*strongbox*.xml; do
    [ -e "$m" ] && mount -o bind /system/etc/empty-device.xml "$m"
done

# keystore2 database dir (its rc references it but never creates it)
mkdir -p /tmp/misc/keystore
chmod 700 /tmp/misc/keystore

# --- 4. TEE + RPMB permissions (re-apply; ueventd may reset them) ----
chmod 0660 /dev/tee0 /dev/teepriv0 /dev/rpmb0 /dev/ufs-bsg0 /dev/0:0:0:49476
chown system:system /dev/tee0 /dev/teepriv0 /dev/rpmb0 /dev/ufs-bsg0 /dev/0:0:0:49476

# --- 5. TEE -> keymint -> gatekeeper -> keystore2 --------------------
setprop ctl.start tee-supplicant
sleep 3
setprop ctl.restart vendor.keymint-mitee
setprop ctl.start delayed_gatekeeper
sleep 2
setprop apexd.status activated
setprop sys.boot_completed 1
i=0
while [ $i -lt 20 ]; do
    [ "$(getprop init.svc.vendor.keymint-mitee)" = "running" ] && break
    sleep 1
    i=$((i+1))
done
sleep 3
setprop ctl.restart keystore2

# --- 6. NXP Secure Element modules - THE FBE DEPENDENCY --------------
# nxp_i2c.ko MUST load before p73.ko (p73 binds to the i2c adapter
# nxp_i2c registers). Modules come from the LIVE vendor_dlkm of the
# current slot, so vermagic always matches the running kernel.
SE_DIR=""
for d in /vendor_dlkm/lib/modules /lib/modules /vendor/lib/modules; do
    [ -e "$d/p73.ko" ] && SE_DIR="$d" && break
done
[ -n "$SE_DIR" ] || { echo "FATAL: p73.ko not found - weaver cannot start"; exit 0; }
echo "rothko-latemount: SE modules from $SE_DIR"

lsmod | grep -q nxp_i2c || insmod $SE_DIR/nxp_i2c.ko
sleep 1
lsmod | grep -q p73      || insmod $SE_DIR/p73.ko

# --- 7. STOP HERE ----------------------------------------------------
# /dev/p73 access, the eSE HAL, se_omapi and weaver are deliberately not
# touched from the boot path: an APDU exchange started while the GUI is
# still probing keymint deadlocks the TEE and hangs before the first
# frame. rothko-weaver.sh does that stage, after the UI is up.
echo "rothko-latemount: mount + TEE stage complete"
getprop init.svc.vendor.keymint-mitee