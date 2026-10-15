# PXCap Studio 上位机 Ubuntu 22.04 安装操作手册

> 适用设备：PXCap Pro  
> 适用系统：Ubuntu 22.04 LTS 64 位（x86_64 / amd64）  
> 上位机版本：PXCap Studio 1.0.0  
> 安装包：`pxcap-studio_1.0.0_amd64.deb`

## 1. 是否需要单独安装 SDK

如果只使用 PXCap Studio 完成设备连接、实时数据显示、数据采集、质量评分和回放，**不需要单独安装 `pxhandsdk` 开发包，也不需要配置 Python/C++ 开发环境**。

PXCap Studio 安装包已经包含运行上位机所需的 PXCap Pro SDK 动态库和运行库。项目中的 `pxhandsdk_1.0.0.0.ubantu2204_amd64.deb` 只用于自行编写 C++/Python 采集程序，不属于本手册的必装项。

## 2. 安装前准备

### 2.1 系统要求

建议配置：

- Ubuntu 22.04 LTS 桌面版；
- 64 位 Intel/AMD 处理器；
- 8 GB 及以上内存；
- 至少 20 GB 可用磁盘；长期采集应另外规划数据盘；
- 可用 USB 接口；
- 互联网连接，用于首次安装系统依赖；上位机安装完成后，普通采集不依赖互联网。

如果 Ubuntu 运行在 Windows 虚拟机内，需要将 PXCap Pro 的 USB 串口设备和腕部相机直通给 Ubuntu。WSL2 对相机直通支持有限，不建议用于“手套 + 相机”的正式采集。

### 2.2 获取安装包

安装包位于当前交付目录：

```text
PXCap Pro 上位机及使用说明/
└─ pxcap-studio_1.0.0_amd64/
   └─ pxcap-studio_1.0.0_amd64.deb
```

可以使用 U 盘、共享文件夹或局域网把该文件复制到 Ubuntu 的“下载”目录。

### 2.3 检查系统版本和架构

打开终端（`Ctrl+Alt+T`），执行：

```bash
lsb_release -ds
dpkg --print-architecture
uname -m
```

预期结果：

- 系统显示 `Ubuntu 22.04`；
- `dpkg --print-architecture` 显示 `amd64`；
- `uname -m` 显示 `x86_64`。

如果架构是 `arm64` 或 `aarch64`，不能安装当前 amd64 包，需要向供应商索取对应架构版本。

## 3. 安装 PXCap Studio

### 3.1 推荐安装方式

假设安装包位于 Ubuntu 的“下载”目录：

```bash
cd ~/下载
ls -lh pxcap-studio_1.0.0_amd64.deb
sudo apt update
sudo apt install ./pxcap-studio_1.0.0_amd64.deb
```

英文系统的下载目录通常为：

```bash
cd ~/Downloads
```

注意：

- `./` 不能省略，否则 APT 会把文件名当作软件源中的包名；
- 输入 `sudo` 密码时终端不会显示字符，这是正常现象；
- 使用 `apt install ./xxx.deb` 会自动安装缺失依赖，比直接使用 `dpkg -i` 更合适。

安装包声明的主要系统依赖包括：

```text
libgtk-3-0, libnotify4, libnss3, libxss1, libxtst6,
xdg-utils, libatspi2.0-0, libuuid1, libsecret-1-0,
libgbm1, libasound2, udev
```

### 3.2 网络受限时的备用方式

如果已经执行过 `dpkg -i`，但提示依赖未满足，可在网络恢复后执行：

```bash
sudo apt --fix-broken install
sudo apt install ./pxcap-studio_1.0.0_amd64.deb
```

完全离线时，必须提前准备上面列出的 Ubuntu 22.04 amd64 依赖包。不要从其他 Ubuntu 大版本或其他架构混装依赖。

## 4. 配置设备权限

PXCap Pro 通常枚举为 `/dev/ttyACM*` 或 `/dev/ttyUSB*`。腕部相机通常枚举为 `/dev/video*`。

