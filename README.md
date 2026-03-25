# 免解锁 Bootloader Root 方案

**测试设备**: OnePlus Ace 3

内核版本: 5.15.x-android13

**原理**: 利用已有的 root shell 权限，在运行时加载 KernelSU 内核模块

> ⚠️ **仅供测试，后果自负。Use at your own risk!!!**

## 前提条件

1. [Magica](https://github.com/vvb2060/Magica) 获得 adb root 权限（`adb shell` 直接为 root）
4. 安装 [**KernelSU Manager**](https://github.com/tiann/KernelSU)

## 使用方法

### 每次开机后运行

```bat
ksu_oneclick.bat
```

自动完成以下步骤：
1. 修补并`insmod` 加载KernelSU内核模块
2. 部署 ksud、执行启动阶段（`post-fs-data → services → boot-completed`）

## 注意事项

- ⚠️ 重启后失效
- ⚠️ 仅在 OnePlus Ace 3 ColorOS16 (PJE110_16.0.3.500)上测试

## Credits

- Fork from [xunchahaha/mi_nobl_root](https://github.com/xunchahaha/mi_nobl_root)
- [KernelSU](https://kernelsu.org/)
