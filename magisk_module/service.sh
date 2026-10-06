#!/system/bin/sh
MODDIR=${0%/*}
[ -z "$MODDIR" ] || [ "$MODDIR" = "$0" ] && MODDIR="/data/adb/modules/oneone"

# Cho he thong Android khoi dong hoan tat
while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 2
done

# Doi them 5 giay de cac tien trinh LDPlayer on dinh
sleep 5

# Tim file app.sh o moi vi tri co the
SCRIPT_PATH=""
if [ -f "$MODDIR/system/bin/app.sh" ]; then
    SCRIPT_PATH="$MODDIR/system/bin/app.sh"
elif [ -f "/system/bin/app.sh" ]; then
    SCRIPT_PATH="/system/bin/app.sh"
elif [ -f "/data/local/tmp/app.sh" ]; then
    SCRIPT_PATH="/data/local/tmp/app.sh"
elif [ -f "$MODDIR/system\\bin\\app.sh" ]; then
    SCRIPT_PATH="$MODDIR/system\\bin\\app.sh"
fi

mkdir -p /sdcard/oneone 2>/dev/null
echo "[$(date '+%Y-%m-%d %H:%M:%S')] [BOOT] service.sh khoi dong thanh cong (Script: $SCRIPT_PATH)" >> /sdcard/oneone/log.log 2>/dev/null

if [ -n "$SCRIPT_PATH" ]; then
    chmod 755 "$SCRIPT_PATH"
    sh "$SCRIPT_PATH" </dev/null >>/sdcard/oneone/log.log 2>&1 &
fi
