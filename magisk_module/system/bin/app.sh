#!/system/bin/sh
# =================================================================
# One One
# =================================================================

CONFIG_DIR="/sdcard/oneone"
LOG_FILE="$CONFIG_DIR/log.log"
IMAGES_DIR="$CONFIG_DIR/images"
rm -f "$CONFIG_DIR/watchdog.log" 2>/dev/null
rm -f "$CONFIG_DIR/config.txt" 2>/dev/null

IMG_OK="$IMAGES_DIR/nut_ok.png"
IMG_BALO="$IMAGES_DIR/nut_balo.png"
IMG_VOT="$IMAGES_DIR/chua_cam_vot.png"

# Nguong nhan dien rieng biet cho tung template anh
TH_OK="0.95"
TH_BALO="0.94"
TH_VOT="0.90"

SCRIPT_BIN_DIR=${0%/*}
FINDER_V2="/system/bin/oneone_finder_v2"
if [ ! -x "$FINDER_V2" ]; then
    if [ -f "$SCRIPT_BIN_DIR/oneone_finder_v2" ]; then
        cp -f "$SCRIPT_BIN_DIR/oneone_finder_v2" /data/local/tmp/oneone_finder_v2 2>/dev/null
        chmod 755 /data/local/tmp/oneone_finder_v2 2>/dev/null
    fi
    FINDER_V2="/data/local/tmp/oneone_finder_v2"
fi
mkdir -p "$CONFIG_DIR" 2>/dev/null
mkdir -p "$IMAGES_DIR" 2>/dev/null

ENABLE_LOG=0
LOG_WRITES=0
MAX_LOG_SIZE=524288

# Xac dinh ten LDPlayer hien tai
MY_LD_NAME=""
if [ -f "$CONFIG_DIR/ld_name" ]; then
    MY_LD_NAME=$(cat "$CONFIG_DIR/ld_name" 2>/dev/null | tr -d '\r\n[:space:]')
fi
if [ -z "$MY_LD_NAME" ]; then
    TAB_IDX=1
    [ -f "$CONFIG_DIR/tab_index" ] && TAB_IDX=$(cat "$CONFIG_DIR/tab_index" 2>/dev/null | tr -d '\r\n[:space:]')
    [ -z "$TAB_IDX" ] && TAB_IDX=1
    MY_LD_NAME="LD-$TAB_IDX"
fi

log_msg() {
    [ "$ENABLE_LOG" != "1" ] && [ "$ENABLE_LOG" != "true" ] && [ "$ENABLE_LOG" != "on" ] && return 0
    LOG_WRITES=$((LOG_WRITES + 1))
    if [ "$LOG_WRITES" -ge 50 ]; then
        LOG_WRITES=0
        LOG_SIZE=$(stat -c %s "$LOG_FILE" 2>/dev/null || echo 0)
        if [ "$LOG_SIZE" -ge "$MAX_LOG_SIZE" ]; then
            mv -f "$LOG_FILE" "$LOG_FILE.1" 2>/dev/null
        fi
    fi
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$TIMESTAMP] $1" >> "$LOG_FILE" 2>/dev/null
}

perform_login() {
    if [ "$AUTO_LOGIN" != "1" ] && [ "$AUTO_LOGIN" != "true" ] && [ "$AUTO_LOGIN" != "on" ]; then
        log_msg "[LOGIN] AUTO_LOGIN dang tat (AUTO_LOGIN=$AUTO_LOGIN). Bo qua dang nhap!"
        return 0
    fi

    log_msg "[LOGIN] Phat hien man hinh dang nhap! Dang lay thong tin tai khoan..."
    
    # 1. Tim file Acc.csv
    ACC_FILE=""
    for p in "/mnt/shared/Pictures/Tools/Acc.csv" \
             "/sdcard/Pictures/Tools/Acc.csv" \
             "/mnt/shared/Misc/Tools/Acc.csv" \
             "/sdcard/Pictures/Acc.csv" \
             "/sdcard/oneone/Acc.csv"; do
        if [ -f "$p" ]; then
            ACC_FILE="$p"
            break
        fi
    done

    if [ -z "$ACC_FILE" ]; then
        log_msg "[ERROR] Khong tim thay file Acc.csv de dang nhap!"
        return 1
    fi

    # 2. Xac dinh ten LDPlayer
    MY_LD_NAME=""
    if [ -f "$CONFIG_DIR/ld_name" ]; then
        MY_LD_NAME=$(cat "$CONFIG_DIR/ld_name" 2>/dev/null | tr -d '\r\n[:space:]')
    fi
    if [ -z "$MY_LD_NAME" ]; then
        TAB_IDX=1
        [ -f "$CONFIG_DIR/tab_index" ] && TAB_IDX=$(cat "$CONFIG_DIR/tab_index" 2>/dev/null | tr -d '\r\n[:space:]')
        [ -z "$TAB_IDX" ] && TAB_IDX=1
        MY_LD_NAME="LD-$TAB_IDX"
    fi

    log_msg "[LOGIN] May ao hien tai: '$MY_LD_NAME'. Dang tim tai khoan trong Acc.csv..."

    # Khoa file de tranh nhieu tab ghi de cung luc
    LOCK_DIR="$(dirname "$ACC_FILE")/.acc_lock"
    local lk_count=0
    LOCK_ACQUIRED=0
    while ! mkdir "$LOCK_DIR" 2>/dev/null; do
        sleep 0.1
        lk_count=$((lk_count + 1))
        if [ "$lk_count" -ge 50 ]; then
            log_msg "[WARN] Acc.csv dang duoc tab khac cap nhat. Thu lai lan sau."
            return 1
        fi
    done
    LOCK_ACQUIRED=1

    MATCHED_TK=""
    MATCHED_MK=""
    LINE_NUM=0
    FREE_LINE_NUM=0
    FREE_TK=""
    FREE_MK=""

    # Doc tung dong trong Acc.csv (dinh dang: tk|mk|ten_ld)
    while IFS= read -r line || [ -n "$line" ]; do
        clean_line=$(echo "$line" | tr -d '\r' | sed -e 's/[^[:print:]]//g')
        [ -z "$clean_line" ] && continue
        case "$clean_line" in
            \#*|\/\/*|\;*) continue ;;
        esac

        c_tk=$(echo "$clean_line" | cut -d '|' -f1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        c_mk=$(echo "$clean_line" | cut -d '|' -f2 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        c_ld=$(echo "$clean_line" | cut -d '|' -f3 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')

        [ -z "$c_tk" ] || [ -z "$c_mk" ] && continue

        LINE_NUM=$((LINE_NUM + 1))

        if [ "$c_ld" = "$MY_LD_NAME" ]; then
            MATCHED_TK="$c_tk"
            MATCHED_MK="$c_mk"
            break
        fi

        if [ -z "$c_ld" ] && [ "$FREE_LINE_NUM" -eq 0 ]; then
            FREE_LINE_NUM="$LINE_NUM"
            FREE_TK="$c_tk"
            FREE_MK="$c_mk"
        fi
    done < "$ACC_FILE"

    TK=""
    MK=""

    if [ -n "$MATCHED_TK" ]; then
        TK="$MATCHED_TK"
        MK="$MATCHED_MK"
        log_msg "[LOGIN] Tim thay tai khoan da match cho $MY_LD_NAME: $TK"
    elif [ "$FREE_LINE_NUM" -gt 0 ]; then
        TK="$FREE_TK"
        MK="$FREE_MK"
        log_msg "[LOGIN] Tim thay tai khoan free tai dong $FREE_LINE_NUM ($TK). Dang gan vao $MY_LD_NAME..."
        
        TMP_ACC="$CONFIG_DIR/acc_tmp.csv"
        CUR_LINE=0
        > "$TMP_ACC"
        while IFS= read -r line || [ -n "$line" ]; do
            clean_line=$(echo "$line" | tr -d '\r' | sed -e 's/[^[:print:]]//g')
            if [ -z "$clean_line" ]; then
                echo "" >> "$TMP_ACC"
                continue
            fi
            case "$clean_line" in
                \#*|\/\/*|\;*)
                    echo "$clean_line" >> "$TMP_ACC"
                    continue
                    ;;
            esac

            CUR_LINE=$((CUR_LINE + 1))
            if [ "$CUR_LINE" -eq "$FREE_LINE_NUM" ]; then
                echo "${FREE_TK}|${FREE_MK}|${MY_LD_NAME}" >> "$TMP_ACC"
            else
                echo "$clean_line" >> "$TMP_ACC"
            fi
        done < "$ACC_FILE"
        cp -f "$TMP_ACC" "$ACC_FILE"
        rm -f "$TMP_ACC"
        log_msg "[LOGIN] Da cap nhat Acc.csv gan $TK cho $MY_LD_NAME thanh cong!"
    else
        [ "$LOCK_ACQUIRED" -eq 1 ] && rmdir "$LOCK_DIR" 2>/dev/null
        log_msg "[ERROR] Khong tim thay tai khoan cho '$MY_LD_NAME' va khong con tai khoan free nao trong Acc.csv!"
        return 1
    fi

    [ "$LOCK_ACQUIRED" -eq 1 ] && rmdir "$LOCK_DIR" 2>/dev/null

    if [ -z "$TK" ] || [ -z "$MK" ]; then
        log_msg "[ERROR] Tai khoan hoac mat khau rong!"
        return 1
    fi

    log_msg "[LOGIN] $MY_LD_NAME bat dau dang nhap tai khoan: $TK ..."

    # 1. Nhap tai khoan (txtAccount - toa do 480 212 tren 960x540)
    input tap 480 212
    sleep 0.3
    input keyevent 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67
    input text "$TK"
    sleep 0.3

    # 2. Nhap mat khau (txtPassword - toa do 480 260 tren 960x540)
    input tap 480 260
    sleep 0.3
    input keyevent 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67
    input text "$MK"
    sleep 0.5

    # 3. An nut Dang nhap (btnLogin - toa do 480 316 tren 960x540)
    input tap 480 316
    log_msg "[SUCCESS] Da gui thong tin dang nhap cho tai khoan $TK ($MY_LD_NAME)!"
    sleep 2
    return 0
}

start_target_app() {
    PKG="$1"
    log_msg "[START] Dang mo lai app $PKG ..."
    
    LAUNCH_ACT=$(cmd package resolve-activity --brief "$PKG" 2>/dev/null | tail -n 1)
    if [ -n "$LAUNCH_ACT" ] && [ "$LAUNCH_ACT" != "No activity found" ] && [ "$LAUNCH_ACT" != "$PKG" ]; then
        am start -n "$LAUNCH_ACT" > /dev/null 2>&1
    fi

    monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 > /dev/null 2>&1
    monkey -p "$PKG" 1 > /dev/null 2>&1
}

# Ham cho va giam sat crash (tra ve 0 neu thanh cong, 1 neu bi crash)
wait_and_watch_crash() {
    DURATION="$1"
    ELAPSED=0
    
    while [ "$ELAPSED" -lt "$DURATION" ]; do
        reload_config_if_modified
        if [ "$AUTO_LOGIN" != "1" ] && [ "$AUTO_LOGIN" != "true" ] && [ "$AUTO_LOGIN" != "on" ]; then
            return 1
        fi
        PID_NOW=$(pidof "$TARGET_PKG" 2>/dev/null | cut -d ' ' -f1)
        if [ -z "$PID_NOW" ]; then
            log_msg "[ALERT] Game bi crash luc dang cho o giay thu $ELAPSED/$DURATION! Dang khoi dong lai..."
            am force-stop "$TARGET_PKG" > /dev/null 2>&1
            sleep 1
            start_target_app "$TARGET_PKG"
            return 1
        fi
        sleep 5
        ELAPSED=$((ELAPSED + 5))
    done
    return 0
}

# Chuoi hanh dong tu dong sau khi mo lai game
handle_post_restart() {
    while true; do
        reload_config_if_modified
        if [ "$AUTO_LOGIN" != "1" ] && [ "$AUTO_LOGIN" != "true" ] && [ "$AUTO_LOGIN" != "on" ]; then
            log_msg "[AUTO] AUTO_LOGIN dang tat -> Dung hanh dong!"
            return 0
        fi

        START_TIME=$(date +%s)

        # 1. Cho 30s dau tien cho game khoi dong va giam sat crash
        log_msg "[AUTO] Cho $WAIT_BEFORE_MENU giay cho game khoi dong (Giam sat crash)..."
        if ! wait_and_watch_crash "$WAIT_BEFORE_MENU"; then
            reload_config_if_modified
            if [ "$AUTO_LOGIN" != "1" ] && [ "$AUTO_LOGIN" != "true" ] && [ "$AUTO_LOGIN" != "on" ]; then
                log_msg "[AUTO] AUTO_LOGIN dang tat -> Dung hanh dong!"
                return 0
            fi
            log_msg "[AUTO] Game bi crash trong 30s dau -> RESET bat dau lai tu dau!"
            continue
        fi

        # 2. Vong lap giam sat dong bo 5s thong minh:
        # - Uu tien 1: Kiem tra Balo -> Thay Balo la da vao dao -> An Balo & Cam Vot ngay lap tuc!
        # - Uu tien 2: Kiem tra Nut Dang Nhap ZingID -> Neu o man hinh dang nhap thi click va nhap Acc
        # - Uu tien 3: Neu chua vao dao -> Quet an nut Xac Nhan, OK, Tat Menu (neu co popup)
        # - Canh bao crash lien tuc
        log_msg "[AUTO] Bat dau giam sat dong bo 5s (Nhan dien vao dao, dang nhap & xu ly popup)..."

        while true; do
            reload_config_if_modified
            if [ "$AUTO_LOGIN" != "1" ] && [ "$AUTO_LOGIN" != "true" ] && [ "$AUTO_LOGIN" != "on" ]; then
                log_msg "[AUTO] AUTO_LOGIN dang tat -> Dung hanh dong!"
                return 0
            fi

            NOW=$(date +%s)
            ELAPSED=$((NOW - START_TIME))

            # Gioi han ap dung cho moi trang thai, ke ca khi thay Balo nhung khong thay vot.
            if [ "$ELAPSED" -ge "$GAME_LOAD_TIME" ]; then
                log_msg "[TIMEOUT] Sau ${GAME_LOAD_TIME}s van chua xac nhan lay vot. Dung tu dong nhan dien va chuyen sang canh vang."
                return 1
            fi

            # 2.1. Kiem tra crash
            PID_NOW=$(pidof "$TARGET_PKG" 2>/dev/null | cut -d ' ' -f1)
            if [ -z "$PID_NOW" ]; then
                log_msg "[ALERT] Game bi crash o giay thu ${ELAPSED}s! Dang khoi dong lai..."
                am force-stop "$TARGET_PKG" > /dev/null 2>&1
                sleep 1
                start_target_app "$TARGET_PKG"
                continue 2
            fi

            # Mot screencap RAM quet toan bo chuoi nut theo thu tu uu tien.
            if [ -x "$FINDER_V2" ]; then
                RES_BATCH=$("$FINDER_V2" --batch "$IMAGES_DIR" 2>/dev/null)
                if echo "$RES_BATCH" | grep -q '^FOUND '; then
                    B_TAG=$(echo "$RES_BATCH" | awk '{print $2}')
                    B_X=$(echo "$RES_BATCH" | awk '{print $3}')
                    B_Y=$(echo "$RES_BATCH" | awk '{print $4}')
                    case "$B_TAG" in
                        BALO)
                            RAND_WAIT=$(( RANDOM % 11 + 20 ))
                            log_msg "[SUCCESS] $RES_BATCH -> Phat hien da vao dao (Giay thu ${ELAPSED}s)! Cho ${RAND_WAIT}s cho giam lag truoc khi mo Balo..."
                            if ! wait_and_watch_crash "$RAND_WAIT"; then
                                log_msg "[ALERT] Game bi crash trong luc cho giam lag -> Bat dau lai!"
                                continue 2
                            fi
                            log_msg "[AUTO] He thong da on dinh het lag! Tien hanh an Balo de cam vot..."
                            "$FINDER_V2" "$IMG_BALO" "$TH_BALO" --region 860,240,100,140 --click >/dev/null 2>&1
                            sleep "$DELAY_AFTER_BALO"
                            VOT_CHECK=0
                            while [ "$VOT_CHECK" -lt 3 ]; do
                                reload_config_if_modified
                                if [ "$AUTO_LOGIN" != "1" ] && [ "$AUTO_LOGIN" != "true" ] && [ "$AUTO_LOGIN" != "on" ]; then
                                    log_msg "[AUTO] AUTO_LOGIN dang tat -> Dung hanh dong!"
                                    return 0
                                fi
                                NOW=$(date +%s)
                                ELAPSED=$((NOW - START_TIME))
                                [ "$ELAPSED" -ge "$GAME_LOAD_TIME" ] && break
                                RES_VOT=$("$FINDER_V2" "$IMG_VOT" "$TH_VOT" --region 50,120,160,160 2>/dev/null)
                                if echo "$RES_VOT" | grep -q '^FOUND'; then
                                    "$FINDER_V2" "$IMG_VOT" "$TH_VOT" --region 50,120,160,160 --click >/dev/null 2>&1
                                    log_msg "[HOAN TAT] V2 da vao dao va xu ly trang bi vot thanh cong! Chuyen sang che do canh vang..."
                                    break 3
                                fi
                                VOT_CHECK=$((VOT_CHECK + 1))
                                log_msg "[WARN] Chua tim thay vot trong Balo (lan $VOT_CHECK/3)."
                                sleep 1
                            done
                            log_msg "[WARN] Khong tim thay vot sau 3 lan. Fallback bam tam o vot tai (130,200)."
                            input tap 130 200
                            sleep 1
                            log_msg "[HOAN TAT] Da fallback bam o vot. Chuyen sang che do canh dong ho..."
                            return 0
                            ;;
                        LOGIN)
                            input tap "$B_X" "$B_Y"
                            log_msg "[SUCCESS] $RES_BATCH -> Da an [Nut Dang Nhap (ZingID)]!"
                            sleep 2; perform_login; sleep 2; continue
                            ;;
                        CONFIRM|OK|MENU)
                            input tap "$B_X" "$B_Y"
                            log_msg "[SUCCESS] $RES_BATCH -> Da an [$B_TAG]!"
                            sleep 1; continue
                            ;;
                    esac
                elif echo "$RES_BATCH" | grep -q '^NOT_FOUND'; then
                    if [ "$ELAPSED" -ge "$GAME_LOAD_TIME" ]; then
                        log_msg "[TIMEOUT] Sau ${GAME_LOAD_TIME}s van chua xac nhan lay vot. Dung tu dong nhan dien va chuyen sang canh vang."
                        return 1
                    fi
                    sleep "$CHECK_INT"
                    continue
                fi
                log_msg "[ERROR] oneone_finder_v2 loi capture/load: $RES_BATCH"
                sleep "$CHECK_INT"
                continue
            else
                log_msg "[ERROR] Khong tim thay oneone_finder_v2 executable. Dung luong tu dong nhan dien."
                return 1
            fi
        done

        log_msg "[HOAN TAT] Da vao dao va trang bi vot thanh cong! Chuyen sang che do canh vang..."
        break
    done
}

# Ham lay van tay dong ho thoi gian (chay trong 0.05s, 0% CPU)
# Vung chuan hoa: y=180 (giua dong chu), x=835..945 (110 pixel)
# Offset trong raw dump 960x540: 16 + 180*3840 + 835*4 = 694556, do dai 440 byte
get_timer_pattern() {
    local DUMP="/data/local/tmp/sc_timer.raw"
    screencap "$DUMP" 2>/dev/null
    if [ ! -f "$DUMP" ]; then
        return 1
    fi

    od -v -A n -t u1 -j 694556 -N 440 "$DUMP" 2>/dev/null | awk '
    {
        for (i=1; i<=NF; i++) val[++count] = $i
    }
    END {
        res = ""
        for (i=1; i<=count; i+=4) {
            if (val[i] > 150 && val[i+1] > 150 && val[i+2] > 150) res = res "1"
            else res = res "_"
        }
        print res
    }'
    rm -f "$DUMP" 2>/dev/null
}

# Xoa file config.txt cu; tat ca LDPlayer doc chung config.json
rm -f "$CONFIG_DIR/config.txt" 2>/dev/null

# Thoi gian cho co dinh (Hard-coded)
WAIT_BEFORE_MENU=30
GAME_LOAD_TIME=300
DELAY_AFTER_BALO=2
BOOT_WAIT_MIN=30
BOOT_WAIT_MAX=90

# Cac gia tri mac dinh co the tuy chinh qua config.json
TARGET_PKG="com.vng.playtogether"
CHECK_INT=5

AUTO_LOGIN=0
CACHED_PID=""

log_msg "=== ONE ONE KHOI DONG ($MY_LD_NAME) ==="

# Kiem tra neu LDPlayer vua khoi dong (uptime < 150s)
UPTIME_SEC=$(awk '{print int($1)}' /proc/uptime 2>/dev/null || echo 999)
if [ "$UPTIME_SEC" -lt 150 ]; then
    MY_TAB_NUM=$(echo "$MY_LD_NAME" | tr -dc '0-9')
    [ -z "$MY_TAB_NUM" ] && MY_TAB_NUM=1
    SEED=$((RANDOM + $$ + MY_TAB_NUM * 17))
    RAND_WAIT=$((BOOT_WAIT_MIN + SEED % (BOOT_WAIT_MAX - BOOT_WAIT_MIN + 1)))
    log_msg "[BOOT] LDPlayer vua khoi dong. Cho ngau nhien $RAND_WAIT giay (${BOOT_WAIT_MIN}s-${BOOT_WAIT_MAX}s) cho may ao on dinh hoan toan..."
    sleep "$RAND_WAIT"
    log_msg "[BOOT] He thong LDPlayer da on dinh ($RAND_WAIT giay)! Bat dau kiem tra va mo game..."
fi

LAST_CFG_MTIME=""

# Ham nap cau hinh thong minh: Chi doc file khi co thay doi (Ctrl+S), 0% CPU khi chay ngam
reload_config_if_modified() {
    CFG_PATH=""
    for p in "/mnt/shared/Pictures/Tools/config.json" \
             "/sdcard/Pictures/Tools/config.json" \
             "/mnt/shared/Misc/Tools/config.json" \
             "/sdcard/Pictures/config.json" \
             "/sdcard/oneone/config.json"; do
        if [ -f "$p" ]; then
            CFG_PATH="$p"
            break
        fi
    done

    if [ -z "$CFG_PATH" ]; then
        AUTO_LOGIN=0
        LAST_CFG_MTIME=""
        return 1
    fi

    CUR_MTIME=$(stat -c %Y "$CFG_PATH" 2>/dev/null || echo 0)
    CUR_SIZE=$(stat -c %s "$CFG_PATH" 2>/dev/null || echo 0)
    CUR_SIG="$CUR_MTIME:$CUR_SIZE"
    if [ "$CUR_SIG" = "$LAST_CFG_MTIME" ] && [ -n "$LAST_CFG_MTIME" ]; then
        # File khong thay doi -> Bo qua hoan toan, giu nguyen RAM, 0% CPU, 0 I/O
        return 0
    fi

    log_msg "[CONFIG] Nap cau hinh tu $CFG_PATH (mtime: $CUR_MTIME)..."
    LAST_CFG_MTIME="$CUR_SIG"

    case "$CFG_PATH" in
        *.json)
            JSON_LINE=$(tr -d '\r\n' < "$CFG_PATH" 2>/dev/null)
            # 1. Thong so he thong chung
            NEW_PKG=$(echo "$JSON_LINE" | sed -n 's/.*"target_package"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
            [ -n "$NEW_PKG" ] && TARGET_PKG="$NEW_PKG"

            NEW_INT=$(echo "$JSON_LINE" | sed -n 's/.*"check_interval"[[:space:]]*:[[:space:]]*\([0-9][0-9]*\).*/\1/p')
            case "$NEW_INT" in
                ''|*[!0-9]*) log_msg "[WARN] check_interval khong hop le: '$NEW_INT'. Giu gia tri $CHECK_INT." ;;
                *)
                    if [ "$NEW_INT" -ge 1 ] && [ "$NEW_INT" -le 60 ]; then
                        CHECK_INT="$NEW_INT"
                    else
                        log_msg "[WARN] check_interval phai trong khoang 1-60. Giu gia tri $CHECK_INT."
                    fi
                    ;;
            esac

            NEW_LOG=$(echo "$JSON_LINE" | sed -n 's/.*"enable_log"[[:space:]]*:[[:space:]]*\(true\|false\).*/\1/p' | tr '[:upper:]' '[:lower:]')
            case "$NEW_LOG" in
                true|1|on) ENABLE_LOG=1 ;;
                *) ENABLE_LOG=0 ;;
            esac

            # 2. Trich xuat enable_bot cua tab hien tai
            TAB_BLOCK=$(echo "$JSON_LINE" | sed 's/},/}\n/g' | grep -F "\"$MY_LD_NAME\"" | head -n 1)
            if [ -n "$TAB_BLOCK" ]; then
                if echo "$TAB_BLOCK" | grep -q '"enable_bot"[[:space:]]*:[[:space:]]*true'; then
                    AUTO_LOGIN=1
                else
                    AUTO_LOGIN=0
                fi
                LAST_CFG_MTIME="$CUR_SIG"
                log_msg "[CONFIG] $MY_LD_NAME -> enable_bot: $AUTO_LOGIN | check_interval: $CHECK_INT"
            else
                AUTO_LOGIN=0
                log_msg "[WARN] Khong tim thay block cho $MY_LD_NAME trong $CFG_PATH"
            fi
            ;;
    esac
    return 0
}

