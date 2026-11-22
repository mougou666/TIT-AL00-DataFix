#!/system/bin/sh
# fixdata.sh - restore mobile data path (robust)
LOG=/data/local/tmp/fixdata.log
echo "=== $(date) start" > $LOG
until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 2; done
trap 'start ril-daemon-mtk 2>/dev/null' EXIT
echo "boot ok" >> $LOG
i=0
while [ $i -lt 60 ]; do
  [ "$(getprop gsm.sim.state)" = "READY" ] && break
  sleep 2; i=$((i+1))
done
echo "sim=$(getprop gsm.sim.state)" >> $LOG
sleep 8
stop ril-daemon-mtk
sleep 2
stop ccci_mdinit
sleep 3
start ccci_mdinit
sleep 12
start ril-daemon-mtk
echo "modem reset done" >> $LOG
i=0
while [ $i -lt 60 ]; do
  op=$(getprop gsm.operator.numeric)
  [ -n "$op" ] && break
  sleep 2; i=$((i+1))
done
echo "op=$op" >> $LOG
sleep 20
ip -4 addr show ccmni0 2>/dev/null | grep inet >> $LOG
echo "=== done" >> $LOG

