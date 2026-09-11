@echo off
setlocal
pushd "%~dp0"
if errorlevel 1 exit /b 1

call mads tetris.asm -o:tetris.xex -t:tetris.lab
if errorlevel 1 goto failed
if /I "%~1"=="game" goto done

call mads design.asm -o:design.xex
if errorlevel 1 goto failed
call mads design2.asm -o:design2.xex
if errorlevel 1 goto failed
call mads design3.asm -o:design3.xex
if errorlevel 1 goto failed

:done
popd
exit /b 0

:failed
popd
exit /b 1
