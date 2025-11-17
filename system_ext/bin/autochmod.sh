#! /system/bin/sh

CURTIME=`date +%F_%H-%M-%S`
CURTIME_FORMAT=`date "+%Y-%m-%d %H:%M:%S"`

DEFAULT_LOG_BASE_PATH=/sdcard/Android/data/com.oplus.olc/files/Log
SDCARD_LOG_BASE_PATH=`getprop persist.sys.olc.log.path ${DEFAULT_LOG_BASE_PATH}`
BASE_PATH=$(dirname $(dirname ${SDCARD_LOG_BASE_PATH}))
SDCARD_LOG_TRIGGER_PATH=${BASE_PATH}/trigger

DATA_DEBUGGING_PATH=/data/debugging
DATA_OPLUS_LOG_PATH=/data/persist_log
ANR_BINDER_PATH=${DATA_DEBUGGING_PATH}/anr_binder_info
CACHE_PATH=${DATA_DEBUGGING_PATH}/cache
TCPDUMP_PATH=${DATA_DEBUGGING_PATH}/tcpdump

config="$1"

#================================== COMMON LOG =========================
function bugreportandtransfer() {
    local SOURCE_PATH=/data/user_de/0/com.android.shell/files/bugreports
    local DESTINATION_PATH=/data/oplus/psw/powermonitor
    traceTransferState "capture bugreport start"
    bugreportz
    traceTransferState "capture bugreport end"
    if [ -d "${SOURCE_PATH}" ]; then
        mkdir -p "${DESTINATION_PATH}/bugreports"
        local file_count=3
        local latest_files=$(find "$SOURCE_PATH" -maxdepth 1 -type f -printf '%T@ %p\n' | sort -nk 1 -r | head -n "$file_count" | cut -d' ' -f2-)
        for file in $latest_files; do
            cp "$file" "${DESTINATION_PATH}/bugreports"
            traceTransferState "copy $file to dir /data/oplus/psw/powermonitor/bugreports"
        done
    fi
}
function backup_unboot_log(){
    CACHE_EMPTY=`ls ${CACHE_PATH} | wc -l`
    if [ "${CACHE_EMPTY}" == "0" ];then
        return
    fi

    CACHE_PATH_FILES=`ls ${CACHE_PATH}/*`
    if [ "${CACHE_PATH_FILES}" = "" ];then
        traceTransferState "CACHE_PATH is empty"
    else
        traceTransferState "mv ${CACHE_PATH} TO ${DATA_DEBUGGING_PATH}/unboot"
        mv ${CACHE_PATH} ${DATA_DEBUGGING_PATH}/unboot
    fi
}

function initcache(){
    traceTransferState "initcache..."
    BOOT_MODE=`getprop sys.oplus_boot_mode`
    if [ x"${BOOT_MODE}" = x"ftm_at" ]; then
        traceTransferState "bootMode:${BOOT_MODE}, return!!!"
        return
    fi
    panicenable=`getprop persist.sys.assert.panic`
    camerapanic=`getprop persist.sys.assert.panic.camera`
    boot_completed=`getprop sys.boot_completed`
    if [[ x"${panicenable}" = x"true" ]] || [[ x"${camerapanic}" = x"true" ]] && [[ x"${boot_completed}" != x"1" ]]; then
        if [ ! -d /dev/log ];then
            mkdir -p /dev/log
            chmod -R 755 /dev/log
        fi
        backup_unboot_log
        traceTransferState "INITCACHE: mkdir ${CACHE_PATH}"
        mkdir -p ${CACHE_PATH}
        mkdir -p ${CACHE_PATH}/apps
        mkdir -p ${CACHE_PATH}/kernel
        mkdir -p ${CACHE_PATH}/netlog
        mkdir -p ${CACHE_PATH}/fingerprint
        chmod -R 777 ${CACHE_PATH}
        setprop sys.oplus.collectcache.start true
    fi
}

# 10M*5
function logcatcache() {
    panicenable=`getprop persist.sys.assert.panic`
    camerapanic=`getprop persist.sys.assert.panic.camera`
    if [[ "${panicenable}" = "true" ]] || [[ "${camerapanic}" = "true" ]]; then
        traceTransferState "panicenable: ${panicenable}"
        /system/bin/logcat -b main -b system -b crash -f ${CACHE_PATH}/apps/android_boot.txt -r 10240 -n 5 -v threadtime
    fi
}

# 4M*3
function radiocache() {
    radioenable=`getprop persist.sys.assert.panic`
    camerapanic=`getprop persist.sys.assert.panic.camera`
    if [[ "${radioenable}" = "true" ]] || [[ "${camerapanic}" = "true" ]]; then
        /system/bin/logcat -b radio -f ${CACHE_PATH}/apps/radio_boot.txt -r 4096 -n 3 -v threadtime
    fi
}

# 4M*10
function eventcache() {
    panicenable=`getprop persist.sys.assert.panic`
    camerapanic=`getprop persist.sys.assert.panic.camera`
    if [[ "${panicenable}" = "true" ]] || [[ "${camerapanic}" = "true" ]]; then
        /system/bin/logcat -b events -f ${CACHE_PATH}/apps/events_boot.txt -r 4096 -n 10 -v threadtime
    fi
}

# 10M*5
function kernelcache() {
    panicenable=`getprop persist.sys.assert.panic`
    camerapanic=`getprop persist.sys.assert.panic.camera`
    AGING_VERSION=`getprop persist.sys.agingtest`
    DEBUG_ENABLE=`getprop ro.debuggable`
    if [[ "${panicenable}" = "true" ]] || [[ "${camerapanic}" = "true" ]]; then
        dmesg > ${CACHE_PATH}/kernel/dmesg_boot.txt
        cat proc/boot_dmesg > ${CACHE_PATH}/kernel/uboot.txt
        cat proc/bootloader_log > ${CACHE_PATH}/kernel/bootloader.txt
        cat /sys/pmic_info/pon_reason > ${CACHE_PATH}/kernel/pon_poff_reason.txt
        cat /sys/pmic_info/poff_reason >> ${CACHE_PATH}/kernel/pon_poff_reason.txt
        cat /sys/pmic_info/ocp_status >> ${CACHE_PATH}/kernel/pon_poff_reason.txt
        if [ x"${AGING_VERSION}" = x"1" ]; then
            dmesg -w > ${CACHE_PATH}/kernel/kernel_boot_klogd.txt
        elif [ x"${DEBUG_ENABLE}" = x"1" ]; then
            /system/bin/logcat -b kernel -f ${CACHE_PATH}/kernel/kernel_boot.txt -r 10240 -n 5 -v threadtime -A
        else
            dmesg -w > ${CACHE_PATH}/kernel/kernel_boot.txt
        fi
    fi
}

#================================== COMMON LOG =========================

#================================== POWER =========================
#Linjie.Xu@PSW.AD.Power.PowerMonitor.1104067, 2018/01/17, Add for OplusPowerMonitor get dmesg at O
function kernelcacheforopm(){
  opmlogpath=`getprop sys.opm.logpath`
  chmod 777 -R ${DATA_DEBUGGING_PATH}/

  mkdir -p /data/oplus/psw/powermonitor
  chmod 777 -R /data/oplus/psw/powermonitor
  chmod 777 -R ${opmlogpath}

  temp_kernel_dir=${DATA_DEBUGGING_PATH}/powermonitor_temp/kernel

  mkdir -p ${temp_kernel_dir}
  chown system:system ${temp_kernel_dir}
  chmod 777 -R ${DATA_DEBUGGING_PATH}/powermonitor_temp
  chmod 777 -R ${temp_kernel_dir}

  touch ${temp_kernel_dir}/dmesg.txt
  chown system:system ${temp_kernel_dir}/dmesg.txt
  chmod 777 -R ${temp_kernel_dir}/dmesg.txt

  dmesg > ${temp_kernel_dir}/dmesg.txt

  cp ${temp_kernel_dir}/dmesg.txt ${opmlogpath}dmesg.txt
  chown system:system ${opmlogpath}dmesg.txt

  chmod 777 -R ${opmlogpath}dmesg.txt

  rm -rf ${DATA_DEBUGGING_PATH}/powermonitor_temp/kernel
  
}
#Jianfa.Chen@PSW.AD.PowerMonitor,add for powermonitor getting Xlog
function catchWXlogForOpm() {
  currentDateWXlog=$(date "+%Y%m%d")
  newpath=`getprop sys.opm.logpath`

  XLOG_DIR="/sdcard/Android/data/com.tencent.mm/MicroMsg/xlog"
  CRASH_DIR="/sdcard/Android/data/com.tencent.mm/MicroMsg/crash"

  mkdir -p ${newpath}/wxlog
  chmod 777 -R ${newpath}/wxlog
  #wxlog/xlog
  if [ -d "${XLOG_DIR}" ]; then
    mkdir -p ${newpath}/wxlog/xlog
    ALL_FILE=$(find ${XLOG_DIR} | grep -E ${currentDateWXlog} | xargs ls -t)
    for file in $ALL_FILE; do
      cp $file ${newpath}/wxlog/xlog/
    done
  fi

  if [ -d "${CRASH_DIR}" ];then
    mkdir -p ${newpath}/wxlog/crash
    ALL_FILE = $(find ${XLOG_DIR} | grep -E ${currentDateWXlog} | xargs ls -t)
    for file in $ALL_FILE;do
      cp $file ${newpath}/wxlog/crash
    done
  fi
  chown -R system:system ${newpath}
}

# Ruihuai.Wu@PSW.AD.PowerMonitor,add for powermonitor get violator info
function catchViolatorInfo() {
  if [ -f /proc/aoss_send_message -a -f /proc/sys_pm_violators ];then
    opmlogpath=`getprop sys.opm.logpath`
    # cat AOSS violators
    echo "{class: lpm_mon, type: rbsc, dur: 1000, flush: 15, ts_adj: 1}" > /proc/aoss_send_message
    sleep 2m
    cat /proc/sys_pm_violators > ${opmlogpath}aoss_violate.info
    # cat CXSD violators
    echo "{class: lpm_mon, type: cxpc, dur: 1000, flush: 15, ts_adj: 1}" > /proc/aoss_send_message
    sleep 2m
    cat /proc/sys_pm_violators > ${opmlogpath}cxsd_violate.info
  fi
}

# FaQuan.Yao@BSP.Power, 2024/04/03, add for checking suspend mode and reset to s2idle.
function catSuspendMode() {
    if [ -f /sys/power/mem_sleep ]; then
        opmlogpath=`getprop sys.opm.logpath`
        cat /sys/power/mem_sleep > ${opmlogpath}mem_sleep.info
        chmod 777 -R ${opmlogpath}mem_sleep.info
        chown -R system:system ${opmlogpath}mem_sleep.info
    fi
}

function checkAndResetSuspendMode() {
    if [ -f /sys/power/mem_sleep ]; then
        modes=$(cat /sys/power/mem_sleep)
        array=($modes)
        if [ "${array[0]}" != "[s2idle]" ]; then
            echo "s2idle" > /sys/power/mem_sleep
        fi
    fi
}

# Qiurun.Zhou@ANDROID.DEBUG, 2022/6/17, copy wxlog for EAP
function eapCopyWXlog() {
  currentDateWXlog=$(date "+%Y%m%d")
  newpath=`getprop sys.opm.logpath`

  XLOG_DIR="/sdcard/Android/data/com.tencent.mm/MicroMsg/xlog"
  CRASH_DIR="/sdcard/Android/data/com.tencent.mm/MicroMsg/crash"

  mkdir -p ${newpath}/wxlog
  chmod 777 -R ${newpath}/wxlog
  #wxlog/xlog
  if [ -d "${XLOG_DIR}" ]; then
    mkdir -p ${newpath}/wxlog/xlog
    ALL_FILE=$(find ${XLOG_DIR} | grep -E ${currentDateWXlog} | xargs ls -t)
    for file in $ALL_FILE; do
      cp $file ${newpath}/wxlog/xlog/
    done
  fi

  if [ -d "${CRASH_DIR}" ]; then
    mkdir -p ${newpath}/wxlog/crash
    ALL_FILE=$(find ${CRASH_DIR} | grep -E ${currentDateWXlog} | xargs ls -t)
    for file in $ALL_FILE; do
      cp $file ${newpath}/wxlog/crash/
    done
  fi
  chown -R system:system ${newpath}
}

# Chunxing.Yang@BSP.Power, 2024/04/26, add for timerfd statistic function.
function catchTimerfdInfoForOpm(){
     opmlogpath=`getprop sys.opm.logpath`
     cat /proc/oplus_lpm/oplus_timer_stats > ${opmlogpath}timerfdInfo.txt
     chown system:system ${opmlogpath}timerfdInfo.txt
}

function enableTimerfdStats(){
    if [ -f /proc/oplus_lpm/oplus_alarmtimer_hook_on ]
    then
        echo 1 > /proc/oplus_lpm/oplus_alarmtimer_hook_on
    fi
}

function disableTimerfdStats(){
    if [ -f /proc/oplus_lpm/oplus_alarmtimer_hook_on ] 
    then
        echo 0 > /proc/oplus_lpm/oplus_alarmtimer_hook_on
    fi
}

# Ruihuai.Wu@BSP.Power, 2024/04/26, add for smptp statistic function.
function enableSmptpStats() {
    if [ -f /proc/oplus_lpm_smp2p/oplus_smp2p_stats_switch ]; then
        echo 1 > /proc/oplus_lpm_smp2p/oplus_smp2p_stats_switch
    fi
}

function disableSmptpStats() {
    if [ -f /proc/oplus_lpm_smp2p/oplus_smp2p_stats_switch ]; then
        echo 0 > /proc/oplus_lpm_smp2p/oplus_smp2p_stats_switch
    fi
}

function resetSmptpStats() {
    if [ -f /proc/oplus_lpm_smp2p/oplus_smp2p_stats ]; then
        echo 0 > /proc/oplus_lpm_smp2p/oplus_smp2p_stats
    fi
}

# WangMin@ANDROID.RESCONTROL, 2023/05/11, Add for save newest wxlog when wx memleak
function copyWXlogForMemLeak() {
   newpath=`getprop sys.opm.logpath`
   XLOG_DIR="/sdcard/Android/data/com.tencent.mm/MicroMsg/xlog"
   mkdir -p ${newpath}/wxlog
   chmod 777 -R ${newpath}/wxlog
   #wxlog/xlog
   if [ -d "${XLOG_DIR}" ]; then
     mkdir -p ${newpath}/wxlog/xlog
     MM_FILE=$(find ${XLOG_DIR} | grep -E "MM_" | xargs ls -t)
     for file in $MM_FILE; do
       cp $file ${newpath}/wxlog/xlog/
     break
     done

     PUSH_FILE=$(find ${XLOG_DIR} | grep -E "PUSH_" | xargs ls -t)
     for file in $PUSH_FILE; do
       cp $file ${newpath}/wxlog/xlog/
     break
     done

     TOOL_FILE=$(find ${XLOG_DIR} | grep -E "TOOL_" | xargs ls -t)
     for file in $TOOL_FILE; do
       cp $file ${newpath}/wxlog/xlog/
     break
     done

     APPBRAND0_FILE=$(find ${XLOG_DIR} | grep -E "APPBRAND0_" | xargs ls -t)
     for file in $APPBRAND0_FILE; do
       cp $file ${newpath}/wxlog/xlog/
     break
     done

     APPBRAND1_FILE=$(find ${XLOG_DIR} | grep -E "APPBRAND1_" | xargs ls -t)
     for file in $APPBRAND1_FILE; do
       cp $file ${newpath}/wxlog/xlog/
     break
     done

     APPBRAND2_FILE=$(find ${XLOG_DIR} | grep -E "APPBRAND2_" | xargs ls -t)
     for file in $APPBRAND2_FILE; do
       cp $file ${newpath}/wxlog/xlog/
     break
     done

     APPBRAND3_FILE=$(find ${XLOG_DIR} | grep -E "APPBRAND3_" | xargs ls -t)
     for file in $APPBRAND3_FILE; do
       cp $file ${newpath}/wxlog/xlog/
     break
     done

     APPBRAND4_FILE=$(find ${XLOG_DIR} | grep -E "APPBRAND4_" | xargs ls -t)
     for file in $APPBRAND4_FILE; do
       cp $file ${newpath}/wxlog/xlog/
     break
     done

     TP_FILE=$(find ${XLOG_DIR} | grep -E "TP_" | xargs ls -t)
     for file in $TP_FILE; do
       cp $file ${newpath}/wxlog/xlog/
     break
     done
   fi
   chown -R system:system ${newpath}
}

# WangMin@ANDROID.RESCONTROL, 2023/12/13, Add for save newest browser xlog when com.haytap.browser memleak
function copyBrowserXlogForMemLeak() {
   newpath=`getprop sys.opm.logpath`
   XLOG_DIR="/sdcard/Android/data/com.heytap.browser/files/xlog/Browser/.log/xlog"
   mkdir -p ${newpath}/xlog
   chmod 777 -R ${newpath}/xlog
   #wxlog/xlog
   if [ -d "${XLOG_DIR}" ]; then
     KERNEL_FILE=$(find ${XLOG_DIR} | grep -E "Kernel_" | xargs ls -t)
     for file in $KERNEL_FILE; do
       cp $file ${newpath}/xlog/
     break
     done

     MAIN_FILE=$(find ${XLOG_DIR} | grep -E "main_" | xargs ls -t)
     for file in $MAIN_FILE; do
       cp $file ${newpath}/xlog/
     break
     done

     MEDIA_FILE=$(find ${XLOG_DIR} | grep -E "media_" | xargs ls -t)
     for file in $MEDIA_FILE; do
       cp $file ${newpath}/xlog/
     break
     done

     PROXY_FILE=$(find ${XLOG_DIR} | grep -E "proxy_" | xargs ls -t)
     for file in $PROXY_FILE; do
       cp $file ${newpath}/xlog/
     break
     done

     SWAN0_FILE=$(find ${XLOG_DIR} | grep -E "swan0_" | xargs ls -t)
     for file in $SWAN0_FILE; do
       cp $file ${newpath}/xlog/
     break
     done
   fi
   chown -R system:system ${newpath}
}

# Zhurui2@ANDROID.STABILITY, 2023/11/17, add for save newest wxlog when theia anr\crash\nfw
function copyXlogForTheia() {
   newpath="/data/persist_log/theia30"
   XLOG_DIR="/sdcard/Android/data/com.tencent.mm/MicroMsg/xlog"
   mkdir -p ${newpath}/wxlog
   chmod 777 -R ${newpath}/wxlog
   #wxlog/xlog
   if [ -d "${XLOG_DIR}" ]; then
     mkdir -p ${newpath}/wxlog/xlog
     MM_FILE=$(find ${XLOG_DIR} | grep -E "MM_" | xargs ls -t)
     for file in $MM_FILE; do
       cp $file ${newpath}/wxlog/xlog/
     break
     done

     PUSH_FILE=$(find ${XLOG_DIR} | grep -E "PUSH_" | xargs ls -t)
     for file in $PUSH_FILE; do
       cp $file ${newpath}/wxlog/xlog/
     break
     done

     TOOL_FILE=$(find ${XLOG_DIR} | grep -E "TOOL_" | xargs ls -t)
     for file in $TOOL_FILE; do
       cp $file ${newpath}/wxlog/xlog/
     break
     done

     APPBRAND0_FILE=$(find ${XLOG_DIR} | grep -E "APPBRAND0_" | xargs ls -t)
     for file in $APPBRAND0_FILE; do
       cp $file ${newpath}/wxlog/xlog/
     break
     done

     APPBRAND1_FILE=$(find ${XLOG_DIR} | grep -E "APPBRAND1_" | xargs ls -t)
     for file in $APPBRAND1_FILE; do
       cp $file ${newpath}/wxlog/xlog/
     break
     done

     APPBRAND2_FILE=$(find ${XLOG_DIR} | grep -E "APPBRAND2_" | xargs ls -t)
     for file in $APPBRAND2_FILE; do
       cp $file ${newpath}/wxlog/xlog/
     break
     done

     APPBRAND3_FILE=$(find ${XLOG_DIR} | grep -E "APPBRAND3_" | xargs ls -t)
     for file in $APPBRAND3_FILE; do
       cp $file ${newpath}/wxlog/xlog/
     break
     done

     APPBRAND4_FILE=$(find ${XLOG_DIR} | grep -E "APPBRAND4_" | xargs ls -t)
     for file in $APPBRAND4_FILE; do
       cp $file ${newpath}/wxlog/xlog/
     break
     done

     TP_FILE=$(find ${XLOG_DIR} | grep -E "TP_" | xargs ls -t)
     for file in $TP_FILE; do
       cp $file ${newpath}/wxlog/xlog/
     break
     done

     chmod 777 -R ${newpath}/wxlog/xlog
   fi
}
function catchQQlogForOpm() {
  currentDateQlog=$(date "+%y.%m.%d")
  newpath=`getprop sys.opm.logpath`
  QLOG_DIR="/sdcard/Android/data/com.tencent.mobileqq/files/tencent/msflogs/com/tencent/mobileqq"
  #qlog
  mkdir -p ${newpath}/qlog
  chmod 777 -R ${newpath}/qlog
  if [ -d "${QLOG_DIR}" ]; then
    mkdir -p ${newpath}/qlog/log
    ALL_FILE=$(find ${QLOG_DIR} | grep -E ${currentDateQlog} | xargs ls -t)
    for file in $ALL_FILE; do
      cp $file ${newpath}/qlog
    done
  fi
  chown -R system:system ${newpath}
}

