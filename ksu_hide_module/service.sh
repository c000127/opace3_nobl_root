#!/system/bin/sh
# 一加Ace3 隐藏 Root 环境模块 - service.sh
# 在 boot_completed 之前修改属性，让检测 APP 无法观察到变化
MODDIR=${0%/*}

hide_prop() {
  local NAME=$1
  local EXPECTED=$2
  local CURRENT=$(resetprop "$NAME" 2>/dev/null)
  # 仅在属性存在且值不同时才修改，减少痕迹
  if [ -n "$CURRENT" ] && [ "$CURRENT" != "$EXPECTED" ]; then
    resetprop -n "$NAME" "$EXPECTED"
  fi
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
# 仅修改实际需要改的属性，不存在的属性不要碰（hide_prop 会自动跳过空值）
#
# 实测 DIFF 结果：仅 ro.boot.selinux 和 ro.oem_unlock_supported 需要修改
# ro.oem_unlock_supported=1 是出厂值，改成 0 反而多一个修改痕迹，所以不改
#
# 以下属性在原始状态下已经是正确值，不需要修改：
#   ro.boot.verifiedbootstate=green  ro.boot.vbmeta.device_state=locked
#   ro.boot.flash.locked=1  ro.boot.veritymode=enforcing
#   ro.secure=1  ro.debuggable=0  ro.build.type=user
#   ro.build.tags=release-keys  ro.crypto.state=encrypted
#   ro.adb.secure=1  ro.force.debuggable=0
#
# 以下属性在设备上不存在（空值），hide_prop 会自动跳过：
#   ro.build.selinux  ro.boot.warranty_bit  ro.warranty_bit
#   ro.vendor.boot.warranty_bit  ro.vendor.warranty_bit
#   sys.oem_unlock_allowed  persist.sys.root_access  service.adb.root
#   ro.config.low_ram  vendor.boot.vbmeta.device_state
#   vendor.boot.verifiedbootstate

# 唯一必须修改的属性：SELinux 状态（来自 cmdline androidboot.selinux=permissive）
hide_prop "ro.boot.selinux" "enforcing"

# === SELinux 强制模式 ===
STATUS=$(getenforce)
if [ "$STATUS" = "Permissive" ]; then
  setenforce 1
fi

# === 等待系统启动完成 ===
resetprop -w sys.boot_completed 1