# Nap cau hinh lan dau tien
reload_config_if_modified

# Kiem tra trang thai ban dau khi bot vua khoi chay
if [ "$AUTO_LOGIN" = "1" ] || [ "$AUTO_LOGIN" = "true" ] || [ "$AUTO_LOGIN" = "on" ]; then
    CACHED_PID=$(pidof "$TARGET_PKG" 2>/dev/null | cut -d ' ' -f1)
    if [ -z "$CACHED_PID" ]; then
        log_msg "[START] Game chua mo. Tien hanh khoi dong game va xu ly..."
        am force-stop "$TARGET_PKG" > /dev/null 2>&1
        sleep 1
        start_target_app "$TARGET_PKG"
        handle_post_restart
    else
        log_msg "[START] Game da chay. Bat dau xac nhan vao dao va trang bi vot..."
        handle_post_restart
    fi
fi

LAST_TIMER_PATTERN=""
TIMER_STUCK_COUNT=0
OK_STUCK_COUNT=0
LAST_OK_PRESENT=0
LAST_TIMER_CHECK=0

while true; do
    # 1. Kiem tra va nap lai cau hinh neu nguoi dung vua sua config.json
    reload_config_if_modified

    # MASTER SWITCH: Neu AUTO_LOGIN khong bat -> Bot tat tat ca hanh dong, 0% CPU!
    if [ "$AUTO_LOGIN" != "1" ] && [ "$AUTO_LOGIN" != "true" ] && [ "$AUTO_LOGIN" != "on" ]; then
        TIMER_STUCK_COUNT=0
        OK_STUCK_COUNT=0
        LAST_OK_PRESENT=0
        LAST_TIMER_PATTERN=""
        sleep "$CHECK_INT"
        continue
    fi

    # 2. Kiem tra tien trinh qua cache /proc (Sieu nhe, 0% CPU)
    APP_ALIVE=0
    if [ -n "$CACHED_PID" ] && [ -d "/proc/$CACHED_PID" ]; then
        if grep -q "$TARGET_PKG" "/proc/$CACHED_PID/cmdline" 2>/dev/null; then
            APP_ALIVE=1
        fi
    fi

    if [ "$APP_ALIVE" -eq 0 ]; then
        CACHED_PID=$(pidof "$TARGET_PKG" 2>/dev/null | cut -d ' ' -f1)
        if [ -n "$CACHED_PID" ]; then
            APP_ALIVE=1
        fi
    fi

    # 3. Neu app bi vang / tat -> Khoi dong lai va chay chuoi xu ly day du
    if [ "$APP_ALIVE" -eq 0 ]; then
        log_msg "[ALERT] App $TARGET_PKG bi vang/tat! Dang khoi dong lai..."
        am force-stop "$TARGET_PKG" > /dev/null 2>&1
        sleep 1
        start_target_app "$TARGET_PKG"
        CACHED_PID=""
        LAST_TIMER_CHECK=0
        TIMER_STUCK_COUNT=0
        OK_STUCK_COUNT=0
        LAST_OK_PRESENT=0
        LAST_TIMER_PATTERN=""
        
        handle_post_restart
        continue
    fi

    # 4. Moi 30s kiem tra dong ho dung yen va nut OK bi ket trong ROI.
    # Hai lan lien tiep (tong 60s theo nhip kiem tra) cua mot trong hai dieu kien se restart game.
    NOW_TIMER=$(date +%s)
    if [ "$LAST_TIMER_CHECK" -eq 0 ] || [ $((NOW_TIMER - LAST_TIMER_CHECK)) -ge 30 ]; then
        LAST_TIMER_CHECK="$NOW_TIMER"
        CUR_PATTERN=$(get_timer_pattern)
        RES_OK=$("$FINDER_V2" "$IMG_OK" "$TH_OK" --region 350,345,260,130 2>/dev/null)

        # Chi kiem tra neu tren man hinh co chu so cua dong ho
        if echo "$CUR_PATTERN" | grep -q "1"; then
            if [ "$CUR_PATTERN" = "$LAST_TIMER_PATTERN" ] && [ -n "$LAST_TIMER_PATTERN" ]; then
                TIMER_STUCK_COUNT=$((TIMER_STUCK_COUNT + 1))
                log_msg "[WARN] Dong ho [Da chay] dung yen lan $TIMER_STUCK_COUNT (da qua $((TIMER_STUCK_COUNT * 30))s)!"

            else
                LAST_TIMER_PATTERN="$CUR_PATTERN"
                TIMER_STUCK_COUNT=0
            fi
        else
            LAST_TIMER_PATTERN=""
            TIMER_STUCK_COUNT=0
        fi

        if echo "$RES_OK" | grep -q '^FOUND'; then
            if [ "$LAST_OK_PRESENT" -eq 1 ]; then
                OK_STUCK_COUNT=$((OK_STUCK_COUNT + 1))
                log_msg "[WARN] Nut OK van xuat hien lan $OK_STUCK_COUNT/2 (da qua $((OK_STUCK_COUNT * 30))s, score: $(echo "$RES_OK" | awk '{print $4}'))!"
            else
                LAST_OK_PRESENT=1
                OK_STUCK_COUNT=0
            fi
        else
            OK_STUCK_COUNT=0
            LAST_OK_PRESENT=0
        fi

        if [ "$TIMER_STUCK_COUNT" -ge 2 ] || [ "$OK_STUCK_COUNT" -ge 2 ]; then
            if [ "$OK_STUCK_COUNT" -ge 2 ]; then
                RESTART_REASON="Nut OK bi ket lien tuc 60s"
            else
                RESTART_REASON="Game/Auto bi do time suot 60s"
            fi
            log_msg "[ALERT] $RESTART_REASON! Dang khoi dong lai..."
            am force-stop "$TARGET_PKG" > /dev/null 2>&1
            sleep 1
            start_target_app "$TARGET_PKG"
            CACHED_PID=""
            LAST_TIMER_CHECK=0
            TIMER_STUCK_COUNT=0
            OK_STUCK_COUNT=0
            LAST_OK_PRESENT=0
            LAST_TIMER_PATTERN=""

            handle_post_restart
            continue
        fi
    fi

    sleep "$CHECK_INT"
done
