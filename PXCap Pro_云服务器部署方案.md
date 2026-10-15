# PXCap Pro 云服务器部署方案

**文档版本：** V1.0  
**创建日期：** 2026-09-30  
**目标场景：** Ubuntu 云服务器远程部署与数据采集

---

## ⚠️ 重要提示：云服务器部署的关键限制

PXCap Pro 上位机和 SDK 是为**本地物理设备连接**设计的系统，云服务器部署面临以下核心挑战：

### 1. 硬件物理连接要求
- **USB 串口直连：** 手套通过 USB CDC 串口（/dev/ttyACM*）与主机通信
- **腕部相机：** 需要 USB UVC 相机设备（/dev/video*）
- **云服务器限制：** 标准云服务器（阿里云、腾讯云、AWS EC2 等）**无法直接连接本地 USB 设备**

### 2. GUI 图形界面依赖
- PXCap Studio 上位机是**桌面应用程序**，需要图形界面
- 云服务器默认只有命令行，需要额外配置远程桌面或 VNC

### 3. 实时性要求
- 触觉数据采集频率：83.3 Hz
- 角度数据采集频率：78 Hz
- 网络延迟会影响实时监控体验

---

## 部署架构方案

根据实际需求，推荐以下三种架构：

### 方案 A：边缘计算 + 云端存储（推荐）

```
┌─────────────────┐         ┌──────────────────┐         ┌─────────────────┐
│  PXCap Pro 手套  │ USB     │   本地边缘主机    │  网络    │   云端服务器     │
│  + 腕部相机     │────────▶│  Ubuntu 22.04    │────────▶│  数据存储/分析   │
└─────────────────┘         │  + PXCap Studio  │         │  + 模型训练     │
                            │  + SDK           │         └─────────────────┘
                            └──────────────────┘
                                    ▲
                                    │ SSH/远程桌面
                                    ▼
                            ┌──────────────────┐
                            │   操作人员终端    │
                            └──────────────────┘
```

**适用场景：**
- 数据采集现场有独立主机（工业 PC、边缘计算盒子、笔记本）
- 需要稳定的实时数据采集
- 采集后自动上传云端进行后处理

**优势：**
- ✅ USB 设备直连，无延迟
- ✅ 实时性最佳
- ✅ 可离线工作
- ✅ 数据采集稳定

**实施步骤：** 见第 3 节

---

### 方案 B：USB over Network（技术可行，不推荐）

```
┌─────────────────┐         ┌──────────────────┐  USB/IP  ┌─────────────────┐
│  PXCap Pro 手套  │ USB     │   本地 USB 服务器 │  网络    │   云端 Ubuntu    │
│  + 腕部相机     │────────▶│  (Windows/Linux) │─────────▶│  + PXCap Studio │
└─────────────────┘         └──────────────────┘          └─────────────────┘
```

**技术方案：**
- 本地使用 USB/IP 服务器共享 USB 设备
- 云服务器通过 USB/IP 客户端远程挂载

**为何不推荐：**
- ❌ 网络延迟影响实时性
- ❌ USB/IP 对带宽要求高（尤其是相机）
- ❌ 连接稳定性差，易断线
- ❌ 数据采集质量评分可能不合格

---

### 方案 C：纯云端 SDK 开发（适合特定场景）

```
┌─────────────────┐         ┌──────────────────┐  SFTP/SCP  ┌─────────────────┐
│  本地采集脚本    │ USB     │   本地 Ubuntu    │    网络    │   云端服务器     │
│  (仅 SDK)       │────────▶│  pxhandsdk       │───────────▶│  数据分析       │
└─────────────────┘         │  自动采集        │            │  + 可视化       │
                            └──────────────────┘            │  + 模型训练     │
                                                            └─────────────────┘
```

**适用场景：**
- 不需要实时图形界面监控
- 只需要定期自动采集数据
- 采集后批量上传云端分析

**优势：**
- ✅ 无需 GUI，资源占用低
- ✅ 可完全自动化
- ✅ 适合无人值守采集

**实施步骤：** 见第 4 节

---

## 3. 方案 A 详细实施：边缘 + 云端架构

### 3.1 边缘端硬件要求

