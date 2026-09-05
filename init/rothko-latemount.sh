#!/system/bin/sh
# rothko-latemount.sh - late mounts + TEE/SE bringup
# Xiaomi 14T Pro (rothko) - MediaTek MT6989, Virtual A/B, erofs logical partitions
exec > /dev/kmsg 2>&1
set -x
setenforce 0
SLOT=$(getprop ro.boot.slot_suffix)
echo "SLOT=[$SLOT]"
ls -la /dev/block/mapper/

# wait for TWRP to map the logical partitions
i=0
while [ $i -lt 30 ]; do
    [ -e /dev/block/mapper/odm$SLOT ] && [ -e /dev/block/mapper/system$SLOT ] && break
    sleep 1
    i=$((i+1))
done

mkdir -p /system_root

# mount and verify each one; retry until the mount actually takes
# (erofs stock images, ext4 fallback for custom ROMs)
i=0
while [ $i -lt 60 ]; do
    grep -q " /vendor " /proc/mounts || { mount -t erofs -o ro /dev/block/mapper/vendor$SLOT /vendor || mount -t ext4 -o ro /dev/block/mapper/vendor$SLOT /vendor; }
    grep -q " /odm " /proc/mounts || { mount -t erofs -o ro /dev/block/mapper/odm$SLOT /odm || mount -t ext4 -o ro /dev/block/mapper/odm$SLOT /odm; }
    grep -q " /system_root " /proc/mounts || { mount -t erofs -o ro /dev/block/mapper/system$SLOT /system_root || mount -t ext4 -o ro /dev/block/mapper/system$SLOT /system_root; }
    [ -x /vendor/bin/tee-supplicant ] && grep -q " /odm " /proc/mounts && break
    sleep 1
    i=$((i+1))
done

echo "--- mounts after wait ---"
grep -E " /vendor | /odm | /system_root " /proc/mounts
[ -x /vendor/bin/tee-supplicant ] || { echo "FATAL: /vendor not mounted"; exit 0; }

# Keystore2 blocks forever waiting for anything that is declared.
# NOTE: /system/etc/empty-device.xml must be copied into the recovery ramdisk
# (see the device.mk PRODUCT_COPY_FILES line in the report below).
mount -o bind /system/etc/empty-device.xml /vendor/etc/vintf/manifest/android.hardware.security.keymint-service.strongbox.nxp.xml
mount -o bind /system/etc/empty-device.xml /vendor/etc/vintf/manifest/android.hardware.security.sharedsecret-service.strongbox.nxp.xml

# keystore2 database dir (its init rc references it but never creates it)
mkdir -p /tmp/misc/keystore
chmod 700 /tmp/misc/keystore

# make crash reporting work
cp /system_root/system/lib64/libprocinfo.so /system_root/system/lib64/libunwindstack.so /system/lib64/

sleep 2

# TEE + RPMB device permissions (revert to root:root each boot)
chmod 0660 /dev/0:0:0:49476 /dev/0:0:0:49456 /dev/0:0:0:49488 /dev/rpmb0 /dev/ufs-bsg0 /dev/tee0 /dev/teepriv0
chown system:system /dev/0:0:0:49476 /dev/0:0:0:49456 /dev/0:0:0:49488 /dev/rpmb0 /dev/ufs-bsg0 /dev/tee0 /dev/teepriv0

# keymint + gatekeeper chain off tee-supplicant via init.recovery.keymint.rc
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

# NXP P73 secure element (StrongBox / weaver chain).
# Modules come from the retained stock vendor_boot ramdisk - guard the loads
# so a missing module logs a warning instead of aborting the script.
[ -e /lib/modules/nxp_i2c.ko ] && insmod /lib/modules/nxp_i2c.ko
[ -e /lib/modules/p73.ko ] && insmod /lib/modules/p73.ko
[ -e /dev/p73 ] || echo "WARN: /dev/p73 missing - weaver will fail"
chmod 0660 /dev/p73
chown 1027:1027 /dev/p73
setprop ctl.start vendor.secure_element_hal_service
sleep 2
setprop ctl.start se_omapi
sleep 2
setprop ctl.start vendor.weaver_nxp
sleep 2

# touchfeature (xiaomi_touch_common.ko / goodix / focaltech are loaded by
# TW_LOAD_VENDOR_MODULES in BoardConfig.mk - only fix the node perms here)
[ -e /dev/xiaomi-touch ] && { chmod 0666 /dev/xiaomi-touch; chown system system /dev/xiaomi-touch; }
setprop ctl.start touchfeature-service