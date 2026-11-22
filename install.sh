#!/system/bin/sh
# =====================================================================
#  TIT-AL00 (Huawei Enjoy 5 / MT6735) - mobile data fix installer
#  Run as root on the device:
#     adb shell su -c "sh /sdcard/TIT-AL00-DataFix/install.sh"
#  or from a root shell:
#     sh /sdcard/TIT-AL00-DataFix/install.sh
# =====================================================================
SRC=$(dirname "$0")
MODDIR=/data/adb/modules
FW=/system/etc/firmware

echo "=== TIT-AL00 data fix installer ==="

# --- sanity checks -------------------------------------------------
[ "$(id -u)" = "0" ] || { echo "!! must run as root"; exit 1; }
[ -d /data/adb ] || { echo "!! Magisk not detected (/data/adb missing)"; exit 1; }

if [ ! -f "$SRC/modules/fwpatch/system/framework/telephony-common.jar" ]; then
  echo "!! package incomplete: telephony-common.jar not found next to install.sh"
  exit 1
fi

# --- 1. modem firmware overlay -------------------------------------
# The kernel of some builds loads modem_1_lwg_1.img which is signed for
# another project (TIT-L01). Loading it makes the MD assert -> baseband
# version "unknown" and SIM not ready. Overlay the correct AL00 image.
echo "--- [1/3] modem firmware overlay"
mkdir -p "$MODDIR/modem_al00/system/etc/firmware"
if [ -f "$FW/modem_1_lwg_n.img" ]; then
  cp -f "$FW/modem_1_lwg_n.img" "$MODDIR/modem_al00/system/etc/firmware/modem_1_lwg_1.img"
  cp -f "$SRC/modules/modem_al00/module.prop" "$MODDIR/modem_al00/module.prop"
  echo "    modem_1_lwg_n.img -> modem_1_lwg_1.img (overlay)"
else
  echo "    !! $FW/modem_1_lwg_n.img not found, skipping"
fi

# --- 2. telephony framework patch ----------------------------------
echo "--- [2/3] telephony framework patch"
mkdir -p "$MODDIR/fwpatch/system/framework"
cp -f "$SRC/modules/fwpatch/system/framework/telephony-common.jar" \
      "$MODDIR/fwpatch/system/framework/telephony-common.jar"
cp -f "$SRC/modules/fwpatch/module.prop" "$MODDIR/fwpatch/module.prop"
chmod 0644 "$MODDIR/fwpatch/system/framework/telephony-common.jar"
echo "    telephony-common.jar installed"

# --- 3. helper scripts ---------------------------------------------
echo "--- [3/3] helper scripts"
cp -f "$SRC/scripts/fixdata.sh" /data/local/tmp/fixdata.sh
chmod 0755 /data/local/tmp/fixdata.sh
echo "    /data/local/tmp/fixdata.sh  (run this if data stops working)"

# Optional boot hook: resets the modem ~30s after boot so the data path
# gets un-stuck. NOTE: on some units this reset also interrupts SIM
# detection; if your SIM disappears after boot, remove it.
if [ "$1" = "--with-boot-hook" ]; then
  mkdir -p /data/adb/service.d
  cp -f "$SRC/scripts/99datapath.sh" /data/adb/service.d/99datapath.sh
  chmod 0755 /data/adb/service.d/99datapath.sh
  echo "    boot hook installed (--with-boot-hook)"
fi

chmod -R 0755 "$MODDIR/modem_al00" "$MODDIR/fwpatch" 2>/dev/null

echo
echo "=== done. reboot to apply:  reboot ==="
echo "If mobile data does not come up after boot, run:"
echo "    su -c 'sh /data/local/tmp/fixdata.sh'"
