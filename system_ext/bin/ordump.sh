#! /system/bin/sh

config="$1"

#ifdef OPLUS_FEATURE_FULLDUMP
#liuyuan@BSP.Kernel.Stability, 2025/08/05, add for OTA version presentation during fulldump
function save_version_ota() {
    echo "$(getprop ro.build.version.ota)" > /proc/version_ota
    echo "save_version_ota exit code: $?" > /dev/kmsg
}
#endif OPLUS_FEATURE_FULLDUMP

case "$config" in
#ifdef OPLUS_FEATURE_FULLDUMP
#liuyuan@BSP.Kernel.Stability, 2025/08/05, add for OTA version presentation during fulldump
    "save_version_ota")
        save_version_ota
        ;;
#endif OPLUS_FEATURE_FULLDUMP
       *)

      ;;
esac