把当前用户加入串口和相机用户组：

```bash
sudo usermod -aG dialout "$USER"
sudo usermod -aG video "$USER"
```

然后**注销 Ubuntu 当前用户并重新登录**。仅关闭终端不够。

重新登录后检查：

```bash
groups
```

输出中应包含：

```text
dialout video
```

不要使用 `sudo chmod 777 /dev/ttyACM0` 作为长期方案：设备重插后节点可能改变，权限也会失效。

## 5. 验证安装

### 5.1 检查软件包

```bash
dpkg -s pxcap-studio | grep -E 'Status|Version|Architecture'
```

预期至少包含：

```text
Status: install ok installed
Version: 1.0.0
Architecture: amd64
```

### 5.2 检查命令和程序目录

```bash
command -v pxcap-studio
ls -l "/opt/PXCap Studio/pxcap-studio"
```

预期命令路径为：

```text
/usr/bin/pxcap-studio
```

## 6. 启动上位机

### 6.1 从桌面启动

按 `Super` 键（Windows 徽标键），搜索：

```text
PXCap Studio
```

点击应用图标启动。

### 6.2 从终端启动

```bash
pxcap-studio
```

也可以直接执行：

```bash
"/opt/PXCap Studio/pxcap-studio"
```

首次排障建议从终端启动，这样可以直接看到启动错误。

启动后，将鼠标移到左上角 PX 图标，确认上位机版本和内置 SDK 版本。

## 7. 连接 PXCap Pro 做首次验证

### 7.1 接线顺序

1. 保持手套直流电源未通电；
2. 使用配套 USB 数据线连接手套和 Ubuntu 主机；
3. 连接手套电源线与 12 V 电源适配器；
4. 电源适配器接入 100–240 V 交流电并上电；
5. 等待约 5–10 秒，让 Ubuntu 完成设备枚举。

禁止在直流电源通电状态下插拔手套电源线。

### 7.2 检查设备节点

```bash
ls -l /dev/ttyACM* /dev/ttyUSB* 2>/dev/null
ls -l /dev/video* 2>/dev/null
```

至少应看到一个串口节点。如果使用腕部相机，还应看到 `/dev/video*`。

还可以执行：

```bash
dmesg --ctime | tail -n 30
```

如果 `dmesg` 提示权限不足，使用：

```bash
sudo dmesg --ctime | tail -n 30
```

### 7.3 在 PXCap Studio 中连接

1. 打开左侧 **设备管理**；
2. 等待自动扫描，或点击 **扫描设备**；
3. 在设备卡片上核对设备类型为 **PXCap Pro**、左右手和串口；
4. 如果自动识别不正确，在未连接状态选择正确型号和串口；
5. 点击 **连接**；
6. 连接成功后，点击 **查看详情**；
7. 在 **实时数据** 页面确认 6 路触觉数据和 17 路关节/磁编码器数据持续更新；
8. 点击 **查看模型**、**查看分布力**，确认三维模型和分布力窗口有数据；
9. 使用相机时，点击 **查看相机**，刷新相机列表并选择腕部相机。

完成以上步骤，表示“安装 → 权限 → 设备枚举 → 上位机连接 → 实时显示”已经跑通。

## 8. 安装后快速采集验证

1. 在设备管理中保持 PXCap Pro 为已连接状态；
2. 打开左侧 **数据采集**；
3. 勾选这台 PXCap Pro；
4. 选择采集频率，首次建议使用界面提供的中低档；
5. 点击 **开始采集**，连续操作至少 10 秒；
6. 点击 **停止采集**；
7. 等待质量评分和回放索引完成，不要在“正在停止”阶段关闭软件；
8. 在采集记录中查看评分；
9. 点击 **回放**，确认视频（如启用）、手部模型和分布力可同步播放。

上位机默认数据目录：

```text
~/.config/pxcap-studio/DataLogging/records/
```

也可以在“数据采集”页面直接打开记录所在目录。

