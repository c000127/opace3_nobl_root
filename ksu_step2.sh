#!/system/bin/sh
# Step 2: Unload modules and insmod KernelSU
# IMPORTANT: This script will exit immediately after insmod because
# KernelSU will revoke the current shell's root privileges.

echo "=========================================================="
echo " KernelSU 加载 Step 2 (仅 insmod) 开始执行..."

# === 卸载 OPLUS 安全模块 ===
echo ""
echo "=== 卸载 OPLUS 安全模块 ==="
rmmod oplus_security_guard 2>/dev/null && echo "已卸载 oplus_security_guard" || echo "oplus_security_guard 不存在或已卸载"
#rmmod oplus_secure_harden 2>/dev/null && echo "已卸载 oplus_secure_harden" || echo "oplus_secure_harden 不存在或已卸载"
#rmmod oplus_security_keventupload 2>/dev/null && echo "已卸载 oplus_security_keventupload" || echo "oplus_security_keventupload 不存在或已卸载"

# SELinux 设为宽容模式
setenforce 0
echo "SELinux: $(getenforce)"
echo ""

# 关闭KernelSU
am force-stop me.weishu.kernelsu 2>/dev/null

# === ksud debug insmod ===
echo "=== 加载内核模块 (ksud debug) ==="
if grep -q "kernelsu" /proc/modules 2>/dev/null; then
    echo "已加载，跳过"
else
    chmod 644 /data/local/tmp/kernelsu.ko 2>/dev/null
    chmod +x /data/local/tmp/ksud-aarch64 2>/dev/null
    
    echo "正在执行寻址装载..."
    /data/local/tmp/ksud-aarch64 debug insmod /data/local/tmp/kernelsu.ko
    RET=$?
    echo "装载返回码: $RET"
    if [ $RET -ne 0 ]; then
        echo "LOAD_FAILED"
        dmesg | tail -10
        exit 1
    fi
fi

echo "=========================================================="
echo " [!] 致命提醒: KernelSU 已加载，当前 Shell 已被降权！"
echo " [1] 请打开手机上的 KernelSU 管理器 App"
echo " [2] 进入超级用户列表，找到 Shell(2000) 并赋予 Root 权限"
echo " [3] 完成后，在电脑端按任意键重连 ADB 并继续剩下的部署"
echo "=========================================================="
