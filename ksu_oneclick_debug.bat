@echo off
chcp 65001 >nul
setlocal
set PYTHONUTF8=1

echo ===============================================
echo   KernelSU 一键加载 v2
echo   每次开机后运行此脚本
echo ===============================================
echo.

set "DIR=%~dp0"
set "KO=%DIR%android13-5.15_kernelsu.ko"
set "PATCHED=%DIR%kernelsu_patched.ko"
set "KSUD=%DIR%ksud-aarch64-linux-android"
set "PATCHER=%DIR%patch_ksu_module.py"
set "KALLSYMS=%DIR%kallsyms.txt"

:: ─── 检查 ADB ───
echo 检查 ADB 连接...
adb get-state >nul 2>&1
if errorlevel 1 (
    echo [X] 没有 ADB 设备，请连接手机
    goto :fail
)
echo [OK] ADB 已连接

:check_root
echo 正在检查 Root Shell 环境...
set "USER_ID="
for /f "tokens=*" %%i in ('adb shell id') do set "USER_ID=%%i"
echo %USER_ID% | findstr "uid=0(root)" >nul
if not errorlevel 1 goto root_ok

echo [X] Current ADB is NOT Root Environment!
echo Please check device authorization or ensure your ROM supports default root shell.
echo Press any key to retry...
pause >nul
goto check_root

:root_ok
echo [OK] 发现 Root Shell Environment
echo.

:: ─── 推送脚本 + ksud ───
echo 推送文件到设备...
adb push "%DIR%ksu_step1.sh" /data/local/tmp/ksu_step1.sh >nul 2>&1
adb push "%DIR%ksu_step2.sh" /data/local/tmp/ksu_step2.sh >nul 2>&1
adb push "%KSUD%" /data/local/tmp/ksud-aarch64 >nul 2>&1
:: 自动修复安卓内的换行格式
adb shell "sed -i 's/\r$//' /data/local/tmp/ksu_step1.sh" >nul 2>&1
adb shell "sed -i 's/\r$//' /data/local/tmp/ksu_step2.sh" >nul 2>&1
:: 推送隐藏模块（整个目录）
adb shell "rm -rf /data/local/tmp/ksu_hide_module" >nul 2>&1
adb push "%DIR%ksu_hide_module" /data/local/tmp/ksu_hide_module >nul 2>&1
:: 修复模块内所有 shell 脚本的换行格式
adb shell "find /data/local/tmp/ksu_hide_module -name '*.sh' -exec sed -i 's/\r$//' {} +" >nul 2>&1
echo [OK] 文件已推送
echo.

:: =====================================
echo [1/5] 拉取 kallsyms...
:: =====================================

:: 始终重新拉取（重启后 KASLR 地址变了）
if exist "%KALLSYMS%" del "%KALLSYMS%" >nul 2>&1
if exist "%PATCHED%" del "%PATCHED%" >nul 2>&1

:: 同步执行并拉取
adb shell "sh /data/local/tmp/ksu_step1.sh"
adb pull /data/local/tmp/kallsyms.txt "%KALLSYMS%" >nul 2>&1

if not exist "%KALLSYMS%" (
    echo [!] kallsyms 拉取失败，重试中...
    adb shell "sh /data/local/tmp/ksu_step1.sh"
    adb pull /data/local/tmp/kallsyms.txt "%KALLSYMS%" >nul 2>&1
)

if not exist "%KALLSYMS%" (
    echo [X] kallsyms 拉取完全失败
    goto :fail
)
echo [OK] kallsyms 已拉取到本地
echo.

:: =====================================
echo [2/5] 补丁内核模块 (PC端 Python)...
:: =====================================

.\python\python.exe "%PATCHER%" "%KO%" "%KALLSYMS%" "%PATCHED%"
if errorlevel 1 (
    echo [X] 补丁失败
    goto :fail
)
if not exist "%PATCHED%" (
    echo [X] 补丁文件未生成
    goto :fail
)
echo.

:: =====================================
echo [3-5/5] 加载模块 + 部署ksud + 触发Manager...
:: =====================================

:: 推送补丁后的 ko
adb push "%PATCHED%" /data/local/tmp/kernelsu_patched.ko >nul 2>&1

:: 执行 step2 (同步输出到控制台)
echo ========== 核心流程执行输出 ==========
adb shell "sh /data/local/tmp/ksu_step2.sh"
echo =======================================
echo.

:: 检查是否成功
adb shell "grep -q 'kernelsu' /proc/modules"
if not errorlevel 1 (
    echo ===============================================
    echo   加载完成！正在重启 KernelSU Manager...
    echo ===============================================
    adb shell "am force-stop me.weishu.kernelsu && am start -n me.weishu.kernelsu/.ui.MainActivity" >nul 2>&1
) else (
    echo ===============================================
    echo   可能未完全成功，请检查上方输出。
    echo ===============================================
)

:: 清理过程临时文件
adb shell rm -f /data/local/tmp/ksu_step2.sh >nul 2>&1

if exist "%KALLSYMS%" del "%KALLSYMS%" >nul 2>&1
if exist "%PATCHED%" del "%PATCHED%" >nul 2>&1

echo.
pause
goto :eof

:fail
echo.
echo [X] 执行失败，请检查报错内容。
pause
