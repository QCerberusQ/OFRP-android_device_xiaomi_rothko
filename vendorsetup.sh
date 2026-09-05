#!/bin/bash
#
#	This file is part of the OrangeFox Recovery Project
#	Copyright (C) 2020-2026 The OrangeFox Recovery Project
#
#	OrangeFox is free software: you can redistribute it and/or modify
#	it under the terms of the GNU General Public License as published by
#	the Free Software Foundation, either version 3 of the License, or
#	any later version.
#
#	OrangeFox is distributed in the hope that it will be useful,
#	but WITHOUT ANY WARRANTY; without even the implied warranty of
#	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#	GNU General Public License for more details.
#
#	This software is released under GPL version 3 or any later version.
#	See <http://www.gnu.org/licenses/>.
#
#	Please maintain this if you use this script or any part of it
#

FDEVICE="rothko"

fox_get_target_device() {
  if echo "$BASH_SOURCE" | grep -q "/$FDEVICE/"; then
      FOX_BUILD_DEVICE="$FDEVICE";
  elif set | grep BASH_ARGV | grep -w \"$FDEVICE\"; then
      FOX_BUILD_DEVICE="$FDEVICE";
  elif echo "${BASH_SOURCE[0]}" | grep -q "/$FDEVICE/"; then
      FOX_BUILD_DEVICE="$FDEVICE";
  elif echo "$0" | grep -q "$FDEVICE"; then
      FOX_BUILD_DEVICE="$FDEVICE";
  fi
}

if [ -z "$1" -a -z "$FOX_BUILD_DEVICE" ]; then
   fox_get_target_device
fi

if [ "$1" = "$FDEVICE" -o "$FOX_BUILD_DEVICE" = "$FDEVICE" ]; then

	# -----------------------------------------------------------------------
	# Build environment
	# -----------------------------------------------------------------------
	export LC_ALL="C"
	export TARGET_ARCH="arm64"
	export ALLOW_MISSING_DEPENDENCIES=true
	# 64MB vendor_boot
	export FOX_DRASTIC_SIZE_REDUCTION=1
	export FOX_EXTREME_SIZE_REDUCTION=1

	# -----------------------------------------------------------------------
	# Build identity
	# -----------------------------------------------------------------------
	export FOX_BUILD_TYPE="Unofficial"

	# -----------------------------------------------------------------------
	# vendor_boot-as-recovery (boot header v4) - no recovery partition
	# -----------------------------------------------------------------------
	export FOX_VENDOR_BOOT_RECOVERY=1

	# Reference vendor_boot image: stock ramdisks are retained,
	# and only the recovery ramdisk is replaced by the build
	export FOX_REFERENCE_VENDOR_BOOT_IMAGE="$(gettop)/device/xiaomi/rothko/prebuilt/stock_vendor_boot.img"

	# -----------------------------------------------------------------------
	# Storage / Theme Paths
	# -----------------------------------------------------------------------
	export FOX_SETTINGS_ROOT_DIRECTORY=/persist/recovery
	export FOX_MISCELLANEOUS_ROOT_DIRECTORY=/sdcard

	# -----------------------------------------------------------------------
	# A/B + Virtual A/B
	# -----------------------------------------------------------------------
	export FOX_AB_DEVICE=1
	export FOX_VIRTUAL_AB_DEVICE=1

	# -----------------------------------------------------------------------
	# Partition mapper (dynamic partitions on super)
	# -----------------------------------------------------------------------
	export FOX_RECOVERY_SYSTEM_PARTITION="/dev/block/mapper/system"
	export FOX_RECOVERY_VENDOR_PARTITION="/dev/block/mapper/vendor"

	# -----------------------------------------------------------------------
	# Binaries (erofs logical partitions + lz4 ramdisk)
	# -----------------------------------------------------------------------
	export FOX_USE_FSCK_EROFS_BINARY=1
	export FOX_USE_LZ4_BINARY=1
	export FOX_REPLACE_TOOLBOX_GETPROP=1

	# -----------------------------------------------------------------------
	# Magisk / patching
	# -----------------------------------------------------------------------
	export FOX_USE_UPDATED_MAGISKBOOT=1

	# -----------------------------------------------------------------------
	# Installer behaviour
	# -----------------------------------------------------------------------
	export FOX_DELETE_AROMAFM=1

else
	if [ -z "$FOX_BUILD_DEVICE" -a -z "$BASH_SOURCE" ]; then
		echo "I: This script requires bash. Not processing the $FDEVICE $(basename $0)"
	fi
fi
