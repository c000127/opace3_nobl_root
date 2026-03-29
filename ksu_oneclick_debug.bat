@echo off
setlocal
chcp 65001 >nul

set "DIR=%~dp0"
set "P=%DIR%prompts\"
set "KO=%DIR%android13-5.15_kernelsu.ko"
set "PATCHED=%DIR%kernelsu_patched.ko"
set "KSUD=%DIR%ksud-aarch64-linux-android"
set "PATCHER=%DIR%patch_ksu_module.py"
set "KALLSYMS=%DIR%kallsyms.txt"

type "%P%banner_debug.txt"
echo.

echo [1/6] Checking ADB...
adb kill-server >nul 2>&1
adb start-server >nul 2>&1
adb get-state >nul 2>&1
if errorlevel 1 goto no_adb
goto check_root

:no_adb
type "%P%no_adb.txt"
echo.
goto fail

:check_root
set "USER_ID="
for /f "tokens=*" %%i in ('adb shell id') do set "USER_ID=%%i"
echo %USER_ID% | findstr "uid=0(root)" >nul
if not errorlevel 1 goto root_ok

type "%P%no_root.txt"
echo.
pause >nul
goto check_root

:root_ok
type "%P%root_ok.txt"
echo.
echo.

echo [2/6] Pushing files...
adb push "%DIR%ksu_step1.sh" /data/local/tmp/ksu_step1.sh
adb push "%DIR%ksu_step2.sh" /data/local/tmp/ksu_step2.sh
adb push "%DIR%ksu_step3.sh" /data/local/tmp/ksu_step3.sh
adb push "%KSUD%" /data/local/tmp/ksud-aarch64
adb shell "sed -i 's/\r$//' /data/local/tmp/ksu_step1.sh"
adb shell "sed -i 's/\r$//' /data/local/tmp/ksu_step2.sh"
adb shell "sed -i 's/\r$//' /data/local/tmp/ksu_step3.sh"
adb shell "rm -rf /data/local/tmp/ksu_hide_module"
adb push "%DIR%ksu_hide_module" /data/local/tmp/ksu_hide_module
adb shell "find /data/local/tmp/ksu_hide_module -name '*.sh' -exec sed -i 's/\r$//' {} +"
echo [OK] Done.
echo.

echo [3/6] Pulling kallsyms...
if exist "%KALLSYMS%" del "%KALLSYMS%" >nul 2>&1
if exist "%PATCHED%" del "%PATCHED%" >nul 2>&1
adb shell "sh /data/local/tmp/ksu_step1.sh"
adb pull /data/local/tmp/kallsyms.txt "%KALLSYMS%"
if exist "%KALLSYMS%" goto kallsyms_ok
type "%P%retry_pull.txt"
echo.
adb shell "sh /data/local/tmp/ksu_step1.sh"
adb pull /data/local/tmp/kallsyms.txt "%KALLSYMS%"
if exist "%KALLSYMS%" goto kallsyms_ok
echo [X] Failed!
goto fail

:kallsyms_ok
echo [OK] Done.
echo.

echo [4/6] Patching module (Python)...
.\python\python.exe "%PATCHER%" "%KO%" "%KALLSYMS%" "%PATCHED%"
if not errorlevel 1 goto patch_check
echo [X] Patch failed!
goto fail

:patch_check
if exist "%PATCHED%" goto patch_ok
echo [X] Patched file not found!
goto fail

:patch_ok
echo [OK] Done.
echo.

echo [5/6] Loading KernelSU (insmod)...
adb push "%PATCHED%" /data/local/tmp/kernelsu_patched.ko
echo.
adb shell "sh /data/local/tmp/ksu_step2.sh"
echo.

type "%P%reroot.txt"
pause >nul

:check_root_phase2
echo reconnecting adb...
adb kill-server >nul 2>&1
adb start-server >nul 2>&1
set "USER_ID="
for /f "tokens=*" %%i in ('adb shell su -c id 2^>nul') do set "USER_ID=%%i"
echo %USER_ID% | findstr "uid=0(root)" >nul
if not errorlevel 1 goto root_ok_phase2

type "%P%retry_root.txt"
echo.
pause >nul
goto check_root_phase2

:root_ok_phase2
type "%P%root_reacquired.txt"
echo.
echo.

echo [6/6] Deploying environment...
adb shell "su -c sh /data/local/tmp/ksu_step3.sh"

adb shell "su -c grep -q kernelsu /proc/modules"
if errorlevel 1 goto cleanup

type "%P%success.txt"
adb shell su -c am force-stop me.weishu.kernelsu >nul 2>&1
adb shell su -c am start -n me.weishu.kernelsu/.ui.MainActivity >nul 2>&1

:cleanup
if exist "%KALLSYMS%" del "%KALLSYMS%" >nul 2>&1
if exist "%PATCHED%" del "%PATCHED%" >nul 2>&1
adb shell su -c rm -f /data/local/tmp/ksu_step2.sh >nul 2>&1
adb shell su -c rm -f /data/local/tmp/ksu_step3.sh >nul 2>&1

echo.
pause
goto :eof

:fail
echo.
type "%P%abort.txt"
echo.
pause