function catchClockForOpm() {
  opmlogpath=`getprop sys.opm.logpath`
  if [ -f /proc/power/clk_enabled_list ]
  then
    cat /proc/power/clk_enabled_list > ${opmlogpath}clk_enabled_list.txt
    chown system:system ${opmlogpath}clk_enabled_list.txt
    chmod 777 -R ${opmlogpath}clk_enabled_list.txt
  fi
  if [ -f /proc/clk/clk_enabled_list ]
  then
    cat /proc/clk/clk_enabled_list > ${opmlogpath}clk_enabled_list.txt
    chown system:system ${opmlogpath}clk_enabled_list.txt
    chmod 777 -R ${opmlogpath}clk_enabled_list.txt
  fi
}

function enableClkDebugSuspend() {
  if [ -f /proc/clk/debug_suspend ]
  then
    echo 1 > /proc/clk/debug_suspend
  fi
}

function disableClkDebugSuspend() {
  if [ -f /proc/clk/debug_suspend ]
  then
    echo 0 > /proc/clk/debug_suspend
  fi
}

function enableRegulatorDebugSuspend() {
  if [ -f /proc/regulator/debug_suspend ]
  then
    echo 1 > /proc/regulator/debug_suspend
  fi
}

function disableRegulatorDebugSuspend() {
  if [ -f /proc/regulator/debug_suspend ]
  then
    echo 0 > /proc/regulator/debug_suspend
  fi
}

function enableSystemServerFreezeOrder() {
  if [ -f /proc/oplus_freeze_process/ss_order_adv_enable ]
  then
    echo 1 > /proc/oplus_freeze_process/ss_order_adv_enable
  fi
}

function disableSystemServerFreezeOrder() {
  if [ -f /proc/oplus_freeze_process/ss_order_adv_enable ]
  then
    echo 0 > /proc/oplus_freeze_process/ss_order_adv_enable
  fi
}

function startSsLogPower() {
    traceTransferState "startSsLogPower"
    powermonitorCustomLogDir=${DATA_DEBUGGING_PATH}/powermonitor_custom_log
    
    if [ ! -d "${powermonitorCustomLogDir}" ];then
        mkdir -p ${powermonitorCustomLogDir}
    fi
    ssLogOutputPath=${powermonitorCustomLogDir}/sslog.txt

    while [ -d "$powermonitorCustomLogDir" ]
    do
       ss -ntp -o state established >> ${ssLogOutputPath}
       sleep 15s #Sleep 15 seconds
    done
    traceTransferState "startSsLogPower_End"
}

function tranferPowerRelated() {
  traceTransferState "tranferPowerRelated"
  powerExtraLogDir="/data/oplus/psw/powermonitor_backup/extra_log";
  powermonitorCustomLogDir=${DATA_DEBUGGING_PATH}/powermonitor_custom_log
  if [ ! -d "${powerExtraLogDir}" ];then
    mkdir -p ${powerExtraLogDir}
  fi
  
  chown system:system ${powerExtraLogDir}
  chmod 777 -R ${powerExtraLogDir}/

  #collect bluetooth log
  buletoothLogSaveDir="${powerExtraLogDir}/buletooth_log";
  if [ ! -d "${buletoothLogSaveDir}" ];then
    mkdir -p ${buletoothLogSaveDir}
  fi

  tar cvzf ${buletoothLogSaveDir}/buletooth_log.tar.gz /data/misc/bluetooth/
  traceTransferState "get bluetooth log"

  #collect sslog
  sslogSourcPath=${powermonitorCustomLogDir}/sslog.txt
  if [ -f "${sslogSourcPath}" ];then
    cp ${sslogSourcPath} ${powerExtraLogDir}/sslog.txt
    traceTransferState "get sslog"
  fi

  chown system:system ${powerExtraLogDir}
  chmod 777 -R ${powerExtraLogDir}/
  
  #clear file
  rm ${sslogSourcPath}
  traceTransferState "tranferPowerRelated_end"
}

#Linjie.Xu@PSW.AD.Power.PowerMonitor.1104067, 2018/01/17, Add for OplusPowerMonitor get Sysinfo at O
function psforopm(){
  opmlogpath=`getprop sys.opm.logpath`
  ps -A -T > ${opmlogpath}psO.txt
  chown system:system ${opmlogpath}psO.txt
}
#Linjie.Xu@PSW.AD.Power.PowerMonitor.1104067, 2019/08/21, Add for OplusPowerMonitor get qrtr at Qcom
function qrtrlookupforopm() {
    echo "qrtrlookup begin"
    opmlogpath=`getprop sys.opm.logpath`
    if [ -d "/d/ipc_logging" ]; then
        echo ${opmlogpath}
        /vendor/bin/qrtr-lookup > ${opmlogpath}/qrtr-lookup_info.txt
        chown system:system ${opmlogpath}/qrtr-lookup_info.txt
    fi
    echo "qrtrlookup end"
}

function cpufreqforopm(){
  opmlogpath=`getprop sys.opm.logpath`
  cat /sys/devices/system/cpu/*/cpufreq/scaling_cur_freq > ${opmlogpath}cpufreq.txt
  chown system:system ${opmlogpath}cpufreq.txt
}

function logcatMainCacheForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  temp_android_dir=${DATA_DEBUGGING_PATH}/powermonitor_temp/android
  mkdir -p ${temp_android_dir}
  logcat -d -f ${temp_android_dir}/logcat.txt -r 4096 -n 1 -v threadtime
  cp ${temp_android_dir}/* ${opmlogpath}
  chown system:system ${opmlogpath}logcat*
  rm -rf ${DATA_DEBUGGING_PATH}/powermonitor_temp/android
}

function logcatEventCacheForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  logcat -b events -d > ${opmlogpath}events.txt
  chown system:system ${opmlogpath}events.txt
}

function logcatRadioCacheForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  logcat -b radio -d > ${opmlogpath}radio.txt
  chown system:system ${opmlogpath}radio.txt
}

function catchBinderInfoForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  cat /sys/kernel/debug/binder/state > ${opmlogpath}binderinfo.txt
  chown system:system ${opmlogpath}binderinfo.txt
}

function catchInterruptsInfoForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  cat /proc/interrupts > ${opmlogpath}interruptsInfo.txt
  chown system:system ${opmlogpath}interruptsInfo.txt
}

function catchBattertFccForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  cat /sys/class/power_supply/battery/batt_fcc > ${opmlogpath}fcc.txt
  chown system:system ${opmlogpath}fcc.txt
}

function catchTopInfoForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  opmfilename=`getprop sys.opm.logpath.filename`
  top -H -n 3 > ${opmlogpath}${opmfilename}top.txt
  chown system:system ${opmlogpath}${opmfilename}top.txt
}

function dumpsysHansHistoryForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  dumpsys activity hans history > ${opmlogpath}hans.txt
  chown system:system ${opmlogpath}hans.txt
  dumpsys activity service com.oplus.battery deepsleepRcd > ${opmlogpath}deepsleepRcd.txt
  chown system:system ${opmlogpath}deepsleepRcd.txt
}

function dumpsysSurfaceFlingerForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  dumpsys sensorservice > ${opmlogpath}sensorservice.txt
  chown system:system ${opmlogpath}sensorservice.txt
}

function dumpsysSensorserviceForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  dumpsys sensorservice > ${opmlogpath}sensorservice.txt
  chown system:system ${opmlogpath}sensorservice.txt
}

function dumpsysBatterystatsForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  dumpsys batterystats > ${opmlogpath}batterystats.txt
  chown system:system ${opmlogpath}batterystats.txt
}

function dumpsysBatterystatsOplusCheckinForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  dumpsys batterystats --oplusCheckin > ${opmlogpath}batterystats_oplusCheckin.txt
  chown system:system ${opmlogpath}batterystats_oplusCheckin.txt
}

function dumpsysBatterystatsCheckinForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  dumpsys batterystats -c > ${opmlogpath}batterystats_checkin.txt
  chown system:system ${opmlogpath}batterystats_checkin.txt
}

function dumpsysMediaForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  dumpsys media.audio_flinger > ${opmlogpath}audio_flinger.txt
  dumpsys media.audio_policy > ${opmlogpath}audio_policy.txt
  dumpsys audio > ${opmlogpath}audio.txt

  chown system:system ${opmlogpath}audio_flinger.txt
  chown system:system ${opmlogpath}audio_policy.txt
  chown system:system ${opmlogpath}audio.txt
}

function getPropForOpm(){
  opmlogpath=`getprop sys.opm.logpath`
  getprop > ${opmlogpath}prop.txt
  chown system:system ${opmlogpath}prop.txt
}
#================================== POWER =========================

#================================== PERFORMANCE =========================
function dmaprocsforhealth(){
  opmlogpath=`getprop sys.opm.logpath`
  cat /proc/dma_buf/dmaprocs > ${opmlogpath}dmaprocs.txt
  cat /proc/osvelte/dma_buf/bufinfo >> ${opmlogpath}dmaprocs.txt
  cat /proc/osvelte/dma_buf/procinfo >> ${opmlogpath}dmaprocs.txt
  chown system:system ${opmlogpath}dmaprocs.txt
}
function slabinfoforhealth(){
  opmlogpath=`getprop sys.opm.logpath`
  cat /proc/slabinfo > ${opmlogpath}slabinfo.txt
  cat /sys/kernel/debug/page_owner > ${opmlogpath}pageowner.txt
  chown system:system ${opmlogpath}slabinfo.txt
  chown system:system ${opmlogpath}pageowner.txt
}
function svelteforhealth(){
    sveltetracer=`getprop sys.opm.svelte_tracer`
    svelteops=`getprop sys.opm.svelte_ops`
    svelteargs=`getprop sys.opm.svelte_args`
    opmlogpath=`getprop sys.opm.logpath`

    if [ "${sveltetracer}" == "malloc" ]; then
        if [ "${svelteops}" == "enable" ]; then
            osvelte malloc-debug -e ${svelteargs}
        elif [ "${svelteops}" == "disable" ]; then
            osvelte malloc-debug -D ${svelteargs}
        elif [ "${svelteops}" == "dump" ]; then
            osvelte malloc-debug -d ${svelteargs} > ${opmlogpath}malloc_${svelteargs}_svelte.txt
            sleep 12
            chown system:system ${opmlogpath}*svelte.txt
        fi
    elif [ "${sveltetracer}" == "vmalloc" ]; then
        if [ "${svelteops}" == "dump" ]; then
            cat /proc/vmallocinfo > ${svelteargs}
            sleep 12
            chown system:system ${svelteargs}
        fi
    elif [ "${sveltetracer}" == "slab" ]; then
        if [ "${svelteops}" == "dump" ]; then
            cat /proc/slabinfo > ${svelteargs}
            sleep 5
            chown system:system ${svelteargs}
        fi
    elif [ "${sveltetracer}" == "kernelstack" ]; then
        if [ "${svelteops}" == "dump" ]; then
            ps -A -T > ${svelteargs}
            sleep 5
            chown system:system ${svelteargs}
        fi
    elif [ "${sveltetracer}" == "ion" ]; then
        if [ "${svelteops}" == "dump" ]; then
            cat /proc/osvelte/dma_buf/bufinfo > ${svelteargs}
            cat /proc/osvelte/dma_buf/procinfo >> ${svelteargs}
            sleep 5
            chown system:system ${svelteargs}
        fi
    elif [ "${sveltetracer}" == "gpu" ]; then
        if [ "${svelteops}" == "dump" ]; then
            dir="/sys/class/kgsl/kgsl/proc/${svelteargs}/memtype/"
            echo "${dir}" > ${opmlogpath}_gpu.txt
            for file in $(ls ${dir}); do
              echo "$file: $(cat ${dir}/$file)" >> ${opmlogpath}_gpu.txt
            done
            sleep 3
            chown system:system ${opmlogpath}*gpu.txt
        fi
    elif [ "${sveltetracer}" == "kmalloc" ]; then
        if [ "${svelteops}" == "enable" ]; then
            echo 1 > /proc/oplus_mem/memleak_detect/kmalloc_debug_enable
            echo ${svelteargs} > /proc/oplus_mem/memleak_detect/kmalloc_debug_create
        elif [ "${svelteops}" == "disable" ]; then
            echo 0 > /proc/oplus_mem/memleak_detect/kmalloc_debug_enable
        elif [ "${svelteops}" == "dump" ]; then
            cat /proc/slabinfo > ${opmlogpath}slabinfo.txt
            cat /proc/oplus_mem/memleak_detect/kmalloc_debug > ${opmlogpath}kmalloc.txt
            sleep 5
            chown system:system ${opmlogpath}slabinfo.txt
            chown system:system ${opmlogpath}kmalloc.txt
        fi
    fi
}
function meminfoforhealth(){
  opmlogpath=`getprop sys.opm.logpath`
  cat /proc/meminfo > ${opmlogpath}meminfo.txt
  chown system:system ${opmlogpath}meminfo.txt
}

#================================== PERFORMANCE =========================

#================================== NETWORK =========================
function tcpdumpcache(){
    tcpdmpenable=`getprop persist.sys.assert.panic`
    camerapanic=`getprop persist.sys.assert.panic.camera`
    argtrue='true'
    if [ "${tcpdmpenable}" = "${argtrue}" ] || [ x"${camerapanic}" = x"true" ]; then
        tcpdump -i any -p -s 0 -W 2 -C 10 -w ${CACHE_PATH}/netlog/tcpdump_boot -Z root
    fi
}

function tcpDumpLog(){
    #panicenable=`getprop persist.sys.assert.panic`
    DATA_LOG_TCPDUMPLOG_PATH=`getprop sys.oplus.logkit.netlog`
    #LiuHaipeng@NETWORK.DATA, modify for limit the tcpdump size to 300M and packet size 100 byte for power log type and other log type
    traceTransferState "tcpDumpLog tcpdumpSize=${tcpdumpSize} tcpdumpCount=${tcpdumpCount} tcpdumpPacketSize=${tcpdumpPacketSize} DATA_LOG_TCPDUMPLOG_PATH=${DATA_LOG_TCPDUMPLOG_PATH}"
    if [ "${tmpTcpdump}" != "" ]; then
        #ifndef OPLUS_FEATURE_TCPDUMP
        #DuYuanhua@NETWORK.DATA.2959182, keep root priviledge temporarily for rutils-remove action
        #tcpdump -i any -p -s 0 -W ${tcpdumpCount} -C ${tcpdumpSize} -w ${DATA_LOG_TCPDUMPLOG_PATH}/tcpdump -Z root
        #else
        #LiuHaipeng@NETWORK.DATA, modify for limit the tcpdump size to 300M and packet size 100 byte for power log type and other log type
        tcpdump -i any -p -s ${tcpdumpPacketSize} -W ${tcpdumpCount} -C ${tcpdumpSize} -w ${DATA_LOG_TCPDUMPLOG_PATH}/tcpdump -R -Z system
        #endif
    fi
}

function manualCaptureTcpdumpLog(){
    DATA_LOG_TCPDUMPLOG_PATH=`getprop sys.oplus.logkit.netlog`
    traceTransferState "tcpDumpLog tcpdumpSize=${tcpdumpSize} tcpdumpCount=${tcpdumpCount} tcpdumpPacketSize=${tcpdumpPacketSize} DATA_LOG_TCPDUMPLOG_PATH=${DATA_LOG_TCPDUMPLOG_PATH}"
    if [ "${tmpTcpdump}" != "" ]; then
        tcpdump -i any -p -s ${tcpdumpPacketSize} -W ${tcpdumpCount} -C ${tcpdumpSize} -w ${DATA_LOG_TCPDUMPLOG_PATH}/tcpdump -Z system
    fi
}
#================================== NETWORK =========================

#================================== DISPLAY Start =========================
function dumpDisplayXlog(){
    FILE_SIZE_MAX=$((8*1024*1024)) # 8MB
    FILE_COUNT_MAX=15
    SOURCE_PATH=/proc/oplus_display/dump
    TARGET_PATH=${DATA_DEBUGGING_PATH}/display/xlog

    if [ ! -d "${TARGET_PATH}" ]; then
        mkdir -p ${TARGET_PATH}
    fi

    chmod 777 -R ${TARGET_PATH}
    chown system:system ${TARGET_PATH}

    # Initialize current_log_file with the latest existing file
    log_files=(${TARGET_PATH}/display_xlog_*.txt)
    if [ ${#log_files[@]} -eq 0 ] || [ ! -e "${log_files[0]}" ]; then
        # No existing files, create a new one
        current_timestamp=$(date +%Y%m%d_%H%M%S)
        current_log_file=${TARGET_PATH}/display_xlog_${current_timestamp}.txt
    else
        # Find the latest file
        current_log_file=${log_files[0]}
        for file in "${log_files[@]}"; do
            if [[ $file -nt $current_log_file ]]; then
                current_log_file=$file
            fi
        done
    fi

    echo "display xlog loop"
    while true
    do
        if [ -f ${SOURCE_PATH} ]; then
            # Check if the current log file exists and its size
            if [ -f ${current_log_file} ]; then
                filesize=$(stat -c%s ${current_log_file})
            else
                filesize=0
            fi

            if [ ${filesize} -lt ${FILE_SIZE_MAX} ]; then
                cat ${SOURCE_PATH} >> ${current_log_file}
            else
                # Create a new log file with the current timestamp
                current_timestamp=$(date +%Y%m%d_%H%M%S)
                current_log_file=${TARGET_PATH}/display_xlog_${current_timestamp}.txt
                cat ${SOURCE_PATH} > ${current_log_file}
            fi

            # Check the number of log files and delete the oldest if necessary
            log_files=(${TARGET_PATH}/display_xlog_*.txt)
            if [ ${#log_files[@]} -gt ${FILE_COUNT_MAX} ]; then
                oldest_file=${log_files[0]}
                for file in "${log_files[@]}"; do
                    if [[ $file -ot $oldest_file ]]; then
                        oldest_file=$file
                    fi
                done
                rm $oldest_file
            fi
        fi
        sleep 1
    done
}

function displayLog(){
    dumpDisplayXlog
}
#================================== DISPLAY End =========================

#================================== FINGERPRINT =========================
function fingerprintcache(){
    platform=`getprop ro.board.platform`
    echo "platform ${platform}"
    state=`cat /proc/oplus_secure_common/secureSNBound`
    logEncrState=`cat /proc/oplus_secure_common/oemLogEncrypt`

    if [ ${state} != "0" ] || [ ${state} = "0" -a ${logEncrState} != "0" ]
    then
        cat /sys/kernel/debug/tzdbg/log > ${CACHE_PATH}/fingerprint/fingerprint_boot.txt
        if [ -f /proc/tzdbg/log ]
        then
            cat /proc/tzdbg/log > ${CACHE_PATH}/fingerprint/fingerprint_boot.txt
        fi
    fi
}

function fplogcache(){
    platform=`getprop ro.board.platform`

    state=`cat /proc/oplus_secure_common/secureSNBound`
    logEncrState=`cat /proc/oplus_secure_common/oemLogEncrypt`

    if [ ${state} != "0" ] || [ ${state} = "0" -a ${logEncrState} != "0" ]
    then
        cat /sys/kernel/debug/tzdbg/qsee_log > ${CACHE_PATH}/fingerprint/qsee_boot.txt
        if [ -f /proc/tzdbg/qsee_log ]
        then
            cat /proc/tzdbg/qsee_log > ${CACHE_PATH}/fingerprint/qsee_boot.txt
        fi
    fi
}

function fingerprintLog(){
    countfp=0
    maxcount=10 #limit Log size about 200M
    state=`cat /proc/oplus_secure_common/secureSNBound`
    logEncrState=`cat /proc/oplus_secure_common/oemLogEncrypt`

    echo "fingerprint state = ${state}; logEncrState = ${logEncrState}"
    if [ ${state} != "0" ] || [ ${state} = "0" -a ${logEncrState} != "0" ]
    then
        FP_LOG_PATH=`getprop sys.oplus.logkit.fingerprintlog`

        chmod -R 777 ${FP_LOG_PATH}
        chown system:system ${FP_LOG_PATH}

        #Bin.Lv@BSP.Security.Basic, 2023/01/30, Add for record key status to logtool
        echo "security_key_status read..."
        echo "" > ${FP_LOG_PATH}/security_key_status.txt
        echo "====== OTA VERSION ======" >> ${FP_LOG_PATH}/security_key_status.txt
        getprop ro.build.version.ota >> ${FP_LOG_PATH}/security_key_status.txt
        echo "====== DEVICE STATUS ======" >> ${FP_LOG_PATH}/security_key_status.txt
        getprop ro.boot.vbmeta.device_state >> ${FP_LOG_PATH}/security_key_status.txt
        echo "====== SECUREBOOT STAGE 0-OFF 2-STAGE ONE 3-STAGE TWO ======" >> ${FP_LOG_PATH}/security_key_status.txt
        cat /proc/oplus_secure_common/secureType >> ${FP_LOG_PATH}/security_key_status.txt

        echo "fingerprint in loop"
        while true
        do
            if [ -f /proc/tzdbg/log ]
            then
                chmod -R 777 ${FP_LOG_PATH}
                chown system:system ${FP_LOG_PATH}
                if [ -f ${FP_LOG_PATH}/tz_log${countfp}.txt ]
                then
                    filesize=`ls -l ${FP_LOG_PATH}/tz_log${countfp}.txt | awk '{print $5}'`
                else
                    filesize=$((1024*1000000))
                fi
                maxsize=$((20*1024*1024)) #20MB
                if [ $filesize -lt $maxsize ]
                then
                    cat /proc/tzdbg/log >> ${FP_LOG_PATH}/tz_log${countfp}.txt
                else
                    ((countfp++))
                    cat /proc/tzdbg/log > ${FP_LOG_PATH}/tz_log${countfp}.txt
                    if [ $countfp -gt $maxcount ]
                    then
                        rm ${FP_LOG_PATH}/tz_log$((countfp-maxcount)).txt;
                    fi
                fi
            fi
            if [ ! -s ${FP_LOG_PATH}/tz_log${countfp}.txt ];then
                rm ${FP_LOG_PATH}/tz_log${countfp}.txt;
                ((countfp--))
            fi
            sleep 1
        done
    fi
}

function fingerprintQseeLog(){
    countqsee=0
    maxcount=10 #limit Log size about 200M
    state=`cat /proc/oplus_secure_common/secureSNBound`
    logEncrState=`cat /proc/oplus_secure_common/oemLogEncrypt`
    echo "fingerprint state = ${state}; logEncrState = ${logEncrState}"
    if [ ${state} != "0" ] || [ ${state} = "0" -a ${logEncrState} != "0" ]
    then
        FP_LOG_PATH=`getprop sys.oplus.logkit.fingerprintlog`
        echo "fingerprint qsee in loop"
        while true
        do
            if [ -f /proc/tzdbg/qsee_log ] #22021 first stage device block
            then
                chmod -R 777 ${FP_LOG_PATH}
                chown system:system ${FP_LOG_PATH}
                if [ -f ${FP_LOG_PATH}/qsee_log${countqsee}.txt ]
                then
                    filesize=`ls -l ${FP_LOG_PATH}/qsee_log${countqsee}.txt | awk '{print $5}'`
                else
                    filesize=$((1024*1000000))
                fi
                maxsize=$((20*1024*1024)) #20MB
                if [ $filesize -lt $maxsize ]
                then
                    chmod -R 777 ${FP_LOG_PATH}
                    chown system:system ${FP_LOG_PATH}
                    cat /proc/tzdbg/qsee_log >> ${FP_LOG_PATH}/qsee_log${countqsee}.txt
                else
                    chmod -R 777 ${FP_LOG_PATH}
                    chown system:system ${FP_LOG_PATH}
                    ((countqsee++))
                    cat /proc/tzdbg/qsee_log > ${FP_LOG_PATH}/qsee_log${countqsee}.txt
                    if [ $countqsee -gt $maxcount ]
                    then
                        rm ${FP_LOG_PATH}/qsee_log$((countqsee-maxcount)).txt;
                        ((countrmqsee++))
                    fi
                fi
            fi
            if [ ! -s ${FP_LOG_PATH}/qsee_log${countqsee}.txt ];then
                rm ${FP_LOG_PATH}/qsee_log${countqsee}.txt;
                ((countqsee--))
            fi
            sleep 1
        done
    fi
}
#================================== FINGERPRINT =========================

#================================== COMMON LOG =========================
function initOplusLog(){
    if [ ! -d /dev/log ];then
        mkdir -p /dev/log
        chmod -R 755 /dev/log
    fi

    traceTransferState "INITOPLUSLOG: start..."

    # TODO less 2G stop logcat, return
    PANICE_NABLE=`getprop persist.sys.assert.panic`
    CAMERA_PANIC_ENABLE=`getprop persist.sys.assert.panic.camera`
    BOOT_MODE=`getprop sys.oplus_boot_mode`
    if [ "${PANICE_NABLE}" = "true" ] || [ x"${CAMERA_PANIC_ENABLE}" = x"true" ]; then
        boot_completed=`getprop sys.boot_completed`
        decrypt_delay=0
        bootCompleteCount=0
        while [ x${boot_completed} != x"1" ];do
            bootCompleteCount=$((bootCompleteCount + 1))
            sleep 1
            decrypt_delay=`expr $decrypt_delay + 1`
            boot_completed=`getprop sys.boot_completed`
            if [ bootCompleteCount -ge 5 ] && [ x"${BOOST_MODE}" = x"ftm_at" ]; then
                break
            fi
        done
        traceTransferState "sleep time: ${bootCompleteCount}"

        echo "start mkdir"
        CURTIME_DEBUG_PATH=`getprop persist.sys.com.oplus.debug.time`
        DATA_LOG_DEBUG_PATH=${DATA_DEBUGGING_PATH}/${CURTIME_DEBUG_PATH}
        mkdir -p  ${DATA_LOG_DEBUG_PATH}
        chmod -R 777 ${DATA_LOG_DEBUG_PATH}

        mkdir -p  ${ANR_BINDER_PATH}
        chmod -R 777 ${ANR_BINDER_PATH}
        chown system:system ${ANR_BINDER_PATH}

        mkdir -p  ${TCPDUMP_PATH}
        chmod -R 777 ${TCPDUMP_PATH}
        chown system:system ${TCPDUMP_PATH}

        decrypt='false'
        if [ x"${decrypt}" != x"true" ]; then
            setprop ctl.stop logcatcache
            setprop ctl.stop radiocache
            setprop ctl.stop eventcache
            setprop ctl.stop kernelcache
            setprop ctl.stop fingerprintcache
            setprop ctl.stop fplogcache
            setprop ctl.stop tcpdumpcache
            traceTransferState "INITOPLUSLOG: mv cache log..."
            mv ${CACHE_PATH}/* ${DATA_LOG_DEBUG_PATH}/
            mv ${DATA_DEBUGGING_PATH}/unboot ${DATA_LOG_DEBUG_PATH}/
        fi

        traceTransferState "INITOPLUSLOG:start debug time: ${CURTIME_DEBUG_PATH}"

        #setprop sys.oplus.collectlog.start true
        startCatchLog
    fi
}

function copyCamDcsLog() {
    timeStamp=`date "+%Y_%m_%d_%H_%M_%S"`
    fieldNum=`cat /proc/sys/kernel/random/uuid`
    otaVersion=`getprop ro.build.version.ota`
    dcsZipName="olog@"${fieldNum:0-12:12}@${otaVersion}@${timeStamp}".zip"
    dcsLogPath="/data/persist_log/DCS/de/camera"
    if [ ! -d "${dcsLogPath}" ]; then
        mkdir ${dcsLogPath}
        chown system:system ${dcsLogPath}
        chmod 777 ${dcsLogPath}
    fi
    if [ -e "/data/persist_log/backup/explorer_log_abnormal_log" ]; then
        mv -f /data/persist_log/backup/explorer_log_abnormal_log ${dcsLogPath}/${dcsZipName}
        chmod 0777 ${dcsLogPath}/${dcsZipName}
        chown system:system ${dcsLogPath}/${dcsZipName}
    fi
}

function disableCameraOfflineProp(){
    PROP_DISABLE_OFFLINE=`getprop persist.sys.engineering.pre.disableoffline`
    PROP_OFFLINE=`getprop persist.sys.log.offline`
    if [ x"${PROP_OFFLINE}" == x"true" ] && [ x"${PROP_DISABLE_OFFLINE}" != x"false" ]; then
        setprop persist.sys.log.offline false
        setprop persist.sys.engineering.pre.disableoffline false
    fi
}

function startCatchLog(){
    traceTransferState "start catch log"
    handle_m_commonLog

    # TODO only for camera tmp plan on android R
    disableCameraOfflineProp

    LOG_TYPE=`getprop persist.sys.debuglog.config`
    handle_command_${LOG_TYPE}
}

function handle_m_commonLog(){
    traceTransferState "startCollectCommonLog..."
    DATA_LOG_APPS_PATH=${DATA_LOG_DEBUG_PATH}/apps
    DATA_LOG_KERNEL_PATH=${DATA_LOG_DEBUG_PATH}/kernel
    ASSERT_PATH=${DATA_LOG_DEBUG_PATH}/asserttip

    if [[ ! -d ${DATA_LOG_APPS_PATH} ]]; then
        mkdir -p ${DATA_LOG_APPS_PATH}
    fi
    if [[ ! -d ${DATA_LOG_KERNEL_PATH} ]]; then
        mkdir -p ${DATA_LOG_KERNEL_PATH}
    fi
    if [[ ! -d ${ASSERT_PATH} ]]; then
        mkdir -p ${ASSERT_PATH}
    fi
    chmod -R 777 ${DATA_LOG_DEBUG_PATH}

    setprop sys.oplus.logkit.appslog ${DATA_LOG_APPS_PATH}
    setprop sys.oplus.logkit.kernellog ${DATA_LOG_KERNEL_PATH}
    setprop sys.oplus.logkit.assertlog ${ASSERT_PATH}
}

function handle_m_tcpdump(){
    DATA_LOG_TCPDUMPLOG_PATH=${TCPDUMP_PATH}/netlog
    if [[ ! -d ${DATA_LOG_TCPDUMPLOG_PATH} ]]; then
        mkdir -p ${DATA_LOG_TCPDUMPLOG_PATH}
    fi
    chmod -R 777 ${TCPDUMP_PATH}
    setprop sys.oplus.logkit.netlog ${DATA_LOG_TCPDUMPLOG_PATH}

    setprop ctl.restart manualCaptureTcpdumpLog
}

function handle_m_qmi(){
    QMI_PATH=${DATA_LOG_DEBUG_PATH}/qmi
    if [[ ! -d ${QMI_PATH} ]]; then
        mkdir -p ${QMI_PATH}
    fi
    chmod -R 777 ${DATA_LOG_DEBUG_PATH}
    setprop sys.oplus.logkit.qmilog ${QMI_PATH}

    setprop ctl.start qmilogon
}

function handle_command_call(){
    handle_m_tcpdump

    setprop ctl.start logcatSsLog
}

function handle_command_signal(){
    handle_m_tcpdump

    setprop ctl.start logcatSsLog
}

function handle_command_media(){
    handle_m_tcpdump
}

#YuFeng.Yang@BSP.DFT.OLC, 2023/5/15, add net log for video type
function handle_command_video() {
    handle_m_tcpdump
}

function handle_command_interconnection() {
    handle_m_tcpdump
}

function handle_command_interconnection_car_wireless_abnormal() {
    handle_m_tcpdump
}

function handle_command_gps(){
    #ifndef OPLUS_GPS_LOG
    #ShiMinghao@CONNECTIVITY.GPS, 2021/02/09, Enable tcpdump when capturing GPS Log for network locationing
    handle_m_tcpdump
    #endif /* OPLUS_GPS_LOG */
}
function handle_command_network(){
    handle_m_tcpdump
    handle_m_qmi

    setprop ctl.start logcatSsLog
}
function handle_command_wifi(){
    handle_m_tcpdump
    handle_m_qmi

    setprop ctl.start logcatSsLog
}
function handle_command_hotspot(){
    handle_m_tcpdump
    handle_m_qmi

    setprop ctl.start logcatSsLog
}

