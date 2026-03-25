# 一加 Ace 3（欧加8gen2）免解锁越狱解决方案

在尝试免解 BL 进行 KernelSU 越狱时，系统底层的安全模块可能会强行拦截导致越狱失败。经过实测，只需在 **临时 Root 环境**，例如通过 [Magica (v2.1)](https://github.com/vvb2060/Magica/releases/tag/v2.1) 提权，在Root Shell 内开启 ADB Root。执行以下命令卸载安全模块：
   ```bash
   rmmod oplus_security_guard 2>/dev/null   
   ```
完成上述操作后，直接打开手机上的 KernelSU App，点击内部的“越狱”选项，即可成功加载并获取完整的 KSU 环境。注意成功后立刻给shell获取root权限。