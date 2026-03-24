# 免解锁 Bootloader Root 方案

**适用设备**: OnePlus Ace 3 
**系统版本**: Android 13 / kernel 5.15  
**Root 方案**: KernelSU (LKM 运行时加载) + ZygiskSU + LSPosed  
**原理**: 利用已有的 root shell 权限，在运行时加载 KernelSU 内核模块

> ⚠️ **仅供安全研究和学习用途，后果自负。Use at your own risk!!!**

## 前提条件

1. **ADB 已连接** — USB 调试已打开，设备已授权
2. **Root Shell** — 可通过高通提权漏洞，搭配 [Magica](https://github.com/vvb2060/Magica) 获得 adb root 权限（`adb shell` 直接为 root）
3. **Windows 电脑** — 运行一键脚本（自带嵌入式 Python，无需额外安装）
4. **KernelSU Manager** — 已安装到设备（`ksu_manager.apk`）

## 文件说明

| 文件 | 用途 |
|------|------|
| `ksu_oneclick.bat` | **一键脚本** — Windows 端运行，自动完成 KernelSU 加载全流程 |
| `patch_ksu_module.py` | Python 补丁工具 — 读取运行时 kallsyms，修补 .ko 中的 KASLR 符号 |
| `android13-5.15_kernelsu.ko` | KernelSU 内核模块原件（kernel 5.15，需补丁后才能加载）|
| `ksud-aarch64-linux-android` | KernelSU 用户态守护进程 |
| `ksu_manager.apk` | KernelSU Manager App |
| `ksu_step1.sh` | 设备端脚本 — 拉取 `/proc/kallsyms` |
| `ksu_step2.sh` | 设备端脚本 — insmod + 部署 ksud + 安装隐藏模块 + 环境清理 |
| `fix_lspd.sh` | LSPosed 修复脚本 — 重注入 ZygiskSU + 启动 lspd + 重启 framework |
| `ksu_hide_module/` | **隐藏 Root 环境模块** — 开机时自动隐藏 SELinux/属性等痕迹 |
| `python/` | 嵌入式 Python 3.13（补丁脚本依赖，无需系统安装 Python）|

### 隐藏模块结构 (`ksu_hide_module/`)

```
ksu_hide_module/
├── module.prop          # 模块元数据
├── service.sh           # 开机自动执行：隐藏属性 + SELinux enforcing
├── action.sh            # KSU Manager 手动操作菜单
├── bin/
│   ├── hide_env.sh      # 环境隐藏脚本
│   ├── ksu_reload.sh    # 重载模块脚本
│   └── fix_lspd.sh      # LSPosed 修复脚本
└── META-INF/            # KSU 模块安装元数据
```

## 使用方法

### 每次开机后运行

```bat
ksu_oneclick.bat
```

自动完成以下步骤：
1. 推送所有脚本和隐藏模块到设备
2. 拉取 `/proc/kallsyms`（每次开机 KASLR 地址不同）
3. PC 端 Python 补丁 `.ko` 文件（修复 KASLR 符号地址）
4. `insmod` 加载内核模块
5. 部署 ksud、执行启动阶段（`post-fs-data → services → boot-completed`）
6. 安装隐藏模块到 `/data/adb/modules/ace3_hide_environment/`
7. 恢复 OPLUS 安全模块、SELinux enforcing
8. 清理所有临时文件

### LSPosed 修复（如显示"未加载"）

通过 root shell 执行：

```bash
adb push fix_lspd.sh /data/local/tmp/
adb shell "chmod 755 /data/local/tmp/fix_lspd.sh && sh /data/local/tmp/fix_lspd.sh"
```

## 工作原理

```
┌─ PC 端 ──────────────────────────────────────────────┐
│  ksu_oneclick.bat                                     │
│    ├─ adb push 脚本 + ksud + 隐藏模块                  │
│    ├─ ksu_step1.sh → 拉取 kallsyms                    │
│    ├─ patch_ksu_module.py → 补丁 .ko KASLR 符号        │
│    └─ ksu_step2.sh → insmod + ksud + 隐藏模块安装      │
└──────────────────────────────────────────────────────┘

┌─ 设备端 ─────────────────────────────────────────────┐
│  KernelSU (LKM)                                      │
│    ├─ insmod kernelsu_patched.ko                     │
│    ├─ ksud post-fs-data / services / boot-completed  │
│    └─ Manager 自动识别 (crowning)                     │
│                                                      │
│  隐藏模块 (ace3_hide_environment)                     │
│    ├─ service.sh: boot_completed 前修改属性           │
│    │   ├─ ro.boot.selinux → enforcing                │
│    │   ├─ 恢复 OPLUS 安全模块                         │
│    │   └─ setenforce 1                               │
│    └─ action.sh: 音量键菜单 (重载/修复/隐藏)          │
│                                                      │
│  ZygiskSU → 注入 zygote64                             │
│  LSPosed → lspd 守护进程 + framework 注入             │
└──────────────────────────────────────────────────────┘
```

## 关键技术点

- **KASLR**: 每次开机内核符号地址随机化，必须实时拉取 kallsyms 重新补丁
- **OPLUS 安全模块**: `insmod` 前必须卸载 `oplus_secure_harden` / `oplus_security_guard` 等模块，否则 ksud 会被内核杀死；加载完成后恢复
- **Magisk 误检测**: ksu_step2.sh 会删除 ksud 自动创建的 `magisk` 兼容符号链接，防止 Manager 误报冲突
- **隐藏模块时序**: `service.sh` 使用 `resetprop -w sys.boot_completed 0` 等待，确保在检测 APP 启动前完成属性修改
- **SELinux**: 加载阶段使用 permissive，完成后切回 enforcing
- **Mount Namespace**: lspd 需要 `nsenter -t 1 -m` 进入 init 的 namespace 才能访问 APEX

## 已知检测限制

以下检测项为 KernelSU 内核模块的**固有痕迹**，无法从用户层面绕过：

| 检测项 | 原因 | 状态 |
|--------|------|------|
| Prop area hole (`userdebug_or_eng_prop`) | KernelSU insmod 时内核直接操作 property 共享内存 | ❌ 无法修复 |
| 2 个 prop modified | KernelSU 内核模块修改 property trie 的 serial number | ❌ 无法修复 |
| Heap entropy (Jemalloc) | KernelSU syscall hook 改变内存分配模式 | ❌ 无法修复 |
| Hardware attestation | TEE/VBMeta 硬件级校验 | ❌ 无法修复 |

## 注意事项

- ⚠️ 每次**重启手机**后需要重新运行 `ksu_oneclick.bat`
- ⚠️ KernelSU 为非持久化加载（LKM），重启后失效
- ⚠️ 隐藏模块在首次安装后，后续开机会自动执行 `service.sh`（即使未运行 oneclick）
- ⚠️ 仅在 OnePlus Ace 3 + Android 13 + kernel 5.15 上测试
- ⚠️ 仅用于安全研究用途

## Credits

- Fork from [xunchahaha/mi_nobl_root](https://github.com/xunchahaha/mi_nobl_root)
- [KernelSU](https://kernelsu.org/)