function handle_command_heat(){
    handle_m_tcpdump

    QMI_PATH=${DATA_LOG_DEBUG_PATH}/qmi
    mkdir -p  ${QMI_PATH}
    setprop sys.oplus.logkit.qmilog ${QMI_PATH}

    start qmilogon
    start logcatSsLog
}
function handle_command_power(){
    handle_m_tcpdump
    handle_m_qmi

    setprop ctl.start logcatSsLog
}

function handle_command_thirdpart(){
    # Add for catching fingerprint and face log
    dumpsys fingerprint log all 1
    dumpsys face log all 1
}

function handle_command_other(){
    handle_m_tcpdump
    handle_m_qmi

    setprop ctl.start logcatSsLog

    #DATA_LOG_FINGERPRINTERLOG_PATH=${DATA_DEBUGGING_PATH}/security
    #mkdir -p  ${DATA_LOG_FINGERPRINTERLOG_PATH}
    #chmod 777 -R ${DATA_LOG_FINGERPRINTERLOG_PATH}
    #setprop sys.oplus.logkit.fingerprintlog ${DATA_LOG_FINGERPRINTERLOG_PATH}

    #setprop ctl.start fingerprintlog
    #setprop ctl.start fplogqess
    ## Add for catching fingerprint and face log
    #dumpsys fingerprint log all 1
    #dumpsys face log all 1
}

