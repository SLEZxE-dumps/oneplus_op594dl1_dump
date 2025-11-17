#!/system/bin/sh

platform_id=""
kernel_version=`uname -r`
mem_total=""
prjname=`getprop ro.boot.prjname`

function mm_configure() {
    platform_id=`cat /sys/devices/soc0/soc_id`
    mem_total_str=`cat /proc/meminfo | grep MemTotal`
    mem_total=${mem_total_str:16:8}

    if [ -z $mem_total ] || [ -z $platform_id ] || [ -z $kernel_version ]
    then
        echo -e "read meminfo failed\n"
        exit -1
    fi

    echo "$platform_id: $mem_total"
    # common configure here
    # disable watermark_boost_factor
    echo 0 > /proc/sys/vm/watermark_boost_factor

    # common configuration
    # in kernel_verion <= 5.10, watermark_scale_factor is set here
    # in kernel_verion >= 5.15, it's controlled by property persist.sys.oplus.wmark_extra_free_kbytes_${MEM_TOTAL_GB}g
    if [[ "$kernel_version" == "4."* || "$kernel_version" == "5.4"* || "$kernel_version" == "5.10"* ]]; then
        if [ $mem_total -le 8388608 ]; then
            echo 25 > /proc/sys/vm/watermark_scale_factor
        else
            echo 16 > /proc/sys/vm/watermark_scale_factor
        fi
    fi

    # special configuration by soc
    case "$platform_id" in
        "518") # SM6225
            if [ $mem_total -le 8388608 ]; then
                echo 32 > /proc/sys/vm/watermark_scale_factor
            else
                echo 16 > /proc/sys/vm/watermark_scale_factor
            fi
            ;;
        "454" |"507") # SM4350 ,SM6375
            echo 15000 > /proc/sys/vm/watermark_boost_factor
            ;;
    esac

    # special configuration by project
    case $prjname in
        "21695")
            echo 32 > /proc/sys/vm/watermark_scale_factor
            ;;
        "21707"|"21708"|"216EA"|"2162B"|"22667"|"22668"|"22602"|"23071"|"23881"|"23091")
            echo 0 > /proc/sys/vm/watermark_boost_factor
            ;;
        "23271"|"23273"|"23274")
            echo 60 > /proc/sys/vm/watermark_scale_factor
            ;;
        "23926"|"23927"|"23976"|"23978")
            if [ $mem_total -le 8388608 ]; then
                echo 25 > /proc/sys/vm/watermark_scale_factor
            else
                echo 16 > /proc/sys/vm/watermark_scale_factor
            fi
            ;;
    esac
}

mm_configure
