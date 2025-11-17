config="$1"

function remove_driver() {
    echo `rmmod kiwi_v2`
}

case "$config" in
    "remove_driver")
    cmd=$(remove_driver)
    ;;
esac
echo "$cmd"
