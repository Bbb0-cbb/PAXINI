# 系统信息收集脚本 - 用于评估 Ubuntu 双系统可行性

Write-Host "=== 系统配置检查 ===" -ForegroundColor Cyan
Write-Host ""

# CPU 信息
Write-Host "【处理器】" -ForegroundColor Yellow
Get-CimInstance -ClassName Win32_Processor | Select-Object Name, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed | Format-List

# 内存信息
Write-Host "【内存】" -ForegroundColor Yellow
$totalRAM = (Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB
Write-Host "总内存: $([math]::Round($totalRAM, 2)) GB"
Write-Host ""

# 磁盘信息
Write-Host "【磁盘空间】" -ForegroundColor Yellow
Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3" | Select-Object DeviceID,
    @{Name="容量(GB)";Expression={[math]::Round($_.Size/1GB,2)}},
    @{Name="可用(GB)";Expression={[math]::Round($_.FreeSpace/1GB,2)}},
    @{Name="可用率(%)";Expression={[math]::Round(($_.FreeSpace/$_.Size)*100,2)}} | Format-Table

# BIOS 模式
Write-Host "【启动模式】" -ForegroundColor Yellow
$bootMode = (Get-CimInstance -ClassName Win32_ComputerSystem).BootupState
$firmwareType = try {
    (Get-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\SecureBoot\State" -ErrorAction Stop).UEFISecureBootEnabled
    "UEFI"
} catch {
    "Legacy BIOS"
}
Write-Host "固件类型: $firmwareType"
Write-Host ""

# 显卡信息
Write-Host "【显卡】" -ForegroundColor Yellow
Get-CimInstance -ClassName Win32_VideoController | Select-Object Name, AdapterRAM | Format-List

# USB 控制器
Write-Host "【USB 控制器】" -ForegroundColor Yellow
$usbControllers = Get-CimInstance -ClassName Win32_USBController
Write-Host "USB 控制器数量: $($usbControllers.Count)"
Write-Host ""

# 操作系统版本
Write-Host "【操作系统】" -ForegroundColor Yellow
Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object Caption, Version, OSArchitecture, InstallDate | Format-List

Write-Host ""
Write-Host "=== 双系统安装建议 ===" -ForegroundColor Cyan
Write-Host ""

# 评估建议
$canInstall = $true
$warnings = @()
$recommendations = @()

# 检查 CPU
$cpu = Get-CimInstance -ClassName Win32_Processor
if ($cpu.NumberOfLogicalProcessors -lt 4) {
    $warnings += "⚠️  CPU 核心数较少（$($cpu.NumberOfLogicalProcessors) 核），建议 4 核以上"
} else {
    $recommendations += "✓ CPU: $($cpu.NumberOfLogicalProcessors) 核，满足要求"
}

# 检查内存
if ($totalRAM -lt 8) {
    $warnings += "⚠️  内存不足 8GB（当前 $([math]::Round($totalRAM, 1)) GB），可能影响性能"
} elseif ($totalRAM -ge 16) {
    $recommendations += "✓ 内存: $([math]::Round($totalRAM, 1)) GB，非常充足"
} else {
    $recommendations += "✓ 内存: $([math]::Round($totalRAM, 1)) GB，满足基本要求"
}

# 检查磁盘空间
$systemDrive = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DeviceID='C:'"
$freeSpaceGB = [math]::Round($systemDrive.FreeSpace/1GB, 2)

if ($freeSpaceGB -lt 60) {
    $warnings += "⚠️  C 盘可用空间不足（仅 $freeSpaceGB GB），建议至少保留 60GB 给 Ubuntu"
    $canInstall = $false
} elseif ($freeSpaceGB -lt 100) {
    $warnings += "⚠️  C 盘可用空间较少（$freeSpaceGB GB），安装 Ubuntu 需要至少 60GB"
    $recommendations += "  建议清理磁盘或使用其他分区"
} else {
    $recommendations += "✓ 磁盘空间: $freeSpaceGB GB 可用，足够安装 Ubuntu"
}

# 检查固件类型
if ($firmwareType -eq "UEFI") {
    $recommendations += "✓ 启动模式: UEFI，推荐使用 GPT 分区方案"
} else {
    $recommendations += "ℹ️  启动模式: Legacy BIOS，使用 MBR 分区方案"
}

Write-Host "【评估结果】" -ForegroundColor Green
foreach ($rec in $recommendations) {
    Write-Host $rec -ForegroundColor Green
}

if ($warnings.Count -gt 0) {
    Write-Host ""
    Write-Host "【警告事项】" -ForegroundColor Red
    foreach ($warn in $warnings) {
        Write-Host $warn -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "【总体建议】" -ForegroundColor Cyan

if ($canInstall) {
    Write-Host "✅ 您的电脑配置适合安装 Ubuntu 双系统" -ForegroundColor Green
    Write-Host ""
    Write-Host "推荐配置方案：" -ForegroundColor White
    Write-Host "  • Ubuntu 分区大小: 80-120 GB"
    Write-Host "  • Swap 分区: $([math]::Max(8, [math]::Ceiling($totalRAM))) GB（建议与内存相等）"
    Write-Host "  • 备份重要数据后再进行分区操作"
    Write-Host "  • 建议使用 Ubuntu 22.04 LTS Desktop 版本"
    Write-Host "  • 如果C盘空间不足，可以使用其他盘（D盘、E盘等）"
} else {
    Write-Host "❌ 当前配置不太适合安装双系统" -ForegroundColor Red
    Write-Host ""
    Write-Host "替代方案：" -ForegroundColor White
    Write-Host "  1. 使用虚拟机（VMware / VirtualBox）"
    Write-Host "  2. 使用 WSL2（适合开发测试）"
    Write-Host "  3. 购买独立的边缘计算设备（Intel NUC / 工业PC）"
}

Write-Host ""
Write-Host "报告已生成完毕！" -ForegroundColor Cyan
Write-Host "按任意键退出..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
