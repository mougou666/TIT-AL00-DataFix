#!/system/bin/sh
# boot hook: restore mobile data path
(
  sleep 30
  sh /data/local/tmp/fixdata.sh
) &
exit 0
