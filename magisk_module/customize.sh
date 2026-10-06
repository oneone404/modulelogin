SKIPUNZIP=0

ui_print "**********************************************"
ui_print "*                   One One                  *"
ui_print "**********************************************"
ui_print "- Installing One One..."

# Phan quyen thuc thi
set_perm_recursive "$MODPATH" 0 0 0755 0644
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/system/bin/app.sh" 0 0 0755
set_perm "$MODPATH/system/bin/oneone_finder_v2" 0 0 0755
cp -f "$MODPATH/system/bin/oneone_finder_v2" /data/local/tmp/oneone_finder_v2 2>/dev/null
chmod 755 /data/local/tmp/oneone_finder_v2 2>/dev/null

# Tao thu muc va chep san anh mau vao /sdcard/oneone/images/
mkdir -p /sdcard/oneone/images
if [ -d "$MODPATH/images" ]; then
    cp -f "$MODPATH/images/"* /sdcard/oneone/images/ 2>/dev/null
fi

# Xoa file config.txt cu; tat ca LDPlayer doc chung config.json
rm -f /sdcard/oneone/config.txt 2>/dev/null

# Dong bo ngay lap tuc sang /data/adb/modules/oneone de khong can phai doi reboot
TARGET_DIR="/data/adb/modules/oneone"
rm -rf "$TARGET_DIR" 2>/dev/null
mkdir -p "$TARGET_DIR" 2>/dev/null
cp -rf "$MODPATH"/* "$TARGET_DIR"/ 2>/dev/null
chmod -R 755 "$TARGET_DIR" 2>/dev/null

ui_print " "
ui_print "[SUCCESS] Module One One installed successfully!"
ui_print "[CONFIG] Doc chung: Documents\\Tools\\config.json"
ui_print "[LOG] File log: /sdcard/oneone/log.log"
ui_print "[IMAGES] Thu muc anh: /sdcard/oneone/images/"
ui_print "[REBOOT] Vui long khoi dong lai LDPlayer de kich hoat!"
