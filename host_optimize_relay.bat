@echo off
title FRP 网络优化

echo 正在检查 frpc.exe 或 frp.exe 是否正在运行...

:: 检查 frpc.exe 是否运行中
tasklist /fi "imagename eq frpc.exe" | find /i "frpc.exe" >nul
if %errorlevel%==0 (
    echo 找到 frpc.exe，设置优先级为高...
    wmic process where name="frpc.exe" CALL setpriority 128
) else (
    :: 如果 frpc.exe 没找到，继续检查 frp.exe
    tasklist /fi "imagename eq frp.exe" | find /i "frp.exe" >nul
    if %errorlevel%==0 (
        echo 找到 frp.exe，设置优先级为高...
        wmic process where name="frp.exe" CALL setpriority 128
    ) else (
        echo 没有找到 frpc.exe 或 frp.exe，请先启动 FRP 客户端。
        goto end
    )
)

:: 网络优化设置
echo 正在应用网络优化设置...

:: 禁用 Nagle 算法（降低延迟）
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" /v TcpAckFrequency /t REG_DWORD /d 1 /f >nul 2>&1
reg add "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" /v TCPNoDelay /t REG_DWORD /d 1 /f >nul 2>&1

:: TCP 参数调整
netsh int tcp set global autotuninglevel=experimental >nul
netsh int tcp set global chimney=enabled >nul
netsh int tcp set global rss=enabled >nul
netsh int tcp set heuristics disabled >nul

:: 刷新 DNS
ipconfig /flushdns
ipconfig /release
ipconfig /renew

:end
echo.
echo 优化完成，已结束。
pause