## 9. 常见问题

### 9.1 APT 提示找不到安装包

确认当前目录和文件名：

```bash
pwd
ls -lh
sudo apt install ./pxcap-studio_1.0.0_amd64.deb
```

文件名前必须有 `./`，或使用绝对路径。

### 9.2 提示架构不匹配

执行：

```bash
dpkg --print-architecture
```

当前包只支持 `amd64`。ARM 设备不能使用。

### 9.3 软件已安装，但找不到图标

执行：

```bash
pxcap-studio
```

如果命令可以启动，注销并重新登录桌面，或执行：

```bash
sudo update-desktop-database /usr/share/applications
```

### 9.4 扫描不到设备

按顺序检查：

1. 12 V 电源是否正常；
2. USB 线是否为可传输数据的线，而不是仅充电线；
3. 虚拟机是否已把 USB 设备直通给 Ubuntu；
4. 是否出现 `/dev/ttyACM*` 或 `/dev/ttyUSB*`；
5. 重插 USB 后重新点击扫描；
6. 查看 `sudo dmesg --ctime | tail -n 50`。

### 9.5 连接时报权限不足

检查：

```bash
groups
ls -l /dev/ttyACM* /dev/ttyUSB* 2>/dev/null
```

如果 `groups` 没有 `dialout`，重新执行：

```bash
sudo usermod -aG dialout "$USER"
```

然后注销并重新登录。

### 9.6 提示串口忙或连接失败

关闭所有可能占用设备的程序：

- 另一实例 PXCap Studio；
- 串口助手；
- SDK 示例程序；
- 自研采集程序。

同一个物理设备同一时间只能由一个活动连接控制。必要时重插设备，再根据新枚举的串口重新连接。

### 9.7 相机无法打开

1. 关闭系统相机、浏览器会议页面等占用摄像头的程序；
2. 确认用户在 `video` 组；
3. 检查 `/dev/video*`；
4. 在相机页面刷新设备列表；
5. 优先选择 MJPEG 视频源；
6. 虚拟机环境中确认相机 USB 也已直通给 Ubuntu。

### 9.8 软件启动后黑屏、闪退或 GPU 报错

先从终端启动并保留输出：

```bash
pxcap-studio
```

如果确认是虚拟机图形加速问题，可以仅用于诊断地尝试：

```bash
pxcap-studio --disable-gpu
```

若该方式能启动，应调整虚拟机显卡/3D 加速设置，而不是长期忽略图形问题。

## 10. 更新、重装和卸载

### 10.1 覆盖安装同版本或新版本

```bash
sudo apt install ./pxcap-studio_1.0.0_amd64.deb --reinstall
```

安装新版本时，将文件名替换为实际版本。升级前先停止采集并关闭 PXCap Studio。

### 10.2 卸载软件但保留用户数据

```bash
sudo apt remove pxcap-studio
```

### 10.3 卸载并清除包配置

```bash
sudo apt purge pxcap-studio
```

采集数据位于用户目录，不要假定卸载会自动备份或清理。卸载前先备份：

```text
~/.config/pxcap-studio/DataLogging/records/
```

## 11. 安装验收清单

- [ ] Ubuntu 为 22.04 amd64/x86_64；
- [ ] `sudo apt install ./pxcap-studio_1.0.0_amd64.deb` 无错误完成；
- [ ] `dpkg -s pxcap-studio` 显示已安装、版本 1.0.0；
- [ ] `command -v pxcap-studio` 返回 `/usr/bin/pxcap-studio`；
- [ ] 当前用户属于 `dialout` 和 `video` 组；
- [ ] 手套上电后 Ubuntu 能看到串口节点；
- [ ] PXCap Studio 能扫描并连接 PXCap Pro；
- [ ] 6 路触觉和 17 路姿态数据持续更新；
- [ ] 三维模型、分布力和相机（如使用）能正常显示；
- [ ] 完成一次至少 10 秒的采集、评分和回放。


