#!/system/bin/sh
# Step 2: insmod + ksud + trigger Manager
KSU_DIR="/data/adb/ksu"

echo "========================================"
echo " KernelSU 加载 Step 2"
echo "========================================"

# === 卸载 OPLUS 安全模块 (防止 ksud 被内核杀死) ===
echo ""
echo "=== 卸载 OPLUS 安全模块 ==="
rmmod oplus_security_guard 2>/dev/null && echo "已卸载 oplus_security_guard" || echo "oplus_security_guard 不存在或已卸载"
#rmmod oplus_secure_harden 2>/dev/null && echo "已卸载 oplus_secure_harden" || echo "oplus_secure_harden 不存在或已卸载"
#rmmod oplus_security_keventupload 2>/dev/null && echo "已卸载 oplus_security_keventupload" || echo "oplus_security_keventupload 不存在或已卸载"

# 停止用户空间安全服务
#stop riskdetect 2>/dev/null
#stop oplus_kevents 2>/dev/null
#stop bsp_kevent 2>/dev/null
#stop qsguard 2>/dev/null
#echo "安全服务已停止"

# SELinux 设为宽容模式
setenforce 0
echo "SELinux: $(getenforce)"
echo ""

# === insmod ===
echo "=== 加载内核模块 ==="
if grep -q "kernelsu" /proc/modules 2>/dev/null; then
    echo "已加载，跳过"
else
    chmod 644 /data/local/tmp/kernelsu_patched.ko 2>/dev/null
    insmod /data/local/tmp/kernelsu_patched.ko
    RET=$?
    echo "insmod 返回码: $RET"
    if [ $RET -ne 0 ]; then
        echo "LOAD_FAILED"
        dmesg | grep -i "kernelsu\|Unknown symbol" | tail -10
        exit 1
    fi
fi
grep "kernelsu" /proc/modules
echo ""

# === ksud ===
echo "=== 部署 ksud ==="
mkdir -p "$KSU_DIR/bin" "$KSU_DIR/log" "$KSU_DIR/modules"

# 直接拷贝 ksud (不使用符号链接)
if [ -f /data/local/tmp/ksud-aarch64 ]; then
    cp /data/local/tmp/ksud-aarch64 "$KSU_DIR/bin/ksud"
    chmod 755 "$KSU_DIR/bin/ksud"
    cp /data/local/tmp/ksud-aarch64 /data/adb/ksud
    chmod 755 /data/adb/ksud
fi
chown -R 0:1000 "$KSU_DIR" 2>/dev/null
echo "ksud 就绪: $($KSU_DIR/bin/ksud -V 2>&1)"
echo ""

# === ksud 启动阶段 ===
echo "=== 执行启动阶段 ==="
"$KSU_DIR/bin/ksud" post-fs-data 2>&1

# 修复: 删除 KSU 自己创建的 magisk 兼容符号链接
if [ -L "$KSU_DIR/bin/magisk" ]; then
    rm -f "$KSU_DIR/bin/magisk"
    echo "已移除 magisk 兼容链接 (防止误检测)"
fi

"$KSU_DIR/bin/ksud" services 2>&1
"$KSU_DIR/bin/ksud" boot-completed 2>&1
echo "启动阶段完成"
echo ""

# === 安装 KSU 隐藏模块（覆盖安装整个目录）===
echo "=== 安装隐藏 Root 环境模块 ==="
MODULE_DIR="/data/adb/modules/ace3_hide_environment"
if [ -d /data/local/tmp/ksu_hide_module ]; then
    rm -rf "$MODULE_DIR"
    mkdir -p "$MODULE_DIR"
    cp -r /data/local/tmp/ksu_hide_module/* "$MODULE_DIR/"
    # chmod 755 "$MODULE_DIR/service.sh"
    chmod 755 "$MODULE_DIR/action.sh" 2>/dev/null
    chmod -R 755 "$MODULE_DIR/bin" 2>/dev/null
    echo "[OK] 隐藏模块已安装到 $MODULE_DIR"
else
    echo "[!] 模块目录未找到，跳过安装"
fi



# === 状态 ===
echo "=== 最终状态 ==="
if grep -q "kernelsu" /proc/modules 2>/dev/null; then
    echo "[OK] 内核模块已加载"
else
    echo "[NO] 内核模块未加载"
fi

"$KSU_DIR/bin/ksud" -V 2>&1

# 检查 Manager 是否被 crown
echo ""
echo "=== Manager 检测 ==="
dmesg | grep -i "crowning\|manager pkg\|is_manager: 1" | tail -5
if dmesg | grep -q "Crowning manager"; then
    echo "[OK] Manager 已被内核识别"
else
    echo "[!] Manager 未被内核识别"
fi

echo ""
echo "=== 最近 KernelSU 日志 ==="
dmesg | grep -i "KernelSU" | tail -10
echo ""

# === 恢复 OPLUS 安全模块===
#echo ""
#echo "=== 恢复 OPLUS 安全模块 ==="
#modprobe oplus_secure_harden 2>/dev/null
#modprobe oplus_security_guard 2>/dev/null
#modprobe oplus_security_keventupload 2>/dev/null
#start riskdetect
#start oplus_kevents
#start bsp_kevent
#start qsguard
#echo "OPLUS安全模块已恢复"

# 恢复内核安全设置
echo 2 > /proc/sys/kernel/kptr_restrict

# 隐藏 ro.boot.selinux
RESETPROP="/data/adb/ksu/bin/resetprop"
CURRENT=$($RESETPROP "ro.boot.selinux" 2>/dev/null)
if [ -n "$CURRENT" ] && [ "$CURRENT" != "enforcing" ]; then
    $RESETPROP -n "ro.boot.selinux" "enforcing"
    echo "[OK] ro.boot.selinux -> enforcing"
fi

# 实验性：尝试解决prop area hole
restorecon /dev/__properties__/u:object_r:userdebug_or_eng_prop:s0 2>/dev/null

rm -f /data/local/tmp/kallsyms.txt
rm -f /data/local/tmp/kernelsu_patched.ko
rm -f /data/local/tmp/ksud-aarch64
rm -f /data/local/tmp/ksu_step1.sh
rm -rf /data/local/tmp/ksu_hide_module
# 注意：不删除 ksu_step2.sh 自身（正在执行中）
echo "临时文件已清理"

echo "ALL_DONE"

setenforce 1