function checkSmallSizeAndCopy(){
    LOG_SOURCE_PATH="$1"
    LOG_TARGET_PATH="$2"
    traceTransferState "CHECKSMALLSIZEANDCOPY:from ${LOG_SOURCE_PATH}"
    # 10M
    LIMIT_SIZE="10240"

    if [ -d "${LOG_SOURCE_PATH}" ]; then
        TMP_LOG_SIZE=`du -s -k ${LOG_SOURCE_PATH} | awk '{print $1}'`
        if [ ${TMP_LOG_SIZE} -le ${LIMIT_SIZE} ]; then  #log size less then 10M
            mkdir -p ${newpath}/${LOG_TARGET_PATH}
            cp -rf ${LOG_SOURCE_PATH}/* ${newpath}/${LOG_TARGET_PATH}
            traceTransferState "CHECKSMALLSIZEANDCOPY:${LOG_SOURCE_PATH} done"
        else
            traceTransferState "CHECKSMALLSIZEANDCOPY:${LOG_SOURCE_PATH} SIZE:${TMP_LOG_SIZE}/${LIMIT_SIZE}"
        fi
    fi
}

function checkNumberSizeAndMove(){
    LOG_SOURCE_PATH="$1"
    LOG_TARGET_PATH="$2"
    LOG_LIMIT_NUM="$3"
    LOG_LIMIT_SIZE="$4"
    traceTransferState "CHECKNUMBERSIZEANDMOVE:FROM ${LOG_SOURCE_PATH}"
    LIMIT_NUM=500
    #500*1024KB
    LIMIT_SIZE="512000"

    if [[ -d "${LOG_SOURCE_PATH}" ]] && [[ ! "`ls -A ${LOG_SOURCE_PATH}`" = "" ]]; then
        TMP_LOG_NUM=`ls -lR ${LOG_SOURCE_PATH} |grep "^-"|wc -l | awk '{print $1}'`
        TMP_LOG_SIZE=`du -s -k ${LOG_SOURCE_PATH} | awk '{print $1}'`
        traceTransferState "CHECKNUMBERSIZEANDMOVE:NUM:${TMP_LOG_NUM}/${LIMIT_NUM} SIZE:${TMP_LOG_SIZE}/${LIMIT_SIZE}"
        if [[ ${TMP_LOG_NUM} -le ${LIMIT_NUM} ]] && [[ ${TMP_LOG_SIZE} -le ${LIMIT_SIZE} ]]; then
            if [[ ! -d ${LOG_TARGET_PATH} ]];then
                mkdir -p ${LOG_TARGET_PATH}
            fi

            mv ${LOG_SOURCE_PATH}/* ${LOG_TARGET_PATH}
            traceTransferState "CHECKNUMBERSIZEANDMOVE:${LOG_SOURCE_PATH} done" "i"
        else
            traceTransferState "CHECKNUMBERSIZEANDMOVE:${LOG_SOURCE_PATH} NUM:${TMP_LOG_NUM}/${LIMIT_NUM} SIZE:${TMP_LOG_SIZE}/${LIMIT_SIZE}" "e"
            rm -rf ${LOG_SOURCE_PATH}/*
        fi
    fi
}

function initLogSizeAndNums() {
    FreeSize=`df /data | grep -v Mounted | awk '{print $4}'`
    GSIZE=`echo | awk '{printf("%d",2*1024*1024)}'`
    traceTransferState "data FreeSize:${FreeSize} and GSIZE:${GSIZE}"
    tmpTcpdump=`getprop persist.sys.log.tcpdump`
    if [ "${tmpTcpdump}" != "" ]; then
        tmpTcpdumpSize=`set -f;array=(${tmpTcpdump//|/ });echo "${array[0]}"`
        tmpTcpdumpCount=`set -f;array=(${tmpTcpdump//|/ });echo "${array[1]}"`
        tcpdumpSize=`echo ${tmpTcpdumpSize} | awk '{printf("%d",$1*1024)}'`
        tcpdumpCount=`echo ${FreeSize} 10 50 ${tcpdumpSize} | awk '{printf("%d",$1*$2/$3/$4)}'`
        ##tcpdump use MB in the order
        tcpdumpSize=${tmpTcpdumpSize}
        if [ ${tcpdumpCount} -ge ${tmpTcpdumpCount} ]; then
            tcpdumpCount=${tmpTcpdumpCount}
        fi
    fi

    #LiuHaipeng@NETWORK.DATA.2959182, modify for limit the tcpdump size to 300M and packet size 100 byte for power log type and other log type
    #YangQing@CONNECTIVITY.WIFI.DCS.4219844, only limit tcpdump total size to 300M for other log, not limit packet size.
    LOG_TYPE=`getprop persist.sys.debuglog.config`
    tcpdumpPacketSize=0
    #ZhuYan@Network.ARCH.4305581, customize tcpdumpPacketSize
    tcpdump_pktsize=`getprop persist.sys.oplus.data.tcpdump_pktsize`
    log_user_mode=`getprop persist.sys.log.user`
    if [ "${tcpdump_pktsize}" != "" ] && [ ${tcpdump_pktsize} -ge 0 ] && [ ${tcpdump_pktsize} -le 65535 ]; then
        tcpdumpPacketSize=${tcpdump_pktsize}
        traceTransferState "tcpDumpLog tcpdumpPacketSize=${tcpdumpPacketSize}"
    fi
    if [ "${LOG_TYPE}" != "call" ] && [ "${LOG_TYPE}" != "network" ] && [ "${LOG_TYPE}" != "wifi" ]; then
        tcpdumpSizeTotal=300
        tcpdumpCount=`echo ${tcpdumpSizeTotal} ${tcpdumpSize} 1 | awk '{printf("%d",$1/$2)}'`
    elif [ "${log_user_mode}" == "1" ]; then
        tcpdumpSizeTotal=500
        tcpdumpCount=`echo ${tcpdumpSizeTotal} ${tcpdumpSize} 1 | awk '{printf("%d",$1/$2)}'`
    fi
}

#ifdef OPLUS_DEBUG_SSLOG_CATCH
#ZhangWankang@NETWORK.POWER 2020/04/02,add for catch ss log
function logcatSsLog(){
    echo "logcatSsLog start"
    outputPath="${DATA_DEBUGGING_PATH}/sslog"
    if [ ! -d "${outputPath}" ]; then
        mkdir -p ${outputPath}
    fi
    while [ -d "$outputPath" ]
    do
        ss -ntp -o state established >> ${outputPath}/sslog.txt
        sleep 15s #Sleep 15 seconds
    done
}
#endif

function transferTombstone() {
    srcpath=`getprop sys.tombstone.file`
    subPath=`getprop persist.sys.com.oplus.debug.time`
    cp ${srcpath} ${DATA_DEBUGGING_PATH}/${subPath}/tombstone/tomb_${CURTIME}
}

function transferAnr() {
    srcpath=`getprop sys.anr.srcfile`
    subPath=`getprop persist.sys.com.oplus.debug.time`
    destfile=`getprop sys.anr.destfile`

    cp ${srcpath} ${DATA_DEBUGGING_PATH}/${subPath}/anr/${destfile}
}

#ifdef OPLUS_BUG_STABILITY
#Qing.Wu@ANDROID.STABILITY.2278668, 2019/09/03, Add for capture binder info
#Weitao.Chen 2023/03/02 modify for deadsystemexception log
function binderinfocapture() {
    panicstate=`getprop persist.sys.assert.panic`
    deadsystem_exp_log="/data/persist_log/DCS/de/stability_monitor/deadsystem_exp/"
    # we only keep total 8 times deadsystem exception
	if [ -d $deadsystem_exp_log ]; then
		dir_count=`ls -l $deadsystem_exp_log | wc -l`
		if [ $dir_count -gt 8 ]; then
                    rm -rfv /data/persist_log/DCS/de/stability_monitor/deadsystem_exp/*
	        fi
	fi

	#first check if log is on
	if [ "$panicstate" == "true" ]; then

		if [ ! -d $deadsystem_exp_log ];then
			mkdir -p $deadsystem_exp_log
		fi

		latest_file=`ls -t $deadsystem_exp_log | head -n 1`
		time_a=`stat -c %Y "$deadsystem_exp_log""$latest_file"`
		time_b=`date +%s`

		let interval=$time_b-$time_a
		#if the latest file is older than 1 hour, go on
		if [ $interval -gt 3600 ]; then
			older_onehour=true;
		fi

		#find out the latest file in /data/persist_log/DCS/de/stability_monitor/deadsystem_exp/

		if [ "$latest_file" != "" ] && [ "$older_onehour" == "true" ] || [ "$latest_file" = "" ]; then
			LOGTIME=`date +%F-%H-%M-%S`
			BINDER_DIR=${deadsystem_exp_log}/deadsystem_${LOGTIME}
			mkdir -p ${BINDER_DIR}
			if [ -f "/dev/binderfs/binder_logs/state" ]; then
				cat /dev/binderfs/binder_logs/state > ${BINDER_DIR}/state
				cat /dev/binderfs/binder_logs/stats > ${BINDER_DIR}/stats
				cat /dev/binderfs/binder_logs/transaction_log > ${BINDER_DIR}/transaction_log
				cat /dev/binderfs/binder_logs/transactions > ${BINDER_DIR}/transactions
			else
				cat /d/binder/state > ${BINDER_DIR}/state
				cat /d/binder/stats > ${BINDER_DIR}/stats
				cat /d/binder/transaction_log > ${BINDER_DIR}/transaction_log
				cat /d/binder/transactions > ${BINDER_DIR}/transactions
			fi
			ps -A -T > ${BINDER_DIR}/ps.txt
			logcat -b crash -b events -b main -b system > ${BINDER_DIR}/logcat.txt &
			dmesg > ${BINDER_DIR}/dmesg.txt &
			kill -3 `pidof system_server`
			sleep 1
			kill -3 `pidof system_server`
			sleep 10
			cp -a /data/anr  ${BINDER_DIR}/
		fi
	fi

}
#endif /* OPLUS_BUG_STABILITY */

#ifdef OPLUS_BUG_STABILITY
#Tian.Pan@ANDROID.STABILITY.3054721.2020/08/31.add for fix debug system_server register too many receivers issue
function receiverinfocapture() {
    alreadycaped=`getprop sys.debug.receiverinfocapture`
    if [ "$alreadycaped" == "1" ] ;then
        return
    fi

    uuid=`cat /proc/sys/kernel/random/uuid`
    version=`getprop ro.build.version.ota`
    logtime=`date +%F-%H-%M-%S`
    logpath="${DATA_OPLUS_LOG_PATH}/DCS/de/stability_monitor"
    if [ ! -d "${logpath}" ]; then
        mkdir ${logpath}
        chown system:system ${logpath}
        chmod 777 ${logpath}
    fi
    filename="${logpath}/stability_receiversinfo@${uuid}@${version}@${logtime}.txt"
    dumpsys -t 60 activity broadcasts > ${filename}
    chown system:system ${filename}
    chmod 0666 ${filename}
    setprop sys.debug.receiverinfocapture 1
}
#endif /*OPLUS_BUG_STABILITY*/

#ifdef OPLUS_BUG_STABILITY
#Tian.Pan@ANDROID.STABILITY.3054721.2020/09/21.add for fix debug system_server register too many receivers issue
function binderthreadfullcapture() {
    capturetimestamp=`getprop sys.debug.receiverinfocapture.timestamp`
    current=`date "+%Y-%m-%d %H:%M:%S"`
    timestamp=`date -d "$current" +%s`
    let interval=$timestamp-$capturetimestamp
    if [ $interval -lt 10 ] ; then
        return
    fi

    capturefinish=`getprop sys.capturebinderthreadinfo.finished`
    if [ "$capturefinish" == "0" ] ;then
        return
    fi
    setprop sys.capturebinderthreadinfo.finished 0

    if [ ! -d ${SDCARD_LOG_BASE_PATH}/binderthread_info/ ];then
    mkdir -p ${SDCARD_LOG_BASE_PATH}/binderthread_info/
    fi
    LOGTIME=`date +%F-%H-%M-%S`
    BINDER_DIR=${SDCARD_LOG_BASE_PATH}/binderthread_info/binderthread_${LOGTIME}
    echo ${BINDER_DIR}
    mkdir -p ${BINDER_DIR}
    if [ -f "/dev/binderfs/binder_logs/state" ]; then
        cat /dev/binderfs/binder_logs/state > ${BINDER_DIR}/state
        cat /dev/binderfs/binder_logs/stats > ${BINDER_DIR}/stats
        cat /dev/binderfs/binder_logs/transaction_log > ${BINDER_DIR}/transaction_log
        cat /dev/binderfs/binder_logs/transactions > ${BINDER_DIR}/transactions
    else
        cat /d/binder/state > ${BINDER_DIR}/state
        cat /d/binder/stats > ${BINDER_DIR}/stats
        cat /d/binder/transaction_log > ${BINDER_DIR}/transaction_log
        cat /d/binder/transactions > ${BINDER_DIR}/transactions
    fi
    ps -A -T > ${BINDER_DIR}/ps.txt

    kill -3 `pidof system_server`
    kill -3 `pidof com.android.phone`
    debuggerd -b `pidof netd` > "/data/anr/debuggerd_netd.txt"
    sleep 10
    cp -r /data/anr/*  ${BINDER_DIR}/
#package log folder to upload if logkit not enable
    logon=`getprop persist.sys.assert.panic`
    if [ ${logon} == "false" ];then
        current=`date "+%Y-%m-%d %H:%M:%S"`
        timeStamp=`date -d "$current" +%s`
        uuid=`cat /proc/sys/kernel/random/uuid`
        #uuid 0df1ed41-e0d6-40e2-8473-cdf7ccbd0d98
        otaversion=`getprop ro.build.version.ota`
        logzipname="${DATA_OPLUS_LOG_PATH}/DCS/de/quality_log/qp_binderinfo@"${uuid:0-12:12}@${otaversion}@${timeStamp}".tar.gz"
        tar -czf ${logzipname} ${BINDER_DIR}
        chown system:system ${logzipname}
    fi

    capturecount=`getprop debug.binderthreadfull.count`
    let capturecount=$capturecount+1
    setprop debug.binderthreadfull.count $capturecount

    current=`date "+%Y-%m-%d %H:%M:%S"`
    timeStamp=`date -d "$current" +%s`
    setprop sys.debug.receiverinfocapture.timestamp $timeStamp

    setprop sys.capturebinderthreadinfo.finished 1
}
#endif /*OPLUS_BUG_STABILITY*/

#ifdef OPLUS_BUG_STABILITY
#Yongqiang.Du@ANDROID.Stability.Crash.0, 2022/08/08, Add for shutdown reason recorder
function rebootdetectcapture() {
    alreadycaped=`getprop sys.debug.rebootdetectcapture`
    normalaction=`getprop debug.rebootdetect.capture`
    if [ "${alreadycaped}" == "1" ] ;then
        return
    fi
    if [ x"${normalaction}" != x"true" ] ;then
       return
    fi

    dd if=/dev/zero of=/sdcard/zero5 bs=1m count=5
    #dd if=/dev/zero of=/data/persist_log/oplusreserve/media/log/shutdown/zero6 bs=1m count=5
    if [ -e /dev/block/by-name/oplusreserve3 ]; then
        dd if=/sdcard/zero5 of=/dev/block/by-name/oplusreserve3 bs=1m seek=16
        #dd if=/data/persist_log/oplusreserve/media/log/shutdown/zero6 of=/dev/block/by-name/oplusreserve3 bs=1m seek=16
        LOG_DEV="/dev/block/by-name/oplusreserve3"
        logcat --buffer-size=4M

    elif [ -e /dev/block/by-name/reserve3 ]; then
        dd if=/sdcard/zero5 of=/dev/block/by-name/reserve3 bs=1m seek=16
        LOG_DEV="/dev/block/by-name/reserve3"
        logcat --buffer-size=4M
    else
        dd if=/sdcard/zero5 of=/dev/block/by-name/opporeserve3 bs=1m seek=16
        LOG_DEV="/dev/block/by-name/opporeserve3"
        logcat --buffer-size=4M
    fi

    rm -rf /sdcard/zero5
    #rm -rf /data/persist_log/oplusreserve/media/log/shutdown/zero6

    #Handle the logcat at the place of 16M from beginning of reserve3
    logcat -b crash -b main -b system -d > /data/persist_log/oplusreserve/media/log/shutdown/temp_logcat
    dd if=/data/persist_log/oplusreserve/media/log/shutdown/temp_logcat of=${LOG_DEV} bs=1m count=4 seek=16
    rm -rf /data/persist_log/oplusreserve/media/log/shutdown/temp_logcat

    #clean 64bit at the place of 16M,to make a sign
    dd if=/dev/zero of=${LOG_DEV} bs=1 count=64
    echo "rebootdetectcapture at ${CURTIME_FORMAT}" > /data/persist_log/oplusreserve/media/log/shutdown/temp_notify
    dd if=/data/persist_log/oplusreserve/media/log/shutdown/temp_notify of=${LOG_DEV} bs=64 seek=256k
    rm -rf /data/persist_log/oplusreserve/media/log/shutdown/temp_notify

    # Handle kmsg dump at the place of 20M from beginning of reserve3
    dmesg |tail -c 1048576> /data/persist_log/oplusreserve/media/log/shutdown/temp_dmesg
    dd if=/data/persist_log/oplusreserve/media/log/shutdown/temp_dmesg of=${LOG_DEV} bs=1m count=1 seek=20
    rm -rf /data/persist_log/oplusreserve/media/log/shutdown/temp_dmesg

    setprop sys.debug.rebootdetectcapture 1
}
#endif /*OPLUS_BUG_STABILITY*/

#Chunbo.Gao@ANDROID.DEBUG.2514795, 2019/11/12, Add for copy binder_info
function copybinderinfo() {
    CURTIME=`date +%F-%H-%M-%S`
    echo ${CURTIME}
    if [ -f "/dev/binderfs/binder_logs/state" ]; then
        cat /dev/binderfs/binder_logs/state > ${ANR_BINDER_PATH}/binder_info_${CURTIME}.txt
    else
        cat /sys/kernel/debug/binder/state > ${ANR_BINDER_PATH}/binder_info_${CURTIME}.txt
    fi
}

#Wuchao.Huang@ROM.Framework.EAP, 2019/11/19, Add for copy binder_info
function copyEapBinderInfo() {
    destBinderInfoPath=`getprop sys.eap.binderinfo.path`
    echo ${destBinderInfoPath}
    if [ -f "/dev/binderfs/binder_logs/state" ]; then
        cat /dev/binderfs/binder_logs/state > ${destBinderInfoPath}
    else
        cat /sys/kernel/debug/binder/state > ${destBinderInfoPath}
    fi
}

# ifdef OPLUS_FEATURE_THEIA
# Yangkai.Yu@ANDROID.STABILITY, Add hook for TheiaBinderBlock
function copyTheiaBinderInfo() {
    destBinderFile=`getprop sys.theia.binderpath`
    echo "copy binder infomation to ${destBinderFile}"
    if [ -f "/dev/binderfs/binder_logs/transactions" ]; then
        cat /dev/binderfs/binder_logs/transactions > ${destBinderFile}
    else
        cat /sys/kernel/debug/binder/transactions > ${destBinderFile}
    fi
}
# endif /*OPLUS_FEATURE_THEIA*/

# add for Sensor.logger
function resetlogpath(){
    setprop sys.oplus.logkit.appslog ""
    setprop sys.oplus.logkit.kernellog ""
    setprop sys.oplus.logkit.netlog ""
    setprop sys.oplus.logkit.assertlog ""
    setprop sys.oplus.logkit.anrlog ""
    setprop sys.oplus.logkit.tombstonelog ""
    setprop sys.oplus.logkit.fingerprintlog ""
    setprop persist.sys.com.oplus.debug.time ""
    # Add for stopping catching fingerprint and face log
    dumpsys fingerprint log all 0
    dumpsys face log all 0
}

function gettpinfo() {
    tplogflag=`getprop persist.sys.oplusdebug.tpcatcher`
    tplogflag=511
    # echo "$tplogflag"
    if [ "$tplogflag" == "" ]
    then
        echo "tplogflag == error"
    else

        echo "tplogflag == $tplogflag"
        # tplogflag=`echo $tplogflag | $XKIT awk '{print lshift($0, 1)}'`
        tpstate=0
        # tpstate=`echo $tplogflag | $XKIT awk '{print and($1, 1)}'`
        tpstate=$(($tplogflag & 1))
        echo "switch tpstate = $tpstate"
        if [ $tpstate == "0" ]
        then
            echo "switch tpstate off"
        else
            echo "switch tpstate on"
            DATA_LOG_KERNEL_PATH=`getprop sys.oplus.logkit.kernellog`
            tpinfopath=/sdcard/tp_debug_info
            subpath=$tpinfopath/${CURTIME}.txt
            mkdir -p $tpinfopath
            # mFlagMainRegister = 1 << 1
            # subflag=`echo | $XKIT awk '{print lshift(1, 1)}'`
            subflag=$((1 << 1))
            echo "1 << 1 subflag = $subflag"
            # tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
            tpstate=$(($tplogflag & subflag))
            if [ $tpstate == "0" ]
            then
                echo "switch tpstate off mFlagMainRegister = 1 << 1 $tpstate"
            else
                echo "switch tpstate on mFlagMainRegister = 1 << 1 $tpstate"
                echo /proc/touchpanel/debug_info/main_register  >> $subpath
                cat /proc/touchpanel/debug_info/main_register  >> $subpath
            fi
            # mFlagSelfDelta = 1 << 2;
            # subflag=`echo | $XKIT awk '{print lshift(1, 2)}'`
            subflag=$((1 << 2))
            echo " 1<<2 subflag = $subflag"
            # tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
            tpstate=$(($tplogflag & subflag))
            if [ $tpstate == "0" ]
            then
                echo "switch tpstate off mFlagMainRegister = 1 << 2 $tpstate"
            else
                echo "switch tpstate on mFlagMainRegister = 1 << 2 $tpstate"
                echo /proc/touchpanel/debug_info/self_delta  >> $subpath
                cat /proc/touchpanel/debug_info/self_delta  >> $subpath
            fi
            # mFlagDetal = 1 << 3;
            # subflag=`echo | $XKIT awk '{print lshift(1, 3)}'`
              subflag=$((1 << 3))
            echo "1 << 3 subflag = $subflag"
            # tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
            tpstate=$(($tplogflag & subflag))
            if [ $tpstate == "0" ]
            then
                echo "switch tpstate off mFlagMainRegister = 1 << 3 $tpstate"
            else
                echo "switch tpstate on mFlagMainRegister = 1 << 3 $tpstate"
                echo /proc/touchpanel/debug_info/delta  >> $subpath
                cat /proc/touchpanel/debug_info/delta  >> $subpath
            fi
            # mFlatSelfRaw = 1 << 4;
            # subflag=`echo | $XKIT awk '{print lshift(1, 4)}'`
            subflag=$((1 << 4))
            echo "1 << 4 subflag = $subflag"
            # tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
            tpstate=$(($tplogflag & subflag))
            if [ $tpstate == "0" ]
            then
                echo "switch tpstate off mFlagMainRegister = 1 << 4 $tpstate"
            else
                echo "switch tpstate on mFlagMainRegister = 1 << 4 $tpstate"
                echo /proc/touchpanel/debug_info/self_raw  >> $subpath
                cat /proc/touchpanel/debug_info/self_raw  >> $subpath
            fi
            # mFlagBaseLine = 1 << 5;
            # subflag=`echo | $XKIT awk '{print lshift(1, 5)}'`
            subflag=$((1 << 5))
            echo "1 << 5 subflag = $subflag"
            # tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
            tpstate=$(($tplogflag & subflag))
            if [ $tpstate == "0" ]
            then
                echo "switch tpstate off mFlagMainRegister = 1 << 5 $tpstate"
            else
                echo "switch tpstate on mFlagMainRegister = 1 << 5 $tpstate"
                echo /proc/touchpanel/debug_info/baseline  >> $subpath
                cat /proc/touchpanel/debug_info/baseline  >> $subpath
            fi
            # mFlagDataLimit = 1 << 6;
            # subflag=`echo | $XKIT awk '{print lshift(1, 6)}'`
            subflag=$((1 << 6))
            echo "1 << 6 subflag = $subflag"
            # tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
            tpstate=$(($tplogflag & subflag))
            if [ $tpstate == "0" ]
            then
                echo "switch tpstate off mFlagMainRegister = 1 << 6 $tpstate"
            else
                echo "switch tpstate on mFlagMainRegister = 1 << 6 $tpstate"
                echo /proc/touchpanel/debug_info/data_limit  >> $subpath
                cat /proc/touchpanel/debug_info/data_limit  >> $subpath
            fi
            # mFlagReserve = 1 << 7;
            #subflag=`echo | $XKIT awk '{print lshift(1, 7)}'`
            subflag=$((1 << 7))
            echo "1 << 7 subflag = $subflag"
            # tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
            tpstate=$(($tplogflag & subflag))
            if [ $tpstate == "0" ]
            then
                echo "switch tpstate off mFlagMainRegister = 1 << 7 $tpstate"
            else
                echo "switch tpstate on mFlagMainRegister = 1 << 7 $tpstate"
                echo /proc/touchpanel/debug_info/reserve  >> $subpath
                cat /proc/touchpanel/debug_info/reserve  >> $subpath
            fi
            # mFlagTpinfo = 1 << 8;
            # subflag=`echo | $XKIT awk '{print lshift(1, 8)}'`
            subflag=$((1 << 8))
            echo "1 << 8 subflag = $subflag"
            # tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
            tpstate=$(($tplogflag & $tpstate))
            if [ $tpstate == "0" ]
            then
                echo "switch tpstate off mFlagMainRegister = 1 << 8 $tpstate"
            else
                echo "switch tpstate on mFlagMainRegister = 1 << 8 $tpstate"
            fi
            #cp  health_monitor
            if [ -f "/proc/touchpanel/debug_info/health_monitor" ]
            then
                echo /proc/touchpanel/debug_info/health_monitor  >> $subpath
                cat /proc/touchpanel/debug_info/health_monitor  >> $subpath
            else
                echo "/proc/touchpanel/debug_info/health_monitor is not exist"
            fi
            echo $tplogflag " end else"

            is_folder_empty=`ls /proc/touchpanel1/debug_info/*`
            if [ "$is_folder_empty" = "" ];then
                echo "/proc/touchpanel1/debug_info is empty"
            else
                echo "/proc/touchpanel1/debug_info is exited"
                echo "switch tpstate on"
                DATA_LOG_KERNEL_PATH=`getprop sys.oplus.logkit.kernellog`
                tpinfopath1=/sdcard/tp_debug_info1
                subpath=$tpinfopath1/${CURTIME}.txt
                mkdir -p $tpinfopath1
                # mFlagMainRegister = 1 << 1
                # subflag=`echo | $XKIT awk '{print lshift(1, 1)}'`
                subflag=$((1 << 1))
                echo "1 << 1 subflag = $subflag"
                # tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
                tpstate=$(($tplogflag & subflag))
                if [ $tpstate == "0" ]
                then
                    echo "switch tpstate off mFlagMainRegister = 1 << 1 $tpstate"
                else
                    echo "switch tpstate on mFlagMainRegister = 1 << 1 $tpstate"
                    echo /proc/touchpanel1/debug_info/main_register  >> $subpath
                    cat /proc/touchpanel1/debug_info/main_register  >> $subpath
                fi
                # mFlagSelfDelta = 1 << 2;
                # subflag=`echo | $XKIT awk '{print lshift(1, 2)}'`
                subflag=$((1 << 2))
                echo " 1<<2 subflag = $subflag"
                # tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
                tpstate=$(($tplogflag & subflag))
                if [ $tpstate == "0" ]
                then
                    echo "switch tpstate off mFlagMainRegister = 1 << 2 $tpstate"
                else
                    echo "switch tpstate on mFlagMainRegister = 1 << 2 $tpstate"
                    echo /proc/touchpanel1/debug_info/self_delta  >> $subpath
                    cat /proc/touchpanel1/debug_info/self_delta  >> $subpath
                fi
                # mFlagDetal = 1 << 3;
                # subflag=`echo | $XKIT awk '{print lshift(1, 3)}'`
                subflag=$((1 << 3))
                echo "1 << 3 subflag = $subflag"
                # tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
                tpstate=$(($tplogflag & subflag))
                if [ $tpstate == "0" ]
                then
                    echo "switch tpstate off mFlagMainRegister = 1 << 3 $tpstate"
                else
                    echo "switch tpstate on mFlagMainRegister = 1 << 3 $tpstate"
                    echo /proc/touchpanel1/debug_info/delta  >> $subpath
                    cat /proc/touchpanel1/debug_info/delta  >> $subpath
                fi
                # mFlatSelfRaw = 1 << 4;
                # subflag=`echo | $XKIT awk '{print lshift(1, 4)}'`
                subflag=$((1 << 4))
                echo "1 << 4 subflag = $subflag"
                # tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
                tpstate=$(($tplogflag & subflag))
                if [ $tpstate == "0" ]
                then
                    echo "switch tpstate off mFlagMainRegister = 1 << 4 $tpstate"
                else
                    echo "switch tpstate on mFlagMainRegister = 1 << 4 $tpstate"
                    echo /proc/touchpanel1/debug_info/self_raw  >> $subpath
                    cat /proc/touchpanel1/debug_info/self_raw  >> $subpath
                fi
                # mFlagBaseLine = 1 << 5;
                # subflag=`echo | $XKIT awk '{print lshift(1, 5)}'`
                subflag=$((1 << 5))
                echo "1 << 5 subflag = $subflag"
                # tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
                tpstate=$(($tplogflag & subflag))
                if [ $tpstate == "0" ]
                then
                    echo "switch tpstate off mFlagMainRegister = 1 << 5 $tpstate"
                else
                    echo "switch tpstate on mFlagMainRegister = 1 << 5 $tpstate"
                    echo /proc/touchpanel1/debug_info/baseline  >> $subpath
                    cat /proc/touchpanel1/debug_info/baseline  >> $subpath
                fi
                # mFlagDataLimit = 1 << 6;
                # subflag=`echo | $XKIT awk '{print lshift(1, 6)}'`
                subflag=$((1 << 6))
                echo "1 << 6 subflag = $subflag"
                # tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
                tpstate=$(($tplogflag & subflag))
                if [ $tpstate == "0" ]
                then
                    echo "switch tpstate off mFlagMainRegister = 1 << 6 $tpstate"
                else
                    echo "switch tpstate on mFlagMainRegister = 1 << 6 $tpstate"
                    echo /proc/touchpanel1/debug_info/data_limit  >> $subpath
                    cat /proc/touchpanel1/debug_info/data_limit  >> $subpath
                fi
                # mFlagReserve = 1 << 7;
                # subflag=`echo | $XKIT awk '{print lshift(1, 7)}'`
                subflag=$((1 << 7))
                echo "1 << 7 subflag = $subflag"
                # tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
                tpstate=$(($tplogflag & subflag))
                if [ $tpstate == "0" ]
                then
                    echo "switch tpstate off mFlagMainRegister = 1 << 7 $tpstate"
                else
                    echo "switch tpstate on mFlagMainRegister = 1 << 7 $tpstate"
                    echo /proc/touchpanel1/debug_info/reserve  >> $subpath
                    cat /proc/touchpanel1/debug_info/reserve  >> $subpath
                fi
                # mFlagTpinfo = 1 << 8;
                # subflag=`echo | $XKIT awk '{print lshift(1, 8)}'`
                subflag=$((1 << 8))
                echo "1 << 8 subflag = $subflag"
                # tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
                tpstate=$(($tplogflag & subflag))
                if [ $tpstate == "0" ]
                then
                    echo "switch tpstate off mFlagMainRegister = 1 << 8 $tpstate"
                else
                    echo "switch tpstate on mFlagMainRegister = 1 << 8 $tpstate"
                fi
                #cp  health_monitor
                if [ -f "/proc/touchpanel1/debug_info/health_monitor" ]
                then
                    echo /proc/touchpanel1/debug_info/health_monitor  >> $subpath
                    cat /proc/touchpanel1/debug_info/health_monitor  >> $subpath
                else
                    echo "/proc/touchpanel1/debug_info/health_monitor is not exist"
                fi
                echo $tplogflag " end else"
            fi
        fi
    fi
}

function gettpserviceinfo() {
    tplogflag=`getprop persist.sys.oplusdebug.tpcatcher`
    # echo "$tplogflag"
    if [ "$tplogflag" == "" ]
    then
        echo "tplogflag == error"
    else

        echo "tplogflag == $tplogflag"
        # tplogflag=`echo $tplogflag | $XKIT awk '{print lshift($0, 1)}'`
        tpstate=0
        # tpstate=`echo $tplogflag | $XKIT awk '{print and($1, 1)}'`
        tpstate=$(($tplogflag & 1))
        echo "switch tpstate = $tpstate"
        if [ $tpstate == "0" ]
        then
            echo "switch tpstate off"
        else
            echo "switch tpstate on"
            DATA_LOG_KERNEL_PATH=`getprop sys.oplus.logkit.kernellog`
            tpinfopath=/sdcard/tp_debug_info
            subpath=$tpinfopath/${CURTIME}_dumpinfo.txt
            mkdir -p $tpinfopath
            # mFlagMainRegister = 1 << 1
            # subflag=`echo | $XKIT awk '{print lshift(1, 1)}'`
            subflag=$((1 << 0))
            echo "1 << 1 subflag = $subflag"
            # tpstate=`echo $tplogflag $subflag, | $XKIT awk '{print and($1, $2)}'`
            tpstate=$(($tplogflag & subflag))
            if [ $tpstate == "0" ]
            then
                echo "switch tpstate off mFlagMainRegister = 1 << 1 $tpstate"
            else
                echo "switch tpstate on mFlagMainRegister = 1 << 1 $tpstate"
                echo gettpserviceinfo  >> $subpath
                tp_pid=`getprop vendor.touchdaemon.pid`;
                if [ "tp_pid" ];then
                    /system/bin/debuggerd -b ${tp_pid}  >  $subpath
                fi
            fi
         fi
     fi
}

function customdmesg() {
    echo "customdmesg begin"
    chmod 777 -R ${DATA_DEBUGGING_PATH}/
    echo "customdmesg end"
}

function customdiaglog() {
    echo "customdiaglog begin"
    chmod 777 -R ${DATA_DEBUGGING_PATH}/customer
    restorecon -RF ${DATA_DEBUGGING_PATH}/customer
    echo "customdiaglog end"
}

function cameraloginit() {
    logdsize=`getprop persist.logd.size`
    echo "get logdsize ${logdsize}"
    if [ "${logdsize}" = "" ]
    then
        echo "camere init set log size 16M"
         setprop persist.logd.size 16777216
    fi
}
#================================== COMMON LOG =========================

#ifdef OPLUS_BUG_DEBUG
#Miao.Yu@ANDROID.WMS, 2019/11/25, Add for dump wm info
function dumpWm() {
    panicstate=`getprop persist.sys.assert.panic`
    dumpenable=`getprop debug.screencapdump.enable`
    if [ "$panicstate" == "true" ] && [ "$dumpenable" == "true" ]
    then
        if [ ! -d ${DATA_DEBUGGING_PATH}/wm/ ];then
        mkdir -p ${DATA_DEBUGGING_PATH}/wm/
        fi

        LOGTIME=`date +%F-%H-%M-%S`
        DIR=${DATA_DEBUGGING_PATH}/wm/${LOGTIME}
        mkdir -p ${DIR}
        dumpsys window -a > ${DIR}/windows.txt
        dumpsys activity a > ${DIR}/activities.txt
        dumpsys activity -v top > ${DIR}/top_activity.txt
        dumpsys SurfaceFlinger > ${DIR}/sf.txt
        dumpsys input > ${DIR}/input.txt
        ps -A > ${DIR}/ps.txt
        mv -f ${DATA_DEBUGGING_PATH}/wm_log.pb ${DIR}/wm_log.pb
        getLogStatistics
    fi
}
#endif /* OPLUS_BUG_DEBUG */

function getLogStatistics() {
    LOG_STATISTICS_PATH=${DATA_DEBUGGING_PATH}/logStatistics
    if [ ! -d ${LOG_STATISTICS_PATH} ]; then
        mkdir -p ${LOG_STATISTICS_PATH}
    fi
    logcat -S > ${DATA_DEBUGGING_PATH}/logStatistics/logStatistics_${CURTIME}.txt
}

function inittpdebug(){
    panicstate=`getprop persist.sys.assert.panic`
    camerapanic=`getprop persist.sys.assert.panic.camera`
    tplogflag=`getprop persist.sys.oplusdebug.tpcatcher`
    if [ "$tplogflag" != "" ]
    then
        echo "inittpdebug not empty panicstate = $panicstate tplogflag = $tplogflag"
        if [ "$panicstate" == "true" ] || [ x"${camerapanic}" = x"true" ]
        then
            # tplogflag=`echo $tplogflag , | $XKIT awk '{print or($1, 1)}'`
            tplogflag=$(($tplogflag | 1))
        else
            # tplogflag=`echo $tplogflag , | $XKIT awk '{print and($1, 510)}'`
            tplogflag=$(($tplogflag & 1))
        fi
        setprop persist.sys.oplusdebug.tpcatcher $tplogflag
    fi
}
function settplevel(){
    tplevel=`getprop persist.sys.oplusdebug.tplevel`
    if [ "$tplevel" == "0" ]
    then
        echo 0 > /proc/touchpanel/debug_level
    elif [ "$tplevel" == "1" ]
    then
        echo 1 > /proc/touchpanel/debug_level
    elif [ "$tplevel" == "2" ]
    then
        echo 2 > /proc/touchpanel/debug_level
    fi
}

function qmilogon() {
    echo "qmilogon begin"
    qmilog_switch=`getprop persist.sys.qmilog.switch`
    echo ${qmilog_switch}
    if [ "$qmilog_switch" == "true" ]; then
        setprop ctl.start adspglink
        setprop ctl.start modemglink
        setprop ctl.start cdspglink
        setprop ctl.start modemqrtr
        setprop ctl.start sensorqrtr
        setprop ctl.start npuqrtr
        setprop ctl.start slpiqrtr
        setprop ctl.start slpiglink
    fi
    echo "qmilogon end"
}
function qmilogoff() {
    echo "qmilogoff begin"
    qmilog_switch=`getprop persist.sys.qmilog.switch`
    echo ${qmilog_switch}
    if [ "$qmilog_switch" == "true" ]; then
        setprop ctl.stop adspglink
        setprop ctl.stop modemglink
        setprop ctl.stop cdspglink
        setprop ctl.stop modemqrtr
        setprop ctl.stop sensorqrtr
        setprop ctl.stop npuqrtr
        setprop ctl.stop slpiqrtr
        setprop ctl.stop slpiglink
    fi
    echo "qmilogoff end"
}
function adspglink() {
    echo "adspglink begin"
    if [ -d "/d/ipc_logging" ]; then
        path=`getprop sys.oplus.logkit.qmilog`
        cat /d/ipc_logging/adsp/log_cont > ${path}/adsp_glink.log
        cat /d/ipc_logging/diag/log_cont > ${path}/diag_ipc_glink.log &
    fi
}
function modemglink() {
    echo "modemglink begin"
    if [ -d "/d/ipc_logging" ]; then
        path=`getprop sys.oplus.logkit.qmilog`
        cat /d/ipc_logging/modem/log_cont > ${path}/modem_glink.log
    fi
}
function cdspglink() {
    echo "cdspglink begin"
    if [ -d "/d/ipc_logging" ]; then
        path=`getprop sys.oplus.logkit.qmilog`
        cat /d/ipc_logging/cdsp/log_cont > ${path}/cdsp_glink.log
    fi
}
function modemqrtr() {
    echo "modemqrtr begin"
    if [ -d "/d/ipc_logging" ]; then
        path=`getprop sys.oplus.logkit.qmilog`
        cat /d/ipc_logging/qrtr_0/log_cont > ${path}/modem_qrtr.log
    fi
}
function sensorqrtr() {
    echo "sensorqrtr begin"
    if [ -d "/d/ipc_logging" ]; then
        path=`getprop sys.oplus.logkit.qmilog`
        cat /d/ipc_logging/qrtr_5/log_cont > ${path}/sensor_qrtr.log
    fi
}
function npuqrtr() {
    echo "NPUqrtr begin"
    if [ -d "/d/ipc_logging" ]; then
        path=`getprop sys.oplus.logkit.qmilog`
        cat /d/ipc_logging/qrtr_10/log_cont > ${path}/NPU_qrtr.log
    fi
}
function slpiqrtr() {
    echo "slpiqrtr begin"
    if [ -d "/d/ipc_logging" ]; then
        path=`getprop sys.oplus.logkit.qmilog`
        cat /d/ipc_logging/qrtr_9/log_cont > ${path}/slpi_qrtr.log
    fi
}
function slpiglink() {
    echo "slpiglink begin"
    if [ -d "/d/ipc_logging" ]; then
        path=`getprop sys.oplus.logkit.qmilog`
        cat /d/ipc_logging/slpi/log_cont > ${path}/slpi_glink.log
    fi
}

#================================== STABILITY =========================
function dumpon(){
    platform=`getprop ro.board.platform`

    echo full > /sys/kernel/dload/dload_mode
    echo 0 > /sys/kernel/dload/emmc_dload

    dump_log_dir_v1="/sys/bus/msm_subsys/devices"
    dump_log_dir_v2="/sys/class/remoteproc"
    dump_sm8450_wlan_log_dir="/sys/devices/platform/soc/b0000000.qcom,cnss-qca6490"
    #lixiong@CONNECTIVITY.WIFI.HARDWARE.DUMP.2928304, 2022/08/11, add for sm8550
    dump_sm8550_wlan_log_dir="/sys/devices/platform/soc/b0000000.qcom,cnss-qca-converged"

    #fangbinghua@CONNECTIVITY.WIFI.HARDWARE.DUMP.2928304, 2023/07/06, add for sm8650
    dump_sm8650_wlan_log_dir="/sys/devices/platform/soc/b0000000.qcom,cnss-kiwi"

    #XiaSong@CONNECTIVITY.WIFI.HARDWARE.MINIDUMP.2928304, 2022/2/11, add for SM7450S wlan minidump
    dump_sm7450_wlan_log_dir="/sys/devices/platform/soc/8a00000.remoteproc-wpss/remoteproc/remoteproc3"

    #Gexuyang@CONNECTIVITY.WIFI.HARDWARE.MINIDUMP.2928304, 2023/11/23, add for SM7550 wlan minidump
    dump_sm7550_wlan_remoteproc="/sys/devices/platform/soc/9f700000.remoteproc-wpss/remoteproc/"

    #lixiong2@CONNECTIVITY.WIFI.HARDWARE.MINIDUMP.7001610, 2024/03/21, add for SM8750 wlan minidump
    dump_sm8750_wlan_log_dir="/sys/devices/platform/soc/b0000000.qcom,cnss-peach"

    #lixiong2@CONNECTIVITY.WIFI.HARDWARE.MINIDUMP.8524496, 2025/03/03, add for wcn8735 wlan minidump
    dump_sm8735_wlan_log_dir="/sys/devices/platform/soc/97000000.remoteproc-wpss/remoteproc/remoteproc3"

    if [ -d ${dump_sm7550_wlan_remoteproc} ]; then
        remoteproc=`ls -t ${dump_sm7550_wlan_remoteproc}`
    fi
    dump_sm7550_wlan_log_dir=${dump_sm7550_wlan_remoteproc}/${remoteproc}

    #liuhaifeng@CONNECTIVITY.WIFI.HARDWARE.MINIDUMP.2928304, 2024/01/09, add for SM7675 wlan minidump
    dump_sm7675_wlan_remoteproc="/sys/devices/platform/soc/9bb00000.remoteproc-wpss/remoteproc"
    if [ -d ${dump_sm7675_wlan_remoteproc} ]; then
        remoteproc=`ls -t ${dump_sm7675_wlan_remoteproc}`
    fi
    dump_sm7675_wlan_log_dir=${dump_sm7675_wlan_remoteproc}/${remoteproc}

    #liuhaifeng@CONNECTIVITY.WIFI.HARDWARE.MINIDUMP.6187898, 2023/09/01, add for wifi minidump control switch
    wlan_minidump_enable_state=`getprop ro.oplus.wifi.minidump.enable.state`

    wlan_aging_test=`getprop persist.sys.wlan.aging.status`
    #for wcn aging test
    if [ "${wlan_aging_test}" = "true" ] ; then
        modem_crash_not_reboot_to_dump=true
        adsp_crash_not_reboot_to_dump=false
        wlan_crash_not_reboot_to_dump=false
        cdsp_crash_not_reboot_to_dump=true
        slpi_crash_not_reboot_to_dump=true
        ap_crash_only=true
    else
        modem_crash_not_reboot_to_dump=`getprop persist.sys.modem.crash.noreboot`
        adsp_crash_not_reboot_to_dump=`getprop persist.sys.adsp.crash.noreboot`
        wlan_crash_not_reboot_to_dump=`getprop persist.sys.wlan.crash.noreboot`
        cdsp_crash_not_reboot_to_dump=`getprop persist.sys.cdsp.crash.noreboot`
        slpi_crash_not_reboot_to_dump=`getprop persist.sys.slpi.crash.noreboot`
        ap_crash_only=`getprop persist.sys.ap.crash.only`
    fi

    if [ -d ${dump_log_dir_v1} ]; then
        ALL_FILE=`ls -t ${dump_log_dir_v1}`
        for i in $ALL_FILE;
        do
            echo ${i}
            if [ -d ${dump_log_dir_v1}/${i} ]; then
                echo ${dump_log_dir_v1}/${i}/restart_level
                chmod 0666 ${dump_log_dir_v1}/${i}/restart_level
                subsys_name=`cat /sys/bus/msm_subsys/devices/${i}/name`
                if [ "${ap_crash_only}" = "true" ] ; then
                    echo related > ${dump_log_dir_v1}/${i}/restart_level
                else
                    if [ "${subsys_name}" = "modem" ] && [ "${modem_crash_not_reboot_to_dump}" = "true" ] ; then
                        echo related > ${dump_log_dir_v1}/${i}/restart_level
                    elif [ "${subsys_name}" = "adsp" ] && [ "${adsp_crash_not_reboot_to_dump}" = "true" ] ; then
                        echo related > ${dump_log_dir_v1}/${i}/restart_level
                    elif [ "${subsys_name}" = "wlan" ] && [ "${wlan_crash_not_reboot_to_dump}" = "true" ] ; then
                        echo related > ${dump_log_dir_v1}/${i}/restart_level
                    elif [ "${subsys_name}" = "cdsp" ] && [ "${cdsp_crash_not_reboot_to_dump}" = "true" ] ; then
                        echo related > ${dump_log_dir_v1}/${i}/restart_level
                    elif [ "${subsys_name}" = "slpi" ] && [ "${slpi_crash_not_reboot_to_dump}" = "true" ] ; then
                        echo related > ${dump_log_dir_v1}/${i}/restart_level
                    else
                        echo system > ${dump_log_dir_v1}/${i}/restart_level
                    fi
                fi
            fi
        done
    fi

    if [ -d ${dump_log_dir_v2} ]; then
        ALL_FILE=`ls -t ${dump_log_dir_v2}`
        for i in $ALL_FILE;
        do
            echo "${dump_log_dir_v2}/${i}"
            if [ -d ${dump_log_dir_v2}/${i} ]; then
                subsys_name=`cat ${dump_log_dir_v2}/${i}/name`
                if [ "${ap_crash_only}" = "true" ] ; then
                    setprop persist.vendor.ssr.restart_level ALL_ENABLE
                    echo enabled > ${dump_log_dir_v2}/${i}/coredump
                    echo enabled > ${dump_log_dir_v2}/${i}/recovery
                else
                    if [ "${subsys_name}" = "4080000.remoteproc-mss" ] && [ "${modem_crash_not_reboot_to_dump}" = "true" ] ; then
                        setprop persist.vendor.ssr.restart_level ALL_ENABLE
                        echo enabled > ${dump_log_dir_v2}/${i}/coredump
                        echo enabled > ${dump_log_dir_v2}/${i}/recovery
                    elif [ "${subsys_name}" = "3000000.remoteproc-adsp" ] && [ "${adsp_crash_not_reboot_to_dump}" = "true" ] ; then
                        echo enabled > ${dump_log_dir_v2}/${i}/coredump
                        echo enabled > ${dump_log_dir_v2}/${i}/recovery
                    #GaoPan@MULTIMEDIA.AUDIODRIVER.HAL, 2024/01/28, add for SM6225 enabled adsp dump node
                    elif [ "${subsys_name}" = "ab00000.remoteproc-adsp" ] && [ "${adsp_crash_not_reboot_to_dump}" = "true" ] ; then
                        echo enabled > ${dump_log_dir_v2}/${i}/coredump
                        echo enabled > ${dump_log_dir_v2}/${i}/recovery
                    #YangChao@MULTIMEDIA.AUDIODRIVER.HAL, 2024/02/21, add for SM6375 enabled adsp dump node
                    elif [ "${subsys_name}" = "a400000.remoteproc-adsp" ] && [ "${adsp_crash_not_reboot_to_dump}" = "true" ] ; then
                        echo enabled > ${dump_log_dir_v2}/${i}/coredump
                        echo enabled > ${dump_log_dir_v2}/${i}/recovery
                    elif [ "${subsys_name}" = "32300000.remoteproc-cdsp" ] && [ "${cdsp_crash_not_reboot_to_dump}" = "true" ] ; then
                        echo enabled > ${dump_log_dir_v2}/${i}/coredump
                        echo enabled > ${dump_log_dir_v2}/${i}/recovery
                    elif [ "${subsys_name}" = "2400000.remoteproc-slpi" ] && [ "${slpi_crash_not_reboot_to_dump}" = "true" ] ; then
                        echo enabled > ${dump_log_dir_v2}/${i}/coredump
                        echo enabled > ${dump_log_dir_v2}/${i}/recovery
                    elif  [ "${subsys_name}" = "6080000.remoteproc-mss" ] && [ "${modem_crash_not_reboot_to_dump}" = "true" ] ; then
                         setprop persist.vendor.ssr.restart_level ALL_ENABLE
                         echo enabled > ${dump_log_dir_v2}/${i}/coredump
                         echo enabled > ${dump_log_dir_v2}/${i}/recovery
                    else
                        setprop persist.vendor.ssr.restart_level ALL_DISABLE
                        echo disabled > ${dump_log_dir_v2}/${i}/coredump
                        echo disabled > ${dump_log_dir_v2}/${i}/recovery
                    fi
                fi
            fi
        done
    fi

    #for wcn aging test
    if [ "${wlan_aging_test}" = "true" ] ; then
        if [ -d ${dump_sm8450_wlan_log_dir} ]; then
            echo 0 > ${dump_sm8450_wlan_log_dir}/recovery
        fi
        if [ -d ${dump_sm8550_wlan_log_dir} ]; then
            echo 0 > ${dump_sm8550_wlan_log_dir}/recovery
        fi
        if [ -d ${dump_sm7450_wlan_log_dir} ]; then
            echo "disabled" > ${dump_sm7450_wlan_log_dir}/coredump
            echo "disabled" > ${dump_sm7450_wlan_log_dir}/recovery
        fi
        if [ -d ${dump_sm7550_wlan_log_dir} ]; then
            echo "disabled" > ${dump_sm7550_wlan_log_dir}/coredump
            echo "disabled" > ${dump_sm7550_wlan_log_dir}/recovery
        fi
        if [ -d ${dump_sm7675_wlan_log_dir} ]; then
            echo "disabled" > ${dump_sm7675_wlan_log_dir}/coredump
            echo "disabled" > ${dump_sm7675_wlan_log_dir}/recovery
        fi
        if [ -d ${dump_sm8650_wlan_log_dir} ]; then
            echo 0 > ${dump_sm8650_wlan_log_dir}/recovery
        fi
        if [ -d ${dump_sm8750_wlan_log_dir} ]; then
            echo 0 > ${dump_sm8750_wlan_log_dir}/recovery
        fi
        if [-d ${dump_sm8735_wlan_log_dir} ]; then
            echo "disabled" > ${dump_sm8735_wlan_log_dir}/coredump
            echo "disabled" > ${dump_sm8735_wlan_log_dir}/recovery
        fi
    else
        if [ -d ${dump_sm8450_wlan_log_dir} ]; then
            if [ "${wlan_crash_not_reboot_to_dump}" = "true" ] ; then
                echo 0 > ${dump_sm8450_wlan_log_dir}/recovery
            elif [ "${wlan_minidump_enable_state}" == "1" ] ; then
                echo 1 > ${dump_sm8450_wlan_log_dir}/recovery
            else
                echo 0 > ${dump_sm8450_wlan_log_dir}/recovery
            fi
        fi
        if [ -d ${dump_sm8550_wlan_log_dir} ]; then
            if [ "${wlan_crash_not_reboot_to_dump}" = "true" ] ; then
                echo 0 > ${dump_sm8550_wlan_log_dir}/recovery
            elif [ "${wlan_minidump_enable_state}" == "1" ] ; then
                echo 1 > ${dump_sm8550_wlan_log_dir}/recovery
            else
                echo 0 > ${dump_sm8550_wlan_log_dir}/recovery
            fi
        fi
        if [ -d ${dump_sm7450_wlan_log_dir} ]; then
            if [ "${wlan_crash_not_reboot_to_dump}" = "true" ] ; then
                echo "disabled" > ${dump_sm7450_wlan_log_dir}/coredump
                echo "disabled" > ${dump_sm7450_wlan_log_dir}/recovery
            elif [ "${wlan_minidump_enable_state}" == "1" ] ; then
                echo "enabled" > ${dump_sm7450_wlan_log_dir}/coredump
                echo "enabled" > ${dump_sm7450_wlan_log_dir}/recovery
            else
                echo "disabled" > ${dump_sm7450_wlan_log_dir}/coredump
                echo "disabled" > ${dump_sm7450_wlan_log_dir}/recovery
            fi
        fi
        if [ -d ${dump_sm7550_wlan_log_dir} ]; then
            if [ "${wlan_crash_not_reboot_to_dump}" = "true" ] ; then
                echo "disabled" > ${dump_sm7550_wlan_log_dir}/coredump
                echo "disabled" > ${dump_sm7550_wlan_log_dir}/recovery
            elif [ "${wlan_minidump_enable_state}" == "1" ] ; then
                echo "enabled" > ${dump_sm7550_wlan_log_dir}/coredump
                echo "enabled" > ${dump_sm7550_wlan_log_dir}/recovery
            else
                echo "disabled" > ${dump_sm7550_wlan_log_dir}/coredump
                echo "disabled" > ${dump_sm7550_wlan_log_dir}/recovery
            fi
        fi
        if [ -d ${dump_sm7675_wlan_log_dir} ]; then
            if [ "${wlan_crash_not_reboot_to_dump}" = "true" ] ; then
                echo "disabled" > ${dump_sm7675_wlan_log_dir}/coredump
                echo "disabled" > ${dump_sm7675_wlan_log_dir}/recovery
            elif [ "${wlan_minidump_enable_state}" == "1" ] ; then
                echo "enabled" > ${dump_sm7675_wlan_log_dir}/coredump
                echo "enabled" > ${dump_sm7675_wlan_log_dir}/recovery
            else
                echo "disabled" > ${dump_sm7675_wlan_log_dir}/coredump
                echo "disabled" > ${dump_sm7675_wlan_log_dir}/recovery
            fi
        fi
        if [ -d ${dump_sm8650_wlan_log_dir} ]; then
            if [ "${wlan_crash_not_reboot_to_dump}" = "true" ] ; then
                echo 0 > ${dump_sm8650_wlan_log_dir}/recovery
            elif [ "${wlan_minidump_enable_state}" == "1" ] ; then
                echo 1 > ${dump_sm8650_wlan_log_dir}/recovery
            else
                echo 0 > ${dump_sm8650_wlan_log_dir}/recovery
            fi
        fi
        if [ -d ${dump_sm8750_wlan_log_dir} ]; then
            if [ "${wlan_crash_not_reboot_to_dump}" = "true" ] ; then
                echo 0 > ${dump_sm8750_wlan_log_dir}/recovery
            elif [ "${wlan_minidump_enable_state}" == "1" ] ; then
                echo 1 > ${dump_sm8750_wlan_log_dir}/recovery
            else
                echo 0 > ${dump_sm8750_wlan_log_dir}/recovery
            fi
        fi
        if [ -d ${dump_sm8735_wlan_log_dir} ]; then
            if [ "${wlan_crash_not_reboot_to_dump}" = "true" ] ; then
                echo "disabled" > ${dump_sm8735_wlan_log_dir}/coredump
                echo "disabled" > ${dump_sm8735_wlan_log_dir}/recovery
            elif [ "${wlan_minidump_enable_state}" == "1" ] ; then
                echo "enabled" > ${dump_sm8735_wlan_log_dir}/coredump
                echo "enabled" > ${dump_sm8735_wlan_log_dir}/recovery
            else
                echo "disabled" > ${dump_sm8735_wlan_log_dir}/coredump
                echo "disabled" > ${dump_sm8735_wlan_log_dir}/recovery
            fi
        fi
    fi
    if [ "${wlan_aging_test}" = "true" ] ; then
        if [ -d ${dump_log_dir_v1} ]; then
            ALL_FILE=`ls -t ${dump_log_dir_v1}`
            for i in $ALL_FILE;
            do
                echo ${i}
                if [ -d ${dump_log_dir_v1}/${i} ]; then
                    echo ${dump_log_dir_v1}/${i}/restart_level
                    chmod 0666 ${dump_log_dir_v1}/${i}/restart_level
                    subsys_name=`cat /sys/bus/msm_subsys/devices/${i}/name`
                    if [ "${subsys_name}" = "adsp" ]; then
                        echo related > ${dump_log_dir_v1}/${i}/restart_level
                    fi
                fi
            done
        fi

        if [ -d ${dump_log_dir_v2} ]; then
            ALL_FILE=`ls -t ${dump_log_dir_v2}`
            for i in $ALL_FILE;
            do
                echo "${dump_log_dir_v2}/${i}"
                if [ -d ${dump_log_dir_v2}/${i} ]; then
                    subsys_name=`cat ${dump_log_dir_v2}/${i}/name`
                    if [ "${subsys_name}" = "3000000.remoteproc-adsp" ]; then
                        echo disabled > ${dump_log_dir_v2}/${i}/coredump
                        echo disabled > ${dump_log_dir_v2}/${i}/recovery
                        #GaoPan@MULTIMEDIA.AUDIODRIVER.HAL, 2024/01/28, add for SM6225 enabled adsp dump node
                    elif [ "${subsys_name}" = "ab00000.remoteproc-adsp" ]; then
                        echo disabled > ${dump_log_dir_v2}/${i}/coredump
                        echo disabled > ${dump_log_dir_v2}/${i}/recovery
                        #YangChao@MULTIMEDIA.AUDIODRIVER.HAL, 2024/02/21, add for SM6375 enabled adsp dump node
                    elif [ "${subsys_name}" = "a400000.remoteproc-adsp" ]; then
                        echo disabled > ${dump_log_dir_v2}/${i}/coredump
                        echo disabled > ${dump_log_dir_v2}/${i}/recovery
                    fi
                fi
            done
        fi
    fi
}

function dumpoff(){
    platform=`getprop ro.board.platform`


    echo mini > /sys/kernel/dload/dload_mode
    echo 1 > /sys/kernel/dload/emmc_dload

#Chunbo.Gao@ANDROID.DEBUG.1974273, 2019/4/22, Add for dumpoff
    dump_log_dir_v1="/sys/bus/msm_subsys/devices"
    dump_log_dir_v2="/sys/class/remoteproc"
    dump_sm8450_wlan_log_dir="/sys/devices/platform/soc/b0000000.qcom,cnss-qca6490"
    #lixiong@CONNECTIVITY.WIFI.HARDWARE.DUMP.2928304, 2022/08/11, add for sm8550
    dump_sm8550_wlan_log_dir="/sys/devices/platform/soc/b0000000.qcom,cnss-qca-converged"
    #fangbinghua@CONNECTIVITY.WIFI.HARDWARE.DUMP.2928304, 2023/07/06, add for sm8650
    dump_sm8650_wlan_log_dir="/sys/devices/platform/soc/b0000000.qcom,cnss-kiwi"

    #XiaSong@CONNECTIVITY.WIFI.HARDWARE.MINIDUMP.2928304, 2022/2/11, add for SM7450S wlan minidump
    dump_sm7450_wlan_log_dir="/sys/devices/platform/soc/8a00000.remoteproc-wpss/remoteproc/remoteproc3"

    #Gexuyang@CONNECTIVITY.WIFI.HARDWARE.MINIDUMP.2928304, 2023/11/23, add for SM7550 wlan minidump
    dump_sm7550_wlan_remoteproc="/sys/devices/platform/soc/9f700000.remoteproc-wpss/remoteproc/"

    #lixiong2@CONNECTIVITY.WIFI.HARDWARE.MINIDUMP.7001610, 2024/03/21, add for SM8750 wlan minidump
    dump_sm8750_wlan_log_dir="/sys/devices/platform/soc/b0000000.qcom,cnss-peach"

    if [ -d ${dump_sm7550_wlan_remoteproc} ]; then
        remoteproc=`ls -t ${dump_sm7550_wlan_remoteproc}`
    fi
    dump_sm7550_wlan_log_dir=${dump_sm7550_wlan_remoteproc}/${remoteproc}

    #liuhaifeng@CONNECTIVITY.WIFI.HARDWARE.MINIDUMP.2928304, 2024/01/09, add for SM7675 wlan minidump
    dump_sm7675_wlan_remoteproc="/sys/devices/platform/soc/9bb00000.remoteproc-wpss/remoteproc"
    if [ -d ${dump_sm7675_wlan_remoteproc} ]; then
        remoteproc=`ls -t ${dump_sm7675_wlan_remoteproc}`
    fi
    dump_sm7675_wlan_log_dir=${dump_sm7675_wlan_remoteproc}/${remoteproc}

    if [ -d ${dump_log_dir_v1} ]; then
        ALL_FILE=`ls -t ${dump_log_dir_v1}`
        for i in $ALL_FILE;
        do
            echo ${i}
            if [ -d ${dump_log_dir_v1}/${i} ]; then
               echo ${dump_log_dir_v1}/${i}/restart_level
               echo related > ${dump_log_dir_v1}/${i}/restart_level
            fi
        done
    fi

    if [ -d ${dump_log_dir_v2} ]; then
        ALL_FILE=`ls -t ${dump_log_dir_v2}`
        for i in $ALL_FILE;
        do
            echo "${dump_log_dir_v2}/${i}"
            if [ -d ${dump_log_dir_v2}/${i} ]; then
               setprop persist.vendor.ssr.restart_level ALL_ENABLE
               echo enabled > ${dump_log_dir_v2}/${i}/coredump
               echo enabled > ${dump_log_dir_v2}/${i}/recovery
            fi
        done
    fi

    if [ -d ${dump_sm8450_wlan_log_dir} ]; then
        echo 1 > ${dump_sm8450_wlan_log_dir}/recovery
    fi

    #lixiong@CONNECTIVITY.WIFI.HARDWARE.DUMP.2928304, 2022/08/11, add for sm8550
    if [ -d ${dump_sm8550_wlan_log_dir} ]; then
        echo 1 > ${dump_sm8550_wlan_log_dir}/recovery
    fi

    #XiaSong@CONNECTIVITY.WIFI.HARDWARE.MINIDUMP.2928304, 2022/2/11, add for SM7450S wlan minidump
    if [ -d ${dump_sm7450_wlan_log_dir} ]; then
        echo "enabled" > ${dump_sm7450_wlan_log_dir}/coredump
        echo "enabled" > ${dump_sm7450_wlan_log_dir}/recovery
    fi

    #Gexuyang@CONNECTIVITY.WIFI.HARDWARE.MINIDUMP.2928304, 2023/11/23, add for SM7550 wlan minidump
    if [ -d ${dump_sm7550_wlan_log_dir} ]; then
        echo "enabled" > ${dump_sm7550_wlan_log_dir}/coredump
        echo "enabled" > ${dump_sm7550_wlan_log_dir}/recovery
    fi

    #liuhaifeng@CONNECTIVITY.WIFI.HARDWARE.MINIDUMP.2928304, 2023/01/09, add for SM7675 wlan minidump
    if [ -d ${dump_sm7675_wlan_log_dir} ]; then
        echo "enabled" > ${dump_sm7675_wlan_log_dir}/coredump
        echo "enabled" > ${dump_sm7675_wlan_log_dir}/recovery
    fi

    #fangbinghua@CONNECTIVITY.WIFI.HARDWARE.DUMP.2928304, 2023/07/06, add for sm8650
    if [ -d ${dump_sm8650_wlan_log_dir} ]; then
        echo 1 > ${dump_sm8650_wlan_log_dir}/recovery
    fi

    #lixiong2@CONNECTIVITY.WIFI.HARDWARE.MINIDUMP.7001610, 2024/03/21, add for SM8750 wlan minidump
    if [ -d ${dump_sm8750_wlan_log_dir} ]; then
        echo 1 > ${dump_sm8750_wlan_log_dir}/recovery
    fi
}

#Qi.Zhang@TECH.BSP.Stability 2019/09/20, Add for uefi log
function LogcatUefi(){
    panicenable=`getprop persist.sys.assert.panic`
    camerapanic=`getprop persist.sys.assert.panic.camera`
    argtrue='true'
    if [ "${panicenable}" = "${argtrue}" ] || [ x"${camerapanic}" = x"true" ];then
        mkdir -p  ${CACHE_PATH}/uefi
        /system/system_ext/bin/extractCurrentUefiLog
    fi
}

function DumpEnvironment(){
    rm  -rf /cache/environment
    umask 000
    mkdir -p /cache/environment
    chmod 777 /data/misc/gpu/gpusnapshot/*
    ls -l /data/misc/gpu/gpusnapshot/ > /cache/environment/snapshotlist.txt
    cp -rf /data/misc/gpu/gpusnapshot/* /cache/environment/
    chmod 777 /cache/environment/dump*
    rm -rf /data/misc/gpu/gpusnapshot/*
    #ps -A > /cache/environment/ps.txt &
    #Jiaqi.Hao@Android.Stability,2024/11/19, add for get more ps info of minidump
    ps -ATZn -O PRI,NI,RTPRIO,SCH,PCY,CPU,NAME > /cache/environment/ps_thread.txt &
    mount > /cache/environment/mount.txt &
    futexwait_log="${DATA_OPLUS_LOG_PATH}/futexwait_log"
    if [ -d  ${futexwait_log} ];
    then
        all_logs=`ls ${futexwait_log}`
        for i in ${all_logs};do
            echo ${i}
            cp /data/system/dropbox/futexwait_log/${i}  /cache/environment/futexwait_log_${i}
        done
        chmod 777 /cache/environment/futexwait_log*
    fi
    getprop > /cache/environment/prop.txt &
    dumpsys SurfaceFlinger --dispsync > /cache/environment/sf_dispsync.txt &
    dumpsys SurfaceFlinger > /cache/environment/sf.txt &
    /system/bin/dmesg > /cache/environment/dmesg.txt &
    #Jiaqi.Hao@Android.Stability,2022/09/20, add for logcat android log only
    /system/bin/logcat -b crash -b system -b main -d -v threadtime > /cache/environment/android.txt &
    /system/bin/logcat -b radio -d -v threadtime > /cache/environment/radio.txt &
    /system/bin/logcat -b events -d -v threadtime > /cache/environment/events.txt &
    i=`pidof system_server`
    ls /proc/$i/fd -al > /cache/environment/system_server_fd.txt &
    ps -A -T | grep $i > /cache/environment/system_server_thread.txt &
    cp -rf /data/system/packages.xml /cache/environment/packages.xml
    chmod +r /cache/environment/packages.xml
    if [ -f "/dev/binderfs/binder_logs/state" ]; then
        cat /dev/binderfs/binder_logs/state > /cache/environment/binder_info.txt &
    else
        cat /sys/kernel/debug/binder/state > /cache/environment/binder_info.txt &
    fi
    cat /proc/meminfo > /cache/environment/proc_meminfo.txt &
    cat /d/ion/heaps/system > /cache/environment/iom_system_heaps.txt &
    #Yufeng.liu@Plf.AD.Performance, 2020/06/10, Add for ion memory leak
    cat /proc/osvelte/dma_buf/bufinfo > /cache/environment/dma_bufinfo.txt &
    #ifdef OPLUS_BUG_STABILITY
    #Daibo.Le@ANDROID.STABILITY, 2023/07/10, modify for get dma procinfo
    cat /proc/osvelte/dma_buf/procinfo > /cache/environment/dma_procinfo.txt &
    #endif /*OPLUS_BUG_STABILITY*/
    df -k > /cache/environment/df.txt &
    ls -l /data/anr > /cache/environment/anr_ls.txt &
    du -h -a /data/system/dropbox > /cache/environment/dropbox_du.txt &
    dumpsys activity intents > /cache/environment/intents.txt &
    watchdogfile=`getprop persist.sys.oplus.watchdogtrace`
    #Chunbo.Gao@ANDROID.DEBUG.BugID, 2019/4/23, Add for ...
    cp -rf ${DATA_DEBUGGING_PATH}/sf/backtrace/* /cache/environment/
    chmod 777 cache/environment/*
    if [ x"$watchdogfile" != x"0" ] && [ x"$watchdogfile" != x"" ]
    then
        chmod 666 $watchdogfile
        cp -rf $watchdogfile /cache/environment/
        setprop persist.sys.oplus.watchdogtrace 0
    fi
    wait
    setprop sys.dumpenvironment.finished 1
    umask 077
}

function packupminidump() {

    timestamp=`getprop sys.oplus.minidump.ts`
    echo time ${timestamp}
    uuid=`getprop sys.oplus.minidumpuuid`
    otaversion=`getprop ro.build.version.ota`
    minidumppath="${DATA_OPLUS_LOG_PATH}/DCS/de/minidump"
    #tag@hash@ota@datatime
    packupname=${minidumppath}/SYSTEM_LAST_KMSG@${uuid}@${otaversion}@${timestamp}
    echo name ${packupname}
    #read device info begin
    #"/proc/oplusVersion/serialID",
    #"/proc/devinfo/ddr",
    #"/proc/devinfo/emmc",
    #"proc/devinfo/emmc_version"};
    model=`getprop ro.product.model`
    version=`getprop ro.build.version.ota`
    echo "model:${model}" > ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    echo "version:${version}" >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    echo "/proc/oplusVersion/serialID" >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    cat /proc/oplusVersion/serialID >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    echo "\n/proc/devinfo/ddr" >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    cat /proc/devinfo/ddr >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    echo "/proc/devinfo/emmc" >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    cat /proc/devinfo/emmc >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    echo "/proc/devinfo/emmc_version" >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    cat /proc/devinfo/emmc_version >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    echo "/proc/devinfo/ufs" >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    cat /proc/devinfo/ufs >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    echo "/proc/devinfo/ufs_version" >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    cat /proc/devinfo/ufs_version >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    echo "/proc/oplusVersion/ocp" >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    cat /proc/oplusVersion/ocp >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    cp /data/system/packages.xml ${DATA_OPLUS_LOG_PATH}/DCS/minidump/packages.xml
    echo "tar -czvf ${packupname} -C ${DATA_OPLUS_LOG_PATH}/DCS/minidump ." >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    tar -czvf ${packupname}.dat.gz.tmp -C ${DATA_OPLUS_LOG_PATH}/DCS/minidump .
    echo "chown system:system ${packupname}*" >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    chown system:system ${packupname}*
    echo "mv ${packupname}.dat.gz.tmp ${packupname}.dat.gz" >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    mv ${packupname}.dat.gz.tmp ${packupname}.dat.gz
    chown system:system ${packupname}*
    echo "-rf ${DATA_OPLUS_LOG_PATH}/DCS/minidump"
    rm -rf ${DATA_OPLUS_LOG_PATH}/DCS/minidump
    #setprop sys.oplus.phoenix.handle_error ERROR_REBOOT_FROM_KE_SUCCESS
    setprop sys.backup.minidump.tag "SYSTEM_LAST_KMSG"
    setprop ctl.start backup_minidumplog
}

function olcpackupminidump() {

    echo time ${timestamp}
    model=`getprop ro.product.model`
    version=`getprop ro.build.version.ota`
    echo "model:${model}" > ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    echo "version:${version}" >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    echo "/proc/oplusVersion/serialID" >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    cat /proc/oplusVersion/serialID >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    echo "\n/proc/devinfo/ddr" >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    cat /proc/devinfo/ddr >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    echo "/proc/devinfo/emmc" >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    cat /proc/devinfo/emmc >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    echo "/proc/devinfo/emmc_version" >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    cat /proc/devinfo/emmc_version >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    echo "/proc/devinfo/ufs" >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    cat /proc/devinfo/ufs >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    echo "/proc/devinfo/ufs_version" >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    cat /proc/devinfo/ufs_version >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    echo "/proc/oplusVersion/ocp" >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    cat /proc/oplusVersion/ocp >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    echo "chown system:system ${DATA_OPLUS_LOG_PATH}/DCS/minidump/*" >> ${DATA_OPLUS_LOG_PATH}/DCS/minidump/device.info
    chown system:system ${DATA_OPLUS_LOG_PATH}/DCS/minidump/*
    setprop sys.backup.minidump.tag "SYSTEM_LAST_KMSG"
}

#Fangfang.Hui@TECH.AD.Stability, 2019/08/13, Add for the quality feedback dcs config
function backupMinidump() {
    tag=`getprop sys.backup.minidump.tag`
    if [ x"$tag" = x"" ]; then
        echo "backup.minidump.tag is null, do nothing"
        return
    fi
    minidumppath="${DATA_OPLUS_LOG_PATH}/DCS/de/minidump"
    miniDumpFile=$minidumppath/$(ls -t ${minidumppath} | head -1)
    if [ x"$miniDumpFile" = x"" ]; then
        echo "minidump.file is null, do nothing"
        return
    fi
    result=$(echo $miniDumpFile | grep "${tag}")
    if [ x"$result" = x"" ]; then
        echo "tag mismatch, do not backup"
        return
    else
        try_copy_minidump_to_oplusreserve $miniDumpFile
        setprop sys.backup.minidump.tag ""
    fi
}

function try_copy_minidump_to_oplusreserve() {
    OPLUSRESERVE_MINIDUMP_BACKUP_PATH="${DATA_OPLUS_LOG_PATH}/oplusreserve/media/log/minidumpbackup"
    OPLUSRESERVE2_MOUNT_POINT="/mnt/vendor/oplusreserve"

    if [ ! -d ${OPLUSRESERVE_MINIDUMP_BACKUP_PATH} ]; then
        mkdir ${OPLUSRESERVE_MINIDUMP_BACKUP_PATH}
    fi

    NewLogPath=$1
    if [ ! -f $NewLogPath ] ;then
        echo "Can not access ${NewLogPath}, the file may not exists "
        return
    fi
    TmpLogSize=$(du -sk ${NewLogPath} | sed 's/[[:space:]]/,/g' | cut -d "," -f1)
    curBakCount=`ls ${OPLUSRESERVE_MINIDUMP_BACKUP_PATH} | wc -l`
    echo "curBakCount = ${curBakCount}, TmpLogSize = ${TmpLogSize}, NewLogPath = ${NewLogPath}"
    while [ ${curBakCount} -gt 2 ]   #can only save 2 backup minidump logs at most
    do
        rm -rf ${OPLUSRESERVE_MINIDUMP_BACKUP_PATH}/$(ls -t ${OPLUSRESERVE_MINIDUMP_BACKUP_PATH} | tail -1)
        curBakCount=`ls ${OPLUSRESERVE_MINIDUMP_BACKUP_PATH} | wc -l`
        echo "delete one file curBakCount = $curBakCount"
    done
    FreeSize=$(df -ak | grep "${OPLUSRESERVE2_MOUNT_POINT}" | sed 's/[ ][ ]*/,/g' | cut -d "," -f4)
    TotalSize=$(df -ak | grep "${OPLUSRESERVE2_MOUNT_POINT}" | sed 's/[ ][ ]*/,/g' | cut -d "," -f2)
    ReserveSize=`expr $TotalSize / 5`
    NeedSize=`expr $TmpLogSize + $ReserveSize`
    echo "NeedSize = ${NeedSize}, ReserveSize = ${ReserveSize}, FreeSize = ${FreeSize}"
    while [ ${FreeSize} -le ${NeedSize} ]
    do
        curBakCount=`ls ${OPLUSRESERVE_MINIDUMP_BACKUP_PATH} | wc -l`
        if [ $curBakCount -gt 1 ]; then #leave at most on log file
            rm -rf ${OPLUSRESERVE_MINIDUMP_BACKUP_PATH}/$(ls -t ${OPLUSRESERVE_MINIDUMP_BACKUP_PATH} | tail -1)
            echo "${OPLUSRESERVE2_MOUNT_POINT} left space ${FreeSize} not enough for minidump, delete one de minidump"
            FreeSize=$(df -k | grep "${OPLUSRESERVE2_MOUNT_POINT}" | sed 's/[ ][ ]*/,/g' | cut -d "," -f4)
            continue
        fi
        echo "${OPLUSRESERVE2_MOUNT_POINT} left space ${FreeSize} not enough for minidump, nothing to delete"
        return 0
    done
    #space is enough, now copy
    cp $NewLogPath $OPLUSRESERVE_MINIDUMP_BACKUP_PATH
    chmod -R 0771 ${OPLUSRESERVE_MINIDUMP_BACKUP_PATH}
    chown -R system ${OPLUSRESERVE_MINIDUMP_BACKUP_PATH}
    chgrp -R system ${OPLUSRESERVE_MINIDUMP_BACKUP_PATH}
}

#Jianping.Zheng@Swdp.Android.Stability.Crash,2017/04/04,add for record performance
function perf_record() {
    check_interval=`getprop persist.sys.oppo.perfinteval`
    if [ x"${check_interval}" = x"" ]; then
        check_interval=60
    fi
    perf_record_path=${DATA_DEBUGGING_PATH}/perf_record_logs
    while [ true ];do
        if [ ! -d ${perf_record_path} ];then
            mkdir -p ${perf_record_path}
        fi

        echo "\ndate->" `date` >> ${perf_record_path}/cpu.txt
        cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq >> ${perf_record_path}/cpu.txt

        echo "\ndate->" `date` >> ${perf_record_path}/mem.txt
        cat /proc/meminfo >> ${perf_record_path}/mem.txt

        echo "\ndate->" `date` >> ${perf_record_path}/buddyinfo.txt
        cat /proc/buddyinfo >> ${perf_record_path}/buddyinfo.txt

        echo "\ndate->" `date` >> ${perf_record_path}/top.txt
        top -n 1 >> ${perf_record_path}/top.txt

        topneocount=0
        if [ $topneocount -le 10 ]; then
            topneo=`top -n 1 | grep neo | awk '{print $9}' | head -n 1 | awk -F . '{print $1}'`;
            if [ $topneo -gt 90 ]; then
                neopid=`ps -A | grep neo | awk '{print $2}'`;
                echo "\ndate->" `date` >> ${perf_record_path}/neo_debuggerd.txt
                debuggerd $neopid >> ${perf_record_path}/neo_debuggerd.txt;
                let topneocount+=1
            fi
        fi

        sleep "$check_interval"
    done
}

#Fuchun.Liao@BSP.CHG.Basic 2019/06/09 modify for black/bright check
function create_black_bright_check_file(){
	if [ ! -d "/data/oplus/log/bsp" ]; then
		mkdir -p /data/oplus/log/bsp
		chmod -R 777 /data/oplus/log/bsp
		chown -R system:system /data/oplus/log/bsp
	fi

	if [ ! -f "/data/oplus/log/bsp/blackscreen_count.txt" ]; then
		touch /data/oplus/log/bsp/blackscreen_count.txt
		echo 0 > /data/oplus/log/bsp/blackscreen_count.txt
	fi
	chmod 0664 /data/oplus/log/bsp/blackscreen_count.txt

	if [ ! -f "/data/oplus/log/bsp/blackscreen_happened.txt" ]; then
		touch /data/oplus/log/bsp/blackscreen_happened.txt
		echo 0 > /data/oplus/log/bsp/blackscreen_happened.txt
	fi
	chmod 0664 /data/oplus/log/bsp/blackscreen_happened.txt

	if [ ! -f "/data/oplus/log/bsp/brightscreen_count.txt" ]; then
		touch /data/oplus/log/bsp/brightscreen_count.txt
		echo 0 > /data/oplus/log/bsp/brightscreen_count.txt
	fi
	chmod 0664 /data/oplus/log/bsp/brightscreen_count.txt

	if [ ! -f "/data/oplus/log/bsp/brightscreen_happened.txt" ]; then
		touch /data/oplus/log/bsp/brightscreen_happened.txt
		echo 0 > /data/oplus/log/bsp/brightscreen_happened.txt
	fi
	chmod 0664 /data/oplus/log/bsp/brightscreen_happened.txt
}
#================================== STABILITY =========================

#Fei.Mo@PSW.BSP.Sensor, 2017/09/05 ,Add for power monitor top info
function thermalTop(){
   top -m 3 -n 1 > /data/system/dropbox/thermalmonitor/top
   chown system:system /data/system/dropbox/thermalmonitor/top
}
#end, Add for power monitor top info

function logcusmain() {
    echo "logcusmain begin"
    path=${DATA_DEBUGGING_PATH}/customer/apps
    rm -rf ${DATA_DEBUGGING_PATH}/customer
    mkdir -p ${path}
    /system/bin/logcat  -f ${path}/android.txt -r10240 -n 2 -v threadtime *:V
    echo "logcusmain end"
}

function logcusevent() {
    echo "logcusevent begin"
    path=${DATA_DEBUGGING_PATH}/customer/apps
    mkdir -p ${path}
    /system/bin/logcat -b events -f ${path}/event.txt -r10240 -n 2 -v threadtime *:V
    echo "logcusevent end"
}

function logcusradio() {
    echo "logcusradio begin"
    path=${DATA_DEBUGGING_PATH}/customer/apps
    mkdir -p ${path}
    /system/bin/logcat -b radio -f ${path}/radio.txt -r10240 -n 2 -v threadtime *:V
    echo "logcusradio end"
}

function logcustcpdump() {
    echo "logcustcpdump begin"
    path=${DATA_DEBUGGING_PATH}/tcpdump
    if [ -d  ${path} ]; then
        rm -rf ${path}
    fi
    mkdir -p ${path}
    chmod 777 ${path} -R
    tcpdump -i any -p -s 0 -W 2 -C 50 -w ${path}/tcpdump.pcap
    echo "logcustcpdump end"
}

function logcuschmod() {
    path=${DATA_DEBUGGING_PATH}/tcpdump
    chown system:system ${path} -R
    chmod 777 ${path} -R
}

function logcusqmistart() {
    echo "logcusqmistart begin"
    echo 0x2 > /sys/module/ipc_router_core/parameters/debug_mask
    #add for SM8150 platform
    if [ -d "/d/ipc_logging" ]; then
        path=${DATA_DEBUGGING_PATH}/customer/ipc_log
        mkdir -p ${path}
        cat /d/ipc_logging/adsp/log > ${path}/adsp_glink.txt
        cat /d/ipc_logging/modem/log > ${path}/modem_glink.txt
        cat /d/ipc_logging/cdsp/log > ${path}/cdsp_glink.txt
        cat /d/ipc_logging/qrtr_0/log > ${path}/modem_qrtr.txt
        cat /d/ipc_logging/qrtr_5/log > ${path}/sensor_qrtr.txt
        cat /d/ipc_logging/qrtr_10/log > ${path}/NPU_qrtr.txt
        /vendor/bin/qrtr-lookup > ${path}/qrtr-lookup_start.txt
    fi
    echo "logcusqmistart end"
}
function logcusqmistop() {
    echo "logcusqmistop begin"
    echo 0x0 > /sys/module/ipc_router_core/parameters/debug_mask
    path=${DATA_DEBUGGING_PATH}/customer/ipc_log
    mkdir -p ${path}
    /vendor/bin/qrtr-lookup > ${path}/qrtr-lookup_stop.txt
    echo "logcusqmistop end"
}

#ifdef OPLUS_FEATURE_WIFI_LOG
#YangQing@OPLUS_FEATURE_WIFI_LOG, 2022/05/13 , add for collect wifi log
function captureTcpdumpLog(){
    COLLECT_LOG_PATH="${DATA_DEBUGGING_PATH}/wifi_log_temp/"
    if [ -d  ${COLLECT_LOG_PATH} ];then
        rm -rf ${COLLECT_LOG_PATH}
    fi
    if [ ! -d  ${COLLECT_LOG_PATH} ];then
        mkdir -p ${COLLECT_LOG_PATH}
        chown system:system ${COLLECT_LOG_PATH}
        chmod -R 777 ${COLLECT_LOG_PATH}
    fi
    tcpdump -i any -p -s 0 -W 4 -C 5 -w ${COLLECT_LOG_PATH}/tcpdump -Z system
}

#endif /* OPLUS_FEATURE_WIFI_LOG */

#Guotian.Wu add for wifi p2p connect fail log
function collectWifiP2pLog() {
    boot_completed=`getprop sys.boot_completed`
    while [ x${boot_completed} != x"1" ];do
        sleep 2
        boot_completed=`getprop sys.boot_completed`
    done
    wifiP2pLogPath="${DATA_DEBUGGING_PATH}/wifi_p2p_log"
    if [ ! -d  ${wifiP2pLogPath} ];then
        mkdir -p ${wifiP2pLogPath}
    fi

    # collect driver and firmware log
    cnss_pid=`getprop vendor.oplus.wifi.cnss_diag_pid`
    if [[ "w${cnss_pid}" != "w" ]];then
        kill -s SIGUSR1 $cnss_pid
        sleep 2
        mv /data/vendor/wifi/buffered_wlan_logs/* $wifiP2pLogPath
        chmod 666 ${wifiP2pLogPath}/buffered*
    fi

    dmesg > ${wifiP2pLogPath}/dmesg.txt
    /system/bin/logcat -b main -b system -f ${wifiP2pLogPath}/android.txt -r10240 -v threadtime *:V
}

function packWifiP2pFailLog() {
    wifiP2pLogPath="${DATA_DEBUGGING_PATH}/wifi_p2p_log"
    DCS_WIFI_LOG_PATH=`getprop oppo.wifip2p.connectfail`
    logReason=`getprop oplus.wifi.p2p.log.reason`
    logFid=`getprop oplus.wifi.p2p.log.fid`
    version=`getprop ro.build.version.ota`

    if [ "w${logReason}" == "w" ];then
        return
    fi

    if [ ! -d ${DCS_WIFI_LOG_PATH} ];then
        mkdir -p ${DCS_WIFI_LOG_PATH}
        chown system:system ${DCS_WIFI_LOG_PATH}
        chmod -R 777 ${DCS_WIFI_LOG_PATH}
    fi

    if [ ! -d  ${wifiP2pLogPath} ];then
        return
    fi

    tar -czvf  ${DCS_WIFI_LOG_PATH}/${logReason}.tar.gz -C ${wifiP2pLogPath} ${wifiP2pLogPath}
    abs_file=${DCS_WIFI_LOG_PATH}/${logReason}.tar.gz

    fileName="wifip2p_connect_fail@${logFid}@${version}@${logReason}.tar.gz"
    mv ${abs_file} ${DCS_WIFI_LOG_PATH}/${fileName}
    chown system:system ${DCS_WIFI_LOG_PATH}/${fileName}
    setprop sys.oplus.wifi.p2p.log.stop 0
    rm -rf ${wifiP2pLogPath}
}

#Zaogen.Hong@PSW.CN.WiFi.Connect,2020/03/03, Add for trigger wifi dump by engineerMode
function wifi_minidump() {
    iwpriv wlan0 setUnitTestCmd 19 1 4
}

#ifdef OPLUS_FEATURE_RECOVERY_BOOT
#Shuangquan.du@ANDROID.UPDATABILITY, 2019/07/03, add for generate runtime prop
function generate_runtime_prop() {
    getprop | sed -r 's|\[||g;s|\]||g;s|: |=|' | sed 's|ro.cold_boot_done=true||g' > /cache/runtime.prop
    chown root:root /cache/runtime.prop
    chmod 600 /cache/runtime.prop
    sync
}
#endif /* OPLUS_FEATURE_RECOVERY_BOOT */

#Qilong.Ao@ANDROID.BIOMETRICS, 2020/10/16, Add for adb sync
function oplussync() {
    sync
}
#endif

#add for oidt begin
#PanZhuan@BSP.Tools, 2020/10/21, modify for way of OIDT log collection changed, please contact me for new reqirement in the future
function oidtlogs() {
    # get this prop to remove specified path
    removed_path=`getprop sys.oidt.remove_path`
    if [ "$removed_path" ];then
        traceTransferState "remove path ${removed_path}"
        rm -rf ${removed_path}
        setprop sys.oidt.remove_path ''
        return
    fi

    traceTransferState "oidtlogs start... "
    setprop sys.oidt.log_ready 0

    log_path=`getprop sys.oidt.log_path`
    if [ "$log_path" ];then
        oidt_root=${log_path}
    else
        oidt_root="BASE_PATH/oidt/"
    fi

    mkdir -p ${oidt_root}
    traceTransferState "oidt root: ${oidt_root}"

    log_config_file=`getprop sys.oidt.log_config`
    traceTransferState "log config file: ${log_config_file} "

    if [ "$log_config_file" ];then
        paths=`cat ${log_config_file}`

        for file_path in ${paths};do
            # create parent directory of each path
            dest_path=${oidt_root}${file_path%/*}
            # replace dunplicate character '//' with '/' in directory
            dest_path=${dest_path//\/\//\/}
            mkdir -p ${dest_path}
            traceTransferState "copy ${file_path} "
            cp -rf ${file_path} ${dest_path}
        done

        chmod -R 777 ${oidt_root}

        setprop sys.oidt.log_config ''
    fi

    setprop sys.oidt.log_ready 1
    setprop sys.oidt.log_path ''
    traceTransferState "oidtlogs end "
}
#add for oidt end

#ifdef OPLUS_FEATURE_MEMLEAK_DETECT
#Hailong.Liu@ANDROID.MM, 2020/03/18, add for capture native malloc leak on aging_monkey test
function storeSvelteLog() {
    local dest_dir="/data/oplus/heapdump/svelte/"
    local log_file="${dest_dir}/svelte_log.txt"
    local log_dev="/dev/svelte_log"

    if [ ! -c ${log_dev} ]; then
        /system/bin/logwrapper echo "svelte ${log_dev} does not exist."
        return 1
    fi

    if [ ! -d ${dest_dir} ]; then
        mkdir -p ${dest_dir}
        if [ "$?" -ne "0" ]; then
            /system/bin/logwrapper echo "svelte mkdir failed."
            return 1
        fi
        chmod 0777 ${dest_dir}
    fi

    if [ ! -f ${log_file} ]; then
        echo --------Start `date` >> ${log_file}
        if [ "$?" -ne "0" ]; then
            /system/bin/logwrapper echo "svelte create file failed."
            return 1
        fi
        chmod 0777 ${log_file}
    fi

    /system/bin/logwrapper echo "start store svelte log."
    while true
    do
        echo --------`date` >> ${log_file}
        /system/system_ext/bin/svelte logger >> ${log_file}
    done
}
#endif /* OPLUS_FEATURE_MEMLEAK_DETECT */

function traceTransferState() {
    content=$1

    if [[ -d ${BASE_PATH} ]]; then
        if [[ ! -d ${SDCARD_LOG_BASE_PATH} ]]; then
            mkdir -p ${SDCARD_LOG_BASE_PATH}
            chmod 2770 ${BASE_PATH} -R
            echo "${CURTIME_FORMAT} TRACETRANSFERSTATE:${SDCARD_LOG_BASE_PATH} " >> ${SDCARD_LOG_BASE_PATH}/logkit_transfer.log
        fi

        currentTime=`date "+%Y-%m-%d %H:%M:%S"`
        echo "${currentTime} ${content} " >> ${SDCARD_LOG_BASE_PATH}/logkit_transfer.log
    fi

    LOG_LEVEL=$2
    if [[ "${LOG_LEVEL}" == "" ]]; then
        LOG_LEVEL=d
    fi
    log -p ${LOG_LEVEL} -t Debuglog ${content}
}

function chmodDcsEnPath() {
    DCS_EN_PATH=${DATA_OPLUS_LOG_PATH}/DCS/en
    chmod 777 -R ${DCS_EN_PATH}
}

function oplus_compact_memory() {
	echo 1 > "/proc/sys/vm/compact_memory"
}

#ifdef OPLUS_BUG_STABILITY
#Daibo.Le@ANDROID.STABILITY, 2023/06/30, add for BBDS collecting binder log
function binder_infos_capture() {
    REASON_NAME=`getprop sys.debug.bbdscollectbinderreason`
    if [ "${REASON_NAME}" == "" ]; then
        REASON_NAME="binderinfo"
    fi

    STABILITY_LOG_PATH="${DATA_OPLUS_LOG_PATH}/DCS/de/stability_monitor"
    BINDER_LOG_DIR="${STABILITY_LOG_PATH}/${REASON_NAME}"
    if [ ! -d "${BINDER_LOG_DIR}" ]; then
        mkdir -p ${BINDER_LOG_DIR}
        chown system:system ${BINDER_LOG_DIR}
        chmod 777 ${BINDER_LOG_DIR}
    fi
    if [ -f "/dev/binderfs/binder_logs/state" ]; then
        cat /dev/binderfs/binder_logs/state > ${BINDER_LOG_DIR}/state
        cat /dev/binderfs/binder_logs/stats > ${BINDER_LOG_DIR}/stats
        cat /dev/binderfs/binder_logs/transaction_log > ${BINDER_LOG_DIR}/transaction_log
        cat /dev/binderfs/binder_logs/transactions > ${BINDER_LOG_DIR}/transactions
    else
        cat /d/binder/state > ${BINDER_LOG_DIR}/state
        cat /d/binder/stats > ${BINDER_LOG_DIR}/stats
        cat /d/binder/transaction_log > ${BINDER_LOG_DIR}/transaction_log
        cat /d/binder/transactions > ${BINDER_LOG_DIR}/transactions
    fi

    debuggerd -j `pidof system_server` > ${BINDER_LOG_DIR}/system_server.txt &
    logcat -b crash -b events -b main -b system -d > ${BINDER_LOG_DIR}/logcat.txt &
    dmesg > ${BINDER_LOG_DIR}/dmesg.txt &
    #Jiaqi.Hao@Android.Stability,2024/11/19, add for get more ps info of BBDS binder log
    ps -AT -O NAME > ${BINDER_LOG_DIR}/ps.txt &

    logtime=`date +%F-%H-%M-%S`
    uuid=`cat /proc/sys/kernel/random/uuid`
    version=`getprop ro.build.version.ota`
    sleep 10

    filename="${STABILITY_LOG_PATH}/${REASON_NAME}@${uuid}@${version}@${logtime}.tar.gz"
    tar -czvf ${filename} -C ${STABILITY_LOG_PATH} ${REASON_NAME}
    chown system:system ${filename}
    chmod 0666 ${filename}
    rm -rf ${BINDER_LOG_DIR}
}
#endif /*OPLUS_BUG_STABILITY*/

#ifdef OPLUS_FEATURE_THEIA
#Zhurui2@ANDROID.STABILITY, 2025/05/02, add for Smart trace dump
function binder_smart_trace_capture() {
    DATA_ANR_PATH=/data/anr

    if [ -d "${DATA_ANR_PATH}" ]; then
        if [ -f "/dev/binderfs/binder_logs/state" ]; then
            cat /dev/binderfs/binder_logs/state > ${DATA_ANR_PATH}/smart_trace_state
        else
            cat /d/binder/state > ${DATA_ANR_PATH}/smart_trace_state
        fi
        chmod 777 ${DATA_ANR_PATH}/smart_trace_state
    else
        echo "dir ${DATA_ANR_PATH} does not exist."
        return 1
    fi
}
#endif /*OPLUS_FEATURE_THEIA*/

#ifdef OPLUS_ANR_LOG_ENHANCEMENT_HELPER
#Jason.Yu@ANDROID.STABILITY, 2023/12/11, add for Anr Log Enhancement
function catch_nfw_info() {
    NFW_DIR=${DATA_OPLUS_LOG_PATH}/nfw_info
    if [ ! -d ${NFW_DIR} ];then
        mkdir -p ${NFW_DIR}
    fi

    FileNum=$(ls -l ${NFW_DIR} | grep "^d"| wc -l)
    if [ ${FileNum} -ge 10 ]; then
        oldDir=$(ls -rt ${NFW_DIR} | head -1)
        rm -rf ${NFW_DIR}/${oldDir}
    fi

    LOGTIME=`date +%F-%H-%M-%S`
    TIME_DIR=${NFW_DIR}/${LOGTIME}
    mkdir -p ${TIME_DIR}
    dumpsys -t 5  SurfaceFlinger > ${TIME_DIR}/sf.txt
    chmod -R 777 ${NFW_DIR}
    chown -R system:system ${NFW_DIR}
}
#endif /* OPLUS_ANR_LOG_ENHANCEMENT_HELPER */

case "$config" in
    "bugreportandtransfer")
        bugreportandtransfer
        ;;
    "tranfer_tombstone")
        transferTombstone
        ;;
    "initopluslog")
        initOplusLog
        ;;
    "copyCamDcsLog")
        copyCamDcsLog
        ;;
    "tranfer_anr")
        transferAnr
        ;;
