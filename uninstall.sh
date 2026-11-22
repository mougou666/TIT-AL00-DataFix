#!/system/bin/sh
# Remove all TIT-AL00 data-fix components and restore stock behaviour.
# Run as root on the device:
#    adb shell su -c "sh /sdcard/TIT-AL00-DataFix/uninstall.sh"
echo "=== removing TIT-AL00 data fix ==="
rm -rf /data/adb/modules/modem_al00
rm -rf /data/adb/modules/fwpatch
rm -f  /data/adb/service.d/99datapath.sh
rm -f  /data/adb/service.d/99rilfix.sh
rm -f  /data/local/tmp/fixdata.sh
echo "=== done. reboot to restore stock behaviour ==="
