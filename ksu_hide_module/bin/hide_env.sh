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

# === 等待系统即将启动完成（但还没完成）===
# -w 会阻塞直到属性值匹配，确保在检测 APP 启动前完成修改
resetprop -w sys.boot_completed 0

# === 恢复内核安全设置 ===
echo 2 > /proc/sys/kernel/kptr_restrict

# === 恢复 OPLUS 安全模块 ===
modprobe oplus_secure_harden 2>/dev/null
modprobe oplus_security_guard 2>/dev/null
modprobe oplus_security_keventupload 2>/dev/null
start riskdetect 2>/dev/null
start oplus_kevents 2>/dev/null
start bsp_kevent 2>/dev/null
start qsguard 2>/dev/null

# === 隐藏 Root 属性 ===
# Verified Boot 相关
check_reset_prop "ro.boot.verifiedbootstate" "green"
check_reset_prop "ro.boot.vbmeta.device_state" "locked"
check_reset_prop "ro.boot.flash.locked" "1"
check_reset_prop "ro.boot.veritymode" "enforcing"
check_reset_prop "ro.boot.selinux" "enforcing"
check_reset_prop "ro.build.selinux" "1"

# Warranty / OEM Unlock
check_reset_prop "ro.boot.warranty_bit" "0"
check_reset_prop "ro.warranty_bit" "0"
check_reset_prop "ro.vendor.boot.warranty_bit" "0"
check_reset_prop "ro.vendor.warranty_bit" "0"
check_reset_prop "ro.oem_unlock_supported" "0"
check_reset_prop "sys.oem_unlock_allowed" "0"

# Build 相关
check_reset_prop "ro.secure" "1"
check_reset_prop "ro.build.type" "user"
check_reset_prop "ro.build.tags" "release-keys"
check_reset_prop "ro.crypto.state" "encrypted"

# ADB / Debug 相关
check_reset_prop "ro.debuggable" "0"
check_reset_prop "ro.force.debuggable" "0"
check_reset_prop "ro.adb.secure" "1"
check_reset_prop "persist.sys.root_access" "0"
check_reset_prop "service.adb.root" "0"
check_reset_prop "ro.config.low_ram" "false"

# Vendor Boot
check_reset_prop "vendor.boot.vbmeta.device_state" "locked"
check_reset_prop "vendor.boot.verifiedbootstate" "green"

# === SELinux 强制模式 ===
STATUS=$(getenforce)
if [ "$STATUS" = "Permissive" ]; then
  setenforce 1
fi

# === 等待系统启动完成 ===
resetprop -w sys.boot_completed 1
