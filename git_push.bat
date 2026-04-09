@echo off
setlocal
chcp 65001 >nul

cd /d "%~dp0"

echo Cleaning up build cache and obsolete files...
rmdir /s /q python 2>nul
del /f /q commit.txt commit2.txt cleanup.bat fix_lspd.sh ksu_step1.sh patch_ksu_module.py kernelsu_patched.ko kallsyms.txt 2>nul
del /f /q prompts\retry_pull.txt prompts\errors.txt 2>nul

echo Staging changes...
git add -A

echo Creating commit...
>commit_temp.txt echo refactor: native ksud debug insmod injection
>>commit_temp.txt echo.
>>commit_temp.txt echo - Full pipeline transition from PC Python patching to on-device ksud debug insmod
>>commit_temp.txt echo - Obsoleted python dependency, kallsyms extraction, and patch_ksu_module.py
>>commit_temp.txt echo - Streamlined oneclick.bat steps from 6 to 4 phases
>>commit_temp.txt echo - Removed redundant fix_lspd.sh root copy
>>commit_temp.txt echo - Added device-side cleanup handling for kernelsu.ko

git commit -F commit_temp.txt
del commit_temp.txt

echo Pushing to remote...
git push

echo =========================
echo DONE!
echo =========================
pause