#Chunbo.Gao@ANDROID.DEBUG.2514795, 2019/11/12, Add for copy binder_info
    "copybinderinfo")
        copybinderinfo
    ;;
#Wuchao.Huang@ROM.Framework.EAP, 2019/11/19, Add for copy binder_info
    "copyEapBinderInfo")
        copyEapBinderInfo
    ;;
    # ifdef OPLUS_FEATURE_THEIA
    # Yangkai.Yu@ANDROID.STABILITY, Add hook for TheiaBinderBlock
    "copyTheiaBinderInfo")
        copyTheiaBinderInfo
    ;;
    # endif /*OPLUS_FEATURE_THEIA*/
#Miao.Yu@ANDROID.WMS, 2019/11/25, Add for dump wm info
    "dumpWm")
        dumpWm
    ;;
    "fingerprintlog")
        fingerprintLog
        ;;
    "fpqess")
        fingerprintQseeLog
        ;;
    #Qi.Zhang@TECH.BSP.Stability 2019/09/20, Add for uefi log
    "logcatuefi")
        LogcatUefi
        ;;
    "tcpdumplog")
        initLogSizeAndNums
        #ifndef OPLUS_FEATURE_TCPDUMP
        #DuYuanhua@NETWORK.DATA.2959182, remove redundant code for rutils-remove action
        #enabletcpdump
        #endif
        tcpDumpLog
        ;;
    "displayLog")
        displayLog
        ;;