| 配置项 | 最低要求 | 推荐配置 |
|--------|---------|---------|
| **处理器** | Intel i5 / AMD Ryzen 5 | Intel i7 / AMD Ryzen 7 |
| **架构** | x86_64 (amd64) | x86_64 (amd64) |
| **内存** | 8 GB | 16 GB |
| **存储** | 60 GB SSD | 128 GB SSD |
| **USB 端口** | USB 2.0 × 2（手套+相机） | USB 3.0 × 2 |
| **操作系统** | Ubuntu 22.04 LTS Desktop | Ubuntu 22.04 LTS Desktop |
| **网络** | 有线/WiFi，上行 ≥ 10 Mbps | 有线千兆，上行 ≥ 100 Mbps |
| **显示器** | 可选（仅初次配置） | - |

**硬件选型建议：**
- **工业 PC：** 研华 ARK 系列、华北工控等（适合恶劣环境）
- **边缘计算盒子：** NVIDIA Jetson（如需 AI 推理）、Intel NUC
- **笔记本电脑：** 任意满足配置的商用笔记本
- **台式机：** 组装机或品牌机均可

### 3.2 边缘端软件部署

#### 步骤 1：安装 Ubuntu 22.04 LTS

```bash
# 下载 Ubuntu 22.04 Desktop ISO
# 使用 Rufus (Windows) 或 dd (Linux/Mac) 制作启动盘
# 安装时建议：
# - 分区：至少 60 GB 根分区 + 8 GB swap
# - 用户名：建议 pxcap-operator
# - 时区：选择当地时区
# - 自动登录：可选启用（无人值守场景）
```

#### 步骤 2：安装 PXCap Pro 软件包

```bash
# 更新系统
sudo apt update && sudo apt upgrade -y

# 安装依赖（如缺失）
sudo apt install -y build-essential cmake pkg-config usbutils

# 复制 DEB 包到边缘主机（通过 U 盘或网络）
# 假设包在 /tmp 目录

# 安装 SDK
sudo dpkg -i /tmp/pxhandsdk_1.0.0.0.ubantu2204_amd64.deb

# 安装上位机
sudo dpkg -i /tmp/pxcap-studio_1.0.0_amd64.deb

# 修复依赖（如提示缺失）
sudo apt-get -f install

# 配置串口权限
sudo /usr/share/pxhandsdk/scripts/setup-serial-access.sh

# 添加相机权限
sudo usermod -aG video "$USER"

# 重新登录使权限生效
# 方法1：注销后重新登录
# 方法2：重启系统
sudo reboot
```

#### 步骤 3：验证设备连接

```bash
# 连接手套和相机后检查
lsusb                          # 应显示手套和相机 USB 设备
ls -l /dev/ttyACM*            # 应显示串口，如 /dev/ttyACM0
ls -l /dev/video*             # 应显示相机，如 /dev/video0

# 检查权限
groups                        # 应包含 dialout 和 video

# 测试 SDK
/usr/bin/python3 /usr/share/pxhandsdk/examples/amd64/python/pxcappro_demo.py /dev/ttyACM0

# 启动上位机
/opt/PXCap\ Studio/pxcap-studio
```

### 3.3 配置远程访问

为了从异地操作边缘主机，需要配置远程访问：

#### 选项 1：SSH + X11 转发（轻量级，适合低带宽）

```bash
# 边缘主机：安装 SSH 服务器
sudo apt install -y openssh-server
sudo systemctl enable ssh
sudo systemctl start ssh

# 配置防火墙（如启用）
sudo ufw allow 22/tcp

# 操作人员电脑（Linux/Mac）：
ssh -X pxcap-operator@<边缘主机IP>
/opt/PXCap\ Studio/pxcap-studio  # 图形界面通过 X11 转发显示

# 操作人员电脑（Windows）：
# 安装 MobaXterm 或 Xming + PuTTY，启用 X11 转发
```

#### 选项 2：VNC 远程桌面（推荐，体验最佳）

```bash
# 边缘主机：安装 VNC 服务器
sudo apt install -y x11vnc

# 创建 VNC 密码
x11vnc -storepasswd /home/$USER/.vnc/passwd

# 配置 VNC 服务自动启动
sudo tee /etc/systemd/system/x11vnc.service > /dev/null <<EOF
[Unit]
Description=x11vnc Remote Desktop
After=display-manager.service

[Service]
Type=simple
ExecStart=/usr/bin/x11vnc -display :0 -auth guess -forever -loop -noxdamage -repeat -rfbauth /home/pxcap-operator/.vnc/passwd -rfbport 5900 -shared
User=pxcap-operator
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable x11vnc
sudo systemctl start x11vnc

# 配置防火墙
sudo ufw allow 5900/tcp

# 操作人员电脑：
# 使用 RealVNC Viewer、TightVNC 或 VNC Viewer
# 连接地址：<边缘主机IP>:5900
# 输入设置的密码
```

