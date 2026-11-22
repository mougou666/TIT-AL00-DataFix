#!/system/bin/sh
# Wait for the system to finish booting, then restart the RIL once so the
# framework re-connects cleanly to the modem (avoids the boot-time race that
# leaves radio power cycling).
i=0
while [ "$(getprop sys.boot_completed)" != "1" ] && [ $i -lt 90 ]; do
  sleep 2
  i=$((i+1))
done
sleep 20
stop ril-daemon-mtk
sleep 2
start ril-daemon-mtk
