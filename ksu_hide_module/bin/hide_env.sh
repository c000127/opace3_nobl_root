#!/system/bin/sh
# KSU 隐藏 Root 环境模块 - service.sh
# 在 boot_completed 之前修改属性，让检测 APP 无法观察到变化
MODDIR=${0%/*}

check_reset_prop() {
  local NAME=$1
  local EXPECTED=$2
  local VALUE=$(resetprop $NAME)
  [ -z "$VALUE" ] || [ "$VALUE" = "$EXPECTED" ] || resetprop -n $NAME $EXPECTED
}

# 实验性：尝试解决prop area hole
restorecon /dev/__properties__/u:object_r:userdebug_or_eng_prop:s0 2>/dev/null

# === 等待系统即将启动完成（但还没完成）===
# -w 会阻塞直到属性值匹配，确保在检测 APP 启动前完成修改
resetprop -w sys.boot_completed 0

# === 恢复内核安全设置 ===
echo 2 > /proc/sys/kernel/kptr_restrict

# === 恢复 OPLUS 安全模块 ===
#modprobe oplus_secure_harden 2>/dev/null
#modprobe oplus_security_guard 2>/dev/null
#modprobe oplus_security_keventupload 2>/dev/null
#start riskdetect 2>/dev/null
#start oplus_kevents 2>/dev/null
#start bsp_kevent 2>/dev/null
#start qsguard 2>/dev/null

# === 隐藏 Root 属性 ===
# Verified Boot 相关
hide_prop "ro.boot.selinux" "enforcing"

# === SELinux 强制模式 ===
STATUS=$(getenforce)
if [ "$STATUS" = "Permissive" ]; then
  setenforce 1
fi

# === 等待系统启动完成 ===
resetprop -w sys.boot_completed 1