#ifdef OPLUS_FEATURE_RECOVERY_BOOT
#Shuangquan.du@ANDROID.UPDATABILITY, 2019/07/03, add for generate runtime prop
    "generate_runtime_prop")
        generate_runtime_prop
        ;;
#endif /* OPLUS_FEATURE_RECOVERY_BOOT */
#Qilong.Ao@ANDROID.BIOMETRICS, 2020/10/16, Add for adb sync
    "oplussync")
        oplussync
        ;;
#endif
    "dumpenvironment")
        DumpEnvironment
        ;;
    "initcache")
        initcache
        ;;
    "logcatcache")
        logcatcache
        ;;
    "radiocache")
        radiocache
        ;;
    "eventcache")
        eventcache
        ;;
    "kernelcache")
        kernelcache
        ;;
    "tcpdumpcache")
        tcpdumpcache
        ;;
    "fingerprintcache")
        fingerprintcache
        ;;
    "fplogcache")
        fplogcache
        ;;
    "gettpinfo")
        gettpinfo
    ;;
    "gettpserviceinfo")
        gettpserviceinfo
    ;;
    "inittpdebug")
        inittpdebug
    ;;
    "settplevel")
        settplevel
    ;;
#Canjie.Zheng@ANDROID.DEBUG,2017/03/09, add for Sensor.logger
    "resetlogpath")
        resetlogpath
    ;;
    "dumpon")
        dumpon
    ;;
    "dumpoff")
        dumpoff
    ;;
    "packupminidump")
        packupminidump
    ;;
    "olcpackupminidump")
        olcpackupminidump
    ;;
