#! /system/bin/sh

config="$1"

function logOn() {
    # set log on command
    echo "sensor log on"
    local platform
    platform=`getprop ro.soc.manufacturer`
    if [ x"${platform}" = x"QTI" ]; then
        setprop ctl.stop sensor_logger_qxdm_start
        setprop ctl.start sensor_logger_qxdm_start
        return
    fi
}

function logOff() {
    # set log off command
    echo "sensor log off"
    local platform
    platform=`getprop ro.soc.manufacturer`
    if [ x"${platform}" = x"QTI" ]; then
        setprop ctl.start sensor_logger_qxdm_stop
        return
    fi
}

function checkProp() {
    local prop
    prop=$1
    # waiting for 5 seconds
    local i
    i=1
    while [ $i -le 5 ]; do
        sleep 1
        value=$(getprop ${prop})
        echo "prop ${prop} = ${value}"
        if [ x"${value}" != x"running" ]; then
            echo "Property ${prop} has changed to ${value}. Exiting."
            return
        fi
        ((i++))
    done
    echo "Waited for 5 seconds, property still running. Exiting."
    return
}

function logDump() {
    local platform
    # set log dump command
    echo "sensor log dump"

    platform=`getprop ro.soc.manufacturer`
    if [ x"${platform}" = x"QTI" ]; then
        setprop ctl.start sensor_logger_qxdm_drain
        checkProp "init.svc.sensor_logger_qxdm_drain"
        sleep 2
        setprop ctl.start sensor_logger_qxdm_stop
        checkProp "init.svc.sensor_logger_qxdm_stop"
        sleep 5
        setprop ctl.start sensor_logger_qxdm_start
        checkProp "init.svc.sensor_logger_qxdm_start"
    fi
}

case "$config" in
    "logon")
        ;;
    "logoff")
        ;;
    "logdump")
        ;;
    "logon_always")
        ;;
    "logoff_always")
        ;;
    "logdump_always")
        ;;
    *)
        ;;
esac