#### 选项 3：向日葵/ToDesk（最简单，适合非技术人员）

```bash
# 边缘主机：访问向日葵官网下载 Linux 客户端
# https://sunlogin.oray.com/download/linux

# 或使用 ToDesk
# https://www.todesk.com/linux.html

# 安装后登录账号，即可实现远程控制
# 无需配置防火墙和端口转发
```

### 3.4 云端服务器配置

#### 云服务器基本要求

| 配置项 | 最低要求 | 推荐配置 |
|--------|---------|---------|
| **CPU** | 2 核 | 4 核+ |
| **内存** | 4 GB | 8 GB+ |
| **存储** | 100 GB | 500 GB+（根据数据量） |
| **操作系统** | Ubuntu 22.04 Server | Ubuntu 22.04 Server |
| **带宽** | 5 Mbps | 10 Mbps+ |

#### 云端数据接收服务

```bash
# 方案 1：SFTP 服务器（最简单）
sudo apt install -y openssh-server
sudo mkdir -p /data/pxcap-collections
sudo chown pxcap-operator:pxcap-operator /data/pxcap-collections

# 边缘主机可通过 SFTP 上传数据
# sftp pxcap-operator@<云服务器IP>
# put -r ~/.config/pxcap-studio/DataLogging/records/* /data/pxcap-collections/
```

```bash
# 方案 2：HTTP 文件服务器（适合自动化）
sudo apt install -y nginx

# 配置 WebDAV 或使用 Python 脚本接收文件
# 详细配置见第 5 节
```

```bash
# 方案 3：对象存储（推荐生产环境）
# 使用阿里云 OSS、腾讯云 COS 或 AWS S3
# 边缘主机安装 ossutil/coscmd/aws-cli
sudo apt install -y python3-pip
pip3 install aliyun-python-sdk-oss  # 示例：阿里云 OSS

# 配置自动同步脚本（见第 5 节）
```

### 3.5 自动化数据上传

#### 创建上传脚本

```bash
# 在边缘主机创建：/home/pxcap-operator/scripts/upload-data.sh

#!/bin/bash
# PXCap Pro 数据自动上传脚本

SOURCE_DIR="$HOME/.config/pxcap-studio/DataLogging/records"
CLOUD_SERVER="cloud-user@<云服务器IP>"
CLOUD_PATH="/data/pxcap-collections"
LOG_FILE="$HOME/upload.log"

echo "[$(date)] 开始同步数据..." >> "$LOG_FILE"

# 使用 rsync 增量同步
rsync -avz --progress --exclude="*.tmp" \
  "$SOURCE_DIR/" \
  "$CLOUD_SERVER:$CLOUD_PATH/" \
  >> "$LOG_FILE" 2>&1

if [ $? -eq 0 ]; then
    echo "[$(date)] 同步成功" >> "$LOG_FILE"
else
    echo "[$(date)] 同步失败" >> "$LOG_FILE"
fi
```

```bash
# 设置执行权限
chmod +x ~/scripts/upload-data.sh

# 配置 SSH 免密登录（重要）
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa_pxcap -N ""
ssh-copy-id -i ~/.ssh/id_rsa_pxcap.pub cloud-user@<云服务器IP>

# 测试上传
~/scripts/upload-data.sh
```

#### 配置定时任务

```bash
# 编辑 crontab
crontab -e

# 添加以下行（每小时同步一次）
0 * * * * /home/pxcap-operator/scripts/upload-data.sh

# 或者每次采集完成后手动触发
# 可以在上位机中配置采集结束后执行脚本
```

---

## 4. 方案 C 详细实施：纯 SDK 云端开发

### 4.1 边缘端最小化部署

#### 硬件要求

```
最低配置：
- 树莓派 4B (4GB) 或更高
- Intel NUC / 边缘计算盒子
- 或复用方案 A 的硬件，不安装 GUI
```

#### 软件部署

```bash
# 安装 Ubuntu Server（无桌面）
# 或使用 Ubuntu Desktop 但禁用 GUI

# 仅安装 SDK（不安装上位机）
sudo dpkg -i pxhandsdk_1.0.0.0.ubantu2204_amd64.deb
sudo /usr/share/pxhandsdk/scripts/setup-serial-access.sh
sudo reboot
```