#Jianping.Zheng@Swdp.Android.Stability.Crash,2017/04/04,add for record performance
        "perf_record")
        perf_record
    ;;
#Fei.Mo@PSW.BSP.Sensor, 2017/09/01 ,Add for power monitor top info
        "thermal_top")
        thermalTop
#end, Add for power monitor top info
    ;;
#Linjie.Xu@PSW.AD.Power.PowerMonitor.1104067, 2018/01/17, Add for OplusPowerMonitor get dmesg at O
        "kernelcacheforopm")
        kernelcacheforopm
    ;;
        "catchClockForOpm")
        catchClockForOpm
    ;;
        "enableClkDebugSuspend")
        enableClkDebugSuspend
    ;;
        "disableClkDebugSuspend")
        disableClkDebugSuspend
    ;;
        "enableRegulatorDebugSuspend")
        enableRegulatorDebugSuspend
    ;;
        "disableRegulatorDebugSuspend")
        disableRegulatorDebugSuspend
    ;;
        "enableSystemServerFreezeOrder")
        enableSystemServerFreezeOrder
    ;;
        "disableSystemServerFreezeOrder")
        disableSystemServerFreezeOrder
    ;;
#Jianfa.Chen@PSW.AD.PowerMonitor,add for powermonitor getting Xlog
        "catchWXlogForOpm")
        catchWXlogForOpm
    ;;
        "catchViolatorInfo")
        catchViolatorInfo
    ;;
        "catchQQlogForOpm")
        catchQQlogForOpm
    ;;
