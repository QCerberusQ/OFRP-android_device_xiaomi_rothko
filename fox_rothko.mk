#
#
# fox_rothko.mk - OrangeFox Configuration for Xiaomi 14T Pro (rothko)
#
# vendor_boot-as-recovery (boot header v4) - no dedicated recovery partition
# All variables verified against orangefox_build_vars.txt (07 August 2026)
#
#

# -----------------------------------------------------------------------------
# Maintainer
# -----------------------------------------------------------------------------
OF_MAINTAINER := QCerberusQ

# -----------------------------------------------------------------------------
# Screen / cutout
# -----------------------------------------------------------------------------
OF_SCREEN_H             := 2400
OF_STATUS_H             := 120
OF_STATUS_INDENT_LEFT   := 48
OF_STATUS_INDENT_RIGHT  := 48
OF_HIDE_NOTCH           := 1
OF_CLOCK_POS            := 1
OF_ALLOW_DISABLE_NAVBAR := 0
OF_OPTIONS_LIST_NUM     := 8

# -----------------------------------------------------------------------------
# Ramdisk compression - pairs with BOARD_RAMDISK_USE_LZ4 := true
# -----------------------------------------------------------------------------
OF_USE_LZ4_COMPRESSION := 1

# -----------------------------------------------------------------------------
# Encryption / decryption (FBE + metadata)
# -----------------------------------------------------------------------------
OF_FBE_METADATA_MOUNT_IGNORE      := 1
OF_SKIP_DECRYPTED_ADOPTED_STORAGE := 1
OF_FORCE_CASEFOLDING              := 1

# -----------------------------------------------------------------------------
# Data format
# -----------------------------------------------------------------------------
OF_UNBIND_SDCARD_F2FS             := 1
OF_WIPE_METADATA_AFTER_DATAFORMAT := 1
OF_VAB_ORS_WIPE_DATA_IS_FORMAT    := 1
OF_USE_DMCTL                      := 1
OF_ENABLE_ALL_PARTITION_TOOLS     := 1

# -----------------------------------------------------------------------------
# Backup - only partitions that are mounted in recovery.fstab
# -----------------------------------------------------------------------------
OF_QUICK_BACKUP_LIST := /data;/metadata;

# -----------------------------------------------------------------------------
# Misc / device quirks
# -----------------------------------------------------------------------------
OF_NO_TREBLE_COMPATIBILITY_CHECK := 1
OF_USE_GREEN_LED                 := 0
OF_UNMOUNT_SDCARDS_BEFORE_REBOOT := 1
OF_ENABLE_FRP_ADDON              := 1

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------
OF_LOOP_DEVICE_ERRORS_TO_LOG := 1