### 4.2 开发自动采集脚本

#### Python 示例：无人值守采集

```python
#!/usr/bin/env python3
# auto_collection.py - 自动数据采集脚本

import sys
import time
import json
import csv
from datetime import datetime
from pathlib import Path
from pxhandsdk import pxcappro

class AutoCollector:
    def __init__(self, device_port, output_dir, duration_sec=60):
        self.device_port = device_port
        self.output_dir = Path(output_dir)
        self.duration_sec = duration_sec
        self.glove = pxcappro.PxCapPro()
        
        # 创建输出目录
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
    def connect(self):
        """连接设备"""
        rc = self.glove.connect_device(self.device_port)
        if rc != 0:
            error_code, error_msg = self.glove.get_last_error()
            print(f"连接失败: [{error_code}] {error_msg}")
            return False
        print(f"✓ 已连接到设备: {self.device_port}")
        
        # 读取设备信息
        rc, version = self.glove.get_firmware_versions()
        if rc == 0:
            print(f"  主控版本: {version.main_controller_version}")
            print(f"  传感器版本: {version.sensor_version}")
            
        rc, sn = self.glove.get_sn()
        if rc == 0:
            print(f"  设备 SN: {sn}")
            
        return True
    
    def collect_session(self, session_name=None):
        """执行一次采集任务"""
        if session_name is None:
            session_name = f"session_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        
        session_dir = self.output_dir / session_name
        session_dir.mkdir(exist_ok=True)
        
        sensor_file = session_dir / "sensor.csv"
        encoder_file = session_dir / "encoder.csv"
        manifest_file = session_dir / "manifest.json"
        
        print(f"\n开始采集: {session_name}")
        print(f"  持续时间: {self.duration_sec} 秒")
        print(f"  输出目录: {session_dir}")
        
        # 准备 CSV 文件
        sensor_writer = None
        encoder_writer = None
        
        try:
            with open(sensor_file, 'w', newline='') as sf, \
                 open(encoder_file, 'w', newline='') as ef:
                
                start_time = time.time()
                frame_count = 0
                
                # 写入表头
                sensor_writer = csv.writer(sf)
                encoder_writer = csv.writer(ef)
                
                sensor_writer.writerow([
                    'Timestamp', 
                    'thumb_tip_x', 'thumb_tip_y', 'thumb_tip_z',
                    'index_tip_x', 'index_tip_y', 'index_tip_z',
                    'middle_tip_x', 'middle_tip_y', 'middle_tip_z',
                    'ring_tip_x', 'ring_tip_y', 'ring_tip_z',
                    'pinky_tip_x', 'pinky_tip_y', 'pinky_tip_z',
                    'palm_x', 'palm_y', 'palm_z'
                ])
                
                encoder_writer.writerow([
                    'Timestamp',
                    'encoder_0', 'encoder_1', 'encoder_2', 'encoder_3',
                    'encoder_4', 'encoder_5', 'encoder_6', 'encoder_7',
                    'encoder_8', 'encoder_9', 'encoder_10', 'encoder_11',
                    'encoder_12', 'encoder_13', 'encoder_14', 'encoder_15',
                    'encoder_16'
                ])
                
                print("  采集中...", end='', flush=True)
                
                while time.time() - start_time < self.duration_sec:
                    # 读取触觉数据
                    rc, sensor_data = self.glove.get_sensor_data()
                    if rc == 0:
                        timestamp = time.time_ns()
                        forces = [
                            sensor_data.thumb_tip_force.resultant_force,
                            sensor_data.index_tip_force.resultant_force,
                            sensor_data.middle_tip_force.resultant_force,
                            sensor_data.ring_tip_force.resultant_force,
                            sensor_data.pinky_tip_force.resultant_force,
                            sensor_data.palm_force.resultant_force
                        ]
                        row = [timestamp]
                        for f in forces:
                            row.extend([f.x, f.y, f.z])
                        sensor_writer.writerow(row)
                    
                    # 读取编码器数据
                    rc, encoder_data = self.glove.get_encoder_angles()
                    if rc == 0:
                        timestamp = time.time_ns()
                        row = [timestamp] + list(encoder_data.angles)
                        encoder_writer.writerow(row)
                    
                    frame_count += 1
                    if frame_count % 100 == 0:
                        print(".", end='', flush=True)
                    
                    time.sleep(0.01)  # 约 100 Hz
                
                end_time = time.time()
                actual_duration = end_time - start_time
                
                print(f"\n✓ 采集完成")
                print(f"  实际时长: {actual_duration:.2f} 秒")
                print(f"  采集帧数: {frame_count}")
                print(f"  平均频率: {frame_count/actual_duration:.1f} Hz")
                
                # 写入 manifest
                manifest = {
                    "session_id": session_name,
                    "start_time": datetime.fromtimestamp(start_time).isoformat(),
                    "end_time": datetime.fromtimestamp(end_time).isoformat(),
                    "duration_sec": actual_duration,
                    "frame_count": frame_count,
                    "device_port": self.device_port,
                    "files": {
                        "sensor": str(sensor_file.name),
                        "encoder": str(encoder_file.name)
                    }
                }
                
                with open(manifest_file, 'w') as mf:
                    json.dump(manifest, mf, indent=2)
                
                return True
                
        except Exception as e:
            print(f"\n✗ 采集失败: {e}")
            return False
    
    def disconnect(self):
        """断开设备"""
        self.glove.disconnect_device()
        print("✓ 已断开设备连接")

def main():
    if len(sys.argv) < 2:
        print("用法: python3 auto_collection.py /dev/ttyACM0 [输出目录] [持续时间秒]")
        sys.exit(1)
    
    device_port = sys.argv[1]
    output_dir = sys.argv[2] if len(sys.argv) > 2 else "./data"
    duration = int(sys.argv[3]) if len(sys.argv) > 3 else 60
    
    collector = AutoCollector(device_port, output_dir, duration)
    
    try:
        if not collector.connect():
            sys.exit(1)
        
        # 可以循环采集多次
        collector.collect_session()
        
    finally:
        collector.disconnect()

if __name__ == "__main__":
    main()
```

