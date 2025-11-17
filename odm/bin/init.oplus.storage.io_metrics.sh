#!/vendor/bin/sh

#只在试用版本脚本有效
build_version=$(getprop ro.build.version.ota)
if [[ "$build_version" != *"PRE_"* ]];then
    exit 1
fi

function abnormal_io_on() {
    if [ -f /proc/oplus_storage/io_metrics/control/abnormal_io_enabled ];then
        echo 1 > /proc/oplus_storage/io_metrics/control/abnormal_io_enabled
    fi
}

function abnormal_io_off() {
    if [ -f /proc/oplus_storage/io_metrics/control/abnormal_io_enabled ];then
        echo 0 > /proc/oplus_storage/io_metrics/control/abnormal_io_enabled
    fi
}

case "$1" in
    "on")
        abnormal_io_on
        ;;
    "off")
        abnormal_io_off
        ;;
    *)
        ;;
esac