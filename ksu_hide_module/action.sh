#!/system/bin/sh
chmod +x /data/adb/modules/ace3_hide_environment/bin/ksu_reload.sh /data/adb/modules/ace3_hide_environment/bin/hide_env.sh /data/adb/modules/ace3_hide_environment/bin/fix_lspd.sh

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "— 请选择操作："
echo "— [ 音量 加(+): 重载模块 ]"
    echo "— [ 音量 减(-): 修复 LSPosed ]"
    echo "— [ 8秒内未执行操作自动退出 ]"
    
START_TIME=$(date +%s)
while true; do
  NOW_TIME=$(date +%s)
  timeout 1 getevent -lc 1 2>&1 | grep KEY_VOLUME > "$TMPDIR/events"

  if [ $(( NOW_TIME - START_TIME )) -gt 8 ]; then
    ui_print "— 超时未执行功能，结束运行"
    /data/adb/modules/ace3_hide_environment/bin/hide_env.sh
    break
  elif grep -q KEY_VOLUMEUP "$TMPDIR/events"; then
    ui_print "— 检测到音量加键 → 重载模块"
    /data/adb/modules/ace3_hide_environment/bin/ksu_reload.sh
    break
  elif grep -q KEY_VOLUMEDOWN "$TMPDIR/events"; then
    ui_print "— 检测到音量减键 → 修复 LSPosed"
     /data/adb/modules/ace3_hide_environment/bin/fix_lspd.sh    
    break
  fi
done