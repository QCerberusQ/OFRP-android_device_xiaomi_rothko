#
# Copyright (C) 2025 The TWRP Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

DEVICE_PATH := device/xiaomi/rothko

# Configure base.mk
$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)

# Configure core_64_bit_only.mk
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)

# Configure emulated_storage.mk
$(call inherit-product, $(SRC_TARGET_DIR)/product/emulated_storage.mk)

# Configure launch_with_vendor_ramdisk.mk
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota/launch_with_vendor_ramdisk.mk)

# Configure twrp common.mk
$(call inherit-product, vendor/twrp/config/common.mk)

# Configure OrangeFox device flags
$(call inherit-product, $(DEVICE_PATH)/fox_rothko.mk)

# API
PRODUCT_SHIPPING_API_LEVEL := 34

# Enable Fuse Passthrough
PRODUCT_PROPERTY_OVERRIDES += persist.sys.fuse.passthrough.enable=true

# TWRP in Vendor Boot
PRODUCT_PROPERTY_OVERRIDES += ro.twrp.vendor_boot=true

# A/B
ENABLE_VIRTUAL_AB := true
    
PRODUCT_PACKAGES += \
    create_pl_dev \
    create_pl_dev.recovery

PRODUCT_PACKAGES += \
    update_engine_sideload \

#decryption
PRODUCT_PACKAGES += \
    se_omapi \
    se_omapi.recovery

# Bootctrl
PRODUCT_PACKAGES += \
    android.hardware.boot@1.2-mtkimpl \
    android.hardware.boot@1.2-mtkimpl.recovery

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/init/init.recovery.mt6989.rc:$(TARGET_COPY_OUT_RECOVERY)/root/init.recovery.mt6989.rc \
    $(LOCAL_PATH)/init/init.recovery.keymint.rc:$(TARGET_COPY_OUT_RECOVERY)/root/init.recovery.keymint.rc \
    $(LOCAL_PATH)/init/empty-device.xml:$(TARGET_COPY_OUT_RECOVERY)/root/system/etc/empty-device.xml \
    $(LOCAL_PATH)/init/rothko-latemount.sh:$(TARGET_COPY_OUT_RECOVERY)/root/system/bin/rothko-latemount.sh

PRODUCT_PACKAGES_DEBUG += \
    bootctrl

PRODUCT_PACKAGES += \
    fstab.mt6989 \
    fstab.mt6989.vendor_ramdisk

# Dynamic
PRODUCT_USE_DYNAMIC_PARTITIONS := true

# Health
PRODUCT_PACKAGES += \
    android.hardware.health@2.1-impl \
    android.hardware.health@2.1-service

# Mtk plpath utils
PRODUCT_PACKAGES += \
    mtk_plpath_utils \
    mtk_plpath_utils.recovery
    
# Otacert
PRODUCT_EXTRA_RECOVERY_KEYS += \
    $(DEVICE_PATH)/security/miui_releasekey

# Soong namespaces
PRODUCT_SOONG_NAMESPACES += $(DEVICE_PATH)
