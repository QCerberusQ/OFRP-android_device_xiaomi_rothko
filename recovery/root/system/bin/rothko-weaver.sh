#!/system/bin/sh
# rothko-weaver.sh - eSE HAL -> omapi -> weaver stage for OrangeFox (rothko)
# Split out of rothko-latemount.sh: this stage opens an APDU channel to the
# eSE through mitee, so it must never run from the boot path. Start it only
# after the GUI has drawn, with:  setprop rothko.weaver.start 1
# Assumes rothko-latemount.sh has already mounted /vendor and insmod'ed
# nxp_i2c.ko + p73.ko.

exec > /dev/kmsg 2>&1
set -x

[ -x /vendor/bin/hw/vendor.xiaomi.hardware.secure_element-service ] || {
    echo "FATAL: /vendor not mounted - run rothko-latemount first"; exit 0; }

# /dev/p73 appears asynchronously after the i2c probe completes
i=0
while [ $i -lt 10 ]; do
    [ -e /dev/p73 ] && break
    sleep 1
    i=$((i+1))
done
[ -e /dev/p73 ] || { echo "FATAL: /dev/p73 missing - weaver cannot start"; exit 0; }
chmod 0660 /dev/p73
chown 1027:1027 /dev/p73

# --- Secure Element HAL -> omapi -> weaver (strict order) ------------
setprop ctl.start vendor.secure_element_hal_service
sleep 2
setprop ctl.start se_omapi
sleep 2
setprop ctl.start vendor.weaver_nxp
sleep 2

echo "rothko-weaver: orchestration complete"
getprop init.svc.vendor.weaver_nxp