#### 部署和运行

```bash
# 保存脚本
nano /home/pxcap-operator/auto_collection.py
chmod +x /home/pxcap-operator/auto_collection.py

# 运行采集（60 秒）
/usr/bin/python3 /home/pxcap-operator/auto_collection.py /dev/ttyACM0 /data/collections 60

# 配置定时任务（每天凌晨 2 点采集 5 分钟）
crontab -e
# 添加：
0 2 * * * /usr/bin/python3 /home/pxcap-operator/auto_collection.py /dev/ttyACM0 /data/collections 300 >> /var/log/pxcap-cron.log 2>&1
```

### 4.3 数据自动上传到云端

```bash
# 结合 rsync 或云存储 SDK
# 在采集脚本后添加上传逻辑，或单独配置定时同步
# 参考方案 A 的 3.5 节
```

---

## 5. 数据传输和存储方案

### 5.1 估算数据量

```
单个采集会话（10 分钟）：
- sensor.csv: 约 10 MB (6路 × 100Hz × 600秒)
- encoder.csv: 约 5 MB (17路 × 100Hz × 600秒)
- 相机视频 (MJPEG, 30fps): 约 500 MB
- 总计：约 515 MB / 10分钟

每天采集 8 小时：
515 MB × (8×60/10) = 24.7 GB / 天

每月数据量：约 740 GB
```

### 5.2 网络带宽需求

```
实时上传（边采边传）：
24.7 GB / 天 ÷ 86400 秒 = 2.28 Mbps（平均）
建议带宽：≥ 10 Mbps（考虑峰值）

批量上传（每小时同步一次）：
515 MB / 小时 ÷ 3600 秒 = 1.14 Mbps（平均）
建议带宽：≥ 5 Mbps
```

### 5.3 云端存储选型

| 方案 | 适用场景 | 成本 | 优势 |
|------|---------|------|------|
| **云服务器本地盘** | 小规模测试 | 中 | 简单，访问快 |
| **对象存储 (OSS/S3)** | 生产环境 | 低 | 可靠，弹性，成本低 |
| **NAS/文件服务器** | 私有部署 | 高 | 完全可控 |

**推荐：阿里云 OSS 标准存储**
- 750 GB/月 × ¥0.12/GB = ¥90/月
- 公网流出 100 GB × ¥0.50/GB = ¥50/月
- **总计约 ¥140/月**

---

## 6. 安全和运维

### 6.1 网络安全

```bash
# 边缘主机：配置防火墙
sudo ufw enable
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 5900/tcp  # VNC（如需要）

# 云服务器：配置安全组
# 仅开放必要端口：22 (SSH), 443 (HTTPS)
# 限制源 IP 为边缘主机 IP
```

