@echo off
setlocal
pushd "%~dp0"
if errorlevel 1 exit /b 1

call mads tetris.asm -o:tetris.xex -t:tetris.lab
if errorlevel 1 goto failed

popd
exit /b 0

:failed
popd
exit /b 1