# FaQuan.Yao@BSP.Power, 2024/04/03, add for checking suspend mode and reset to s2idle.
        "catSuspendMode")
        catSuspendMode
    ;;
        "checkAndResetSuspendMode")
        checkAndResetSuspendMode
    ;;
# Qiurun.Zhou@ANDROID.DEBUG, 2022/6/17, copy wxlog for EAP
        "eapCopyWXlog")
        eapCopyWXlog
    ;;
# Ruihuai.Wu@BSP.Power, 2024/04/26, add for smp2p statistic function.
        "enableSmptpStats")
        enableSmptpStats
    ;;
# Ruihuai.Wu@BSP.Power, 2024/04/26, add for smp2p statistic function.
        "disableSmptpStats")
        disableSmptpStats
    ;;
# Ruihuai.Wu@BSP.Power, 2024/04/26, add for smp2p statistic function.
        "resetSmptpStats")
        resetSmptpStats
    ;;
# Chunxing.Yang@BSP.POWER, 2024/07/10, add for timerfd statistic function.
        "catchTimerfdInfoForOpm")
		catchTimerfdInfoForOpm
	;;
# Chunxing.Yang@BSP.POWER, 2024/07/10, add for timerfd statistic function.
        "enableTimerfdStats")
		enableTimerfdStats
	;;
# Chunxing.Yang@BSP.POWER, 2024/07/10, add for timerfd statistic function.
        "disableTimerfdStats")
		disableTimerfdStats
	;;
#Linjie.Xu@PSW.AD.Power.PowerMonitor.1104067, 2018/01/17, Add for OplusPowerMonitor get Sysinfo at O
        "psforopm")
        psforopm
    ;;
# WangMin@ANDROID.RESCONTROL, 2023/05/11, Add for save newest wxlog when wx memleak
        "copyWXlogForMemLeak")
        copyWXlogForMemLeak
    ;;
# WangMin@ANDROID.RESCONTROL, 2023/12/13, Add for save newest browser xlog when com.haytap.browser memleak
        "copyBrowserXlogForMemLeak")
        copyBrowserXlogForMemLeak
    ;;
# Zhurui2@ANDROID.STABILITY, 2023/11/17, add for save newest wxlog when theia anr\crash\nfw
        "copyXlogForTheia")
        copyXlogForTheia
    ;;
        "tranferPowerRelated")
        tranferPowerRelated
    ;;
        "startSsLogPower")
        startSsLogPower
    ;;
        "logcatMainCacheForOpm")
        logcatMainCacheForOpm
    ;;
        "logcatEventCacheForOpm")
        logcatEventCacheForOpm
    ;;
        "logcatRadioCacheForOpm")
        logcatRadioCacheForOpm
    ;;
        "catchBinderInfoForOpm")
        catchBinderInfoForOpm
    ;;
        "catchInterruptsInfoForOpm")
        catchInterruptsInfoForOpm
    ;;
        "catchBattertFccForOpm")
        catchBattertFccForOpm
    ;;
        "catchTopInfoForOpm")
        catchTopInfoForOpm
    ;;
          "dumpsysHansHistoryForOpm")
        dumpsysHansHistoryForOpm
    ;;
        "getPropForOpm")
        getPropForOpm
    ;;
        "dumpsysSurfaceFlingerForOpm")
        dumpsysSurfaceFlingerForOpm
    ;;
        "dumpsysSensorserviceForOpm")
        dumpsysSensorserviceForOpm
    ;;
        "dumpsysBatterystatsForOpm")
        dumpsysBatterystatsForOpm
    ;;
        "dumpsysBatterystatsOplusCheckinForOpm")
        dumpsysBatterystatsOplusCheckinForOpm
    ;;
        "dumpsysBatterystatsCheckinForOpm")
        dumpsysBatterystatsCheckinForOpm
    ;;
        "dumpsysMediaForOpm")
        dumpsysMediaForOpm
    ;;
#Linjie.Xu@PSW.AD.Power.PowerMonitor.1104067, 2019/08/21, Add for OplusPowerMonitor get qrtr at Qcom
        "qrtrlookupforopm")
        qrtrlookupforopm
    ;;
        "cpufreqforopm")
        cpufreqforopm
    ;;
        "slabinfoforhealth")
        slabinfoforhealth
    ;;
        "svelteforhealth")
        svelteforhealth
    ;;
        "meminfoforhealth")
        meminfoforhealth
    ;;
        "dmaprocsforhealth")
        dmaprocsforhealth
    ;;
        "customdmesg")
        customdmesg
    ;;
        "customdiaglog")
        customdiaglog
    ;;
#ZhuYan@Network.ARCH, 2021/05/18, Add for catche ap log postback
        "logcusmain")
        logcusmain
    ;;
        "logcusevent")
        logcusevent
    ;;
        "logcusradio")
        logcusradio
    ;;
        "logcustcpdump")
        logcustcpdump
    ;;
        "logcuschmod")
        logcuschmod
    ;;
#endif
        "logcusqmistart")
        logcusqmistart
    ;;
        "logcusqmistop")
        logcusqmistop
    ;;
#laixin@PSW.CN.WiFi.Basic.Switch.1069763, 2018/09/03, Add for collect wifi switch log
        "collectWifiP2pLog")
        collectWifiP2pLog
    ;;
        "packWifiP2pFailLog")
        packWifiP2pFailLog
    ;;
#Zaogen.Hong@PSW.CN.WiFi.Connect,2020/03/03, Add for trigger wifi dump by engineerMode
        "wifi_minidump")
        wifi_minidump
    ;;
#ifdef OPLUS_BUG_STABILITY
#Qing.Wu@ANDROID.STABILITY.2278668, 2019/09/03, Add for capture binder info
    "binderinfocapture")
        binderinfocapture
        ;;
#endif /* OPLUS_BUG_STABILITY */
#ifdef OPLUS_BUG_STABILITY
#Tian.Pan@ANDROID.STABILITY.3054721.2020/08/31.add for fix debug system_server register too many receivers issue.
    "receiverinfocapture")
        receiverinfocapture
        ;;
#endif /*OPLUS_BUG_STABILITY*/
#ifdef OPLUS_BUG_STABILITY
#Tian.Pan@ANDROID.STABILITY.3054721.2020/09/21.add for fix debug system_server register too many receivers issue.
    "binderthreadfullcapture")
        binderthreadfullcapture
        ;;
#endif /*OPLUS_BUG_STABILITY*/
#ifdef OPLUS_BUG_STABILITY
#Yongqiang.Du@ANDROID.Stability.Crash.0, 2022/08/08, Add for shutdown reason recorder
    "rebootdetectcapture")
        rebootdetectcapture
        ;;
#endif /*OPLUS_BUG_STABILITY*/
#//Chunbo.Gao@ANDROID.DEBUG.1968962, 2019/4/23, Add for qmi log
        "qmilogon")
        qmilogon
    ;;
        "qmilogoff")
        qmilogoff
    ;;
        "adspglink")
        adspglink
    ;;
        "modemglink")
        modemglink
    ;;
        "cdspglink")
        cdspglink
    ;;
        "modemqrtr")
        modemqrtr
    ;;
        "sensorqrtr")
        sensorqrtr
    ;;
        "npuqrtr")
        npuqrtr
    ;;
        "slpiqrtr")
        slpiqrtr
    ;;
        "slpiglink")
        slpiglink
    ;;
#ifdef OPLUS_FEATURE_SSLOG_CATCH
#ZhangWankang@NETWORK.POWER 2020/04/02,add for catch ss log
        "logcatSsLog")
        logcatSsLog
    ;;
#endif

#ifdef OPLUS_FEATURE_WIFI_LOG
#YangQing@OPLUS_FEATURE_WIFI_LOG, 2022/05/13 , add for collect wifi log
        "captureTcpdumpLog")
        captureTcpdumpLog
    ;;
#ZouLang@OPLUS_FEATURE_WIFI_LOG, 2024/08/15 , add for manual start capture tcpudump
        "manualCaptureTcpdumpLog")
        initLogSizeAndNums
        manualCaptureTcpdumpLog
    ;;
#endif /* OPLUS_FEATURE_WIFI_LOG */

        "cameraloginit")
        cameraloginit
    ;;
        "oidtlogs")
        oidtlogs
    ;;
#Fuchun.Liao@BSP.CHG.Basic 2019/06/09 modify for black/bright check
	"create_black_bright_check_file")
        create_black_bright_check_file
    ;;
#ifdef OPLUS_FEATURE_MEMLEAK_DETECT
#Hailong.Liu@ANDROID.MM, 2020/03/18, add for capture native malloc leak on aging_monkey test
    "storeSvelteLog")
        storeSvelteLog
    ;;
#endif /* PLUS_FEATURE_MEMLEAK_DETECT */
    "backup_minidumplog")
        backupMinidump
    ;;
    "chmoddcsenpath")
        chmodDcsEnPath
    ;;
    "oplus_compact_memory")
        oplus_compact_memory
    ;;
#ifdef OPLUS_BUG_STABILITY
#Daibo.Le@ANDROID.STABILITY, 2023/06/30, add for BBDS collecting binder log
    "binder_infos_capture")
        binder_infos_capture
        ;;
#endif /*OPLUS_BUG_STABILITY*/
#Zhurui2@ANDROID.STABILITY, 2025/05/02, add for Smart trace dump
    "binder_smart_trace_capture")
        binder_smart_trace_capture
        ;;
#ifdef OPLUS_ANR_LOG_ENHANCEMENT_HELPER
#Jason.Yu@ANDROID.STABILITY, 2023/12/11, add for Anr Log Enhancement
    "catch_nfw_info")
        catch_nfw_info
        ;;
#endif /* OPLUS_ANR_LOG_ENHANCEMENT_HELPER */
       *)

      ;;
esac