### 6.2 监控和告警

```bash
# 边缘主机：安装监控脚本
# /home/pxcap-operator/scripts/health-check.sh

#!/bin/bash
# 检查设备连接状态

if ! ls /dev/ttyACM* > /dev/null 2>&1; then
    echo "警告：未检测到 PXCap Pro 设备" | mail -s "设备告警" admin@example.com
fi

if ! pgrep -x "pxcap-studio" > /dev/null; then
    echo "警告：上位机未运行" | mail -s "软件告警" admin@example.com
fi

# 配置定时检查
crontab -e
# */10 * * * * /home/pxcap-operator/scripts/health-check.sh
```

### 6.3 数据备份

```bash
# 云端：配置定期备份到对象存储
sudo apt install -y rclone

# 配置 rclone（以阿里云 OSS 为例）
rclone config

# 定时备份
crontab -e
# 0 3 * * * rclone sync /data/pxcap-collections aliyun-oss:pxcap-backup/
```

---

## 7. 成本估算

### 方案 A：边缘 + 云端

| 项目 | 成本 | 说明 |
|------|------|------|
| **边缘主机硬件** | ¥3,000 ~ ¥8,000 | Intel NUC 或工业 PC |
| **云服务器** | ¥50 ~ ¥200/月 | 2核4G，按需选配 |
| **云存储** | ¥100 ~ ¥300/月 | OSS，根据数据量 |
| **网络带宽** | ¥50 ~ ¥150/月 | 10 Mbps 固定带宽 |
| **首年总成本** | ¥5,400 ~ ¥16,000 | 硬件 + 12个月云服务 |

### 方案 C：纯 SDK

| 项目 | 成本 | 说明 |
|------|------|------|
| **边缘硬件** | ¥500 ~ ¥2,000 | 树莓派 4B 或 NUC |
| **云服务器** | ¥30 ~ ¥100/月 | 1核2G 即可 |
| **云存储** | ¥100 ~ ¥300/月 | 同上 |
| **首年总成本** | ¥2,000 ~ ¥6,800 | 更经济 |

---

## 8. 常见问题

### Q1: 能否直接在云服务器上连接手套？
**A:** 不能。标准云服务器无法访问您本地的 USB 设备。必须通过本地边缘主机连接，再上传数据到云端。

### Q2: 能否用树莓派作为边缘主机？
**A:** 理论可行，但 SDK 仅提供 x86_64 版本。如需 ARM 支持（树莓派），需联系厂商获取 ARM 版 SDK。

### Q3: 网络中断会影响数据采集吗？
**A:** 不会。边缘主机本地采集不依赖网络，数据先存储本地，网络恢复后再同步到云端。

### Q4: 如何保证数据安全？
**A:** 
- 传输：使用 SFTP/HTTPS 加密传输
- 存储：云端开启服务器端加密
- 访问：配置防火墙和访问控制

### Q5: 延迟多少会影响实时性？
**A:** 本地采集无延迟问题。如通过 VNC 远程监控，建议延迟 < 100ms，否则操作体验较差。

---

## 9. 总结和建议

### 推荐方案对比

| 场景 | 推荐方案 | 原因 |
|------|---------|------|
| **研发测试，需实时监控** | 方案 A（边缘+云端） | 稳定可靠，GUI 完整 |
| **生产环境，无人值守** | 方案 C（纯 SDK） | 自动化程度高，成本低 |
| **临时测试，短期使用** | 本地 Ubuntu 虚拟机 | 无需云端，配置简单 |

### 关键建议

1. **优先本地采集：** 不要试图直接在云服务器上连接 USB 设备
2. **选择合适架构：** 根据是否需要 GUI 和实时监控选择方案 A 或 C
3. **网络容错：** 设计边缘端本地存储，避免网络故障丢失数据
4. **监控告警：** 配置设备和服务健康检查，及时发现问题
5. **数据备份：** 云端数据定期备份到对象存储

---

## 10. 联系支持

**技术问题：**
- 查看完整文档：`PXCap Pro_Windows全流程操作手册.md`
- SDK 手册：`pxcappro使用手册.md`

**商务合作：**
- 邮箱：mkt@paxini.com
- 如需 Windows 原生版或 ARM 版 SDK，请联系厂商

---

**文档版权所有 © 2026**  
基于 PXCap Pro 1.0.0 编写
