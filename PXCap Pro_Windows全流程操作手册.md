# PXCap Pro（Windows 主机）全流程操作手册

本文根据当前项目目录中的产品说明书、PXCap Studio 1.0.0 手册、PxCapPro SDK 1.0.0.0 手册和上位机资源包整理，目标是跑通：开箱与接线 → 设备连接 → 实时验证 → 数据采集 → 质量评分 → 本地归档/上传 → 回放与可视化。

## 0. 关键事实：当前交付物不是 Windows 原生包

项目内只有 Ubuntu/Debian 的 pxcap-studio_1.0.0_amd64.deb、pxhandsdk_1.0.0.0.ubantu2204_amd64.deb、Linux SDK 手册和 URDF；没有 .exe、.msi、Windows SDK .dll 或 Windows 示例。

Windows 电脑的可执行方案：

1. 推荐：在 Windows 上运行 Ubuntu 22.04 x86_64 虚拟机（VMware/VirtualBox）并做 USB 直通；或安装 Ubuntu 双系统。
2. 备选：WSL2 + usbipd-win 直通串口。它适合先读串口数据，但相机/UVC 直通和 GUI 稳定性不如虚拟机；要做“手套 + 腕部相机 + 回放”，优先使用虚拟机/双系统。
3. 如果必须纯 Windows 原生运行，需要向厂商索取 Windows 版 PXCap Studio/SDK；当前目录不能完成这条路线。

本机检查结果（2026-09-30）：WSL 只有 docker-desktop，未安装 Ubuntu；未安装 usbipd-win；当前没有枚举到 PXCap 串口设备，所以尚未进行真实硬件采集。

## 1. Windows → Ubuntu 环境

虚拟机建议分配至少 4 vCPU、8 GB RAM、40 GB 可用磁盘并启用 USB 3.0。把手套 CDC 串口和腕部相机都连接到 Ubuntu 客户机。

Ubuntu 启动后先检查：

    lsusb
    ls -l /dev/ttyACM* 2>/dev/null
    ls -l /dev/video* 2>/dev/null

应看到一个 /dev/ttyACM* 和相机对应的 /dev/video*。没有串口时先不要启动上位机，检查 USB 直通、供电和数据线。

## 2. 安装上位机、SDK 和权限

把项目内两个 .deb 放到 Ubuntu 可访问目录，然后执行：

    sudo apt update
    sudo dpkg -i pxhandsdk_1.0.0.0.ubantu2204_amd64.deb
    sudo apt-get -f install                 # 仅在 dpkg 报依赖缺失时执行
    sudo dpkg -i pxcap-studio_1.0.0_amd64.deb
    sudo /usr/share/pxhandsdk/scripts/setup-serial-access.sh
    sudo usermod -aG video "$USER"         # 使用相机时建议加入 video 组

注销并重新登录 Ubuntu 后确认：

    groups
    dpkg -L pxhandsdk | grep -E 'pxcappro|pxcapPro|examples'
    python3 -c "import pxhandsdk; print(pxhandsdk.PxCapPro)"

上位机可从应用菜单启动，也可执行：

    /opt/PXCap\ Studio/pxcap-studio

启动后将鼠标移到左上角 PX 图标，确认上位机版本 1.0.0 和 SDK 版本。

## 3. 硬件开箱、接线和精度验收

### 3.1 开箱

核对：PXCap Pro 手套、腕部相机及螺丝、零位工装、VR 手柄转接件、备用织物手套、两条小臂束线带、电源适配器、电源线、快速上手指南和合格证。检查外包装、传感器表面、关节/转轴是否有损伤或卡滞。

### 3.2 接线顺序

1. 直流电源断电时，先把 USB 数据线接到手套和 Ubuntu 主机。
2. 将手套电源线接电源适配器，再接电源线和 100–240 V 市电。
3. 等待系统枚举串口，再在上位机中扫描。
4. 断电或换线时反向执行；禁止带电插拔手套电源线。

产品额定工作电压 12 V DC、额定功率 6 W。工作环境 0–50 °C、10–80%RH 且不得凝露；IP20，禁止接触液体、强磁、腐蚀性介质和剧烈冲击。

### 3.3 零位工装精度检查

零位工装下板放在平面，把左/右手套放入对应限位，装上上板并让定位销完全嵌合；按压使手套贴合、各关节锁紧。用上位机实时页或 SDK 读取 17 路角度，所有关节应在 0±3°。不满足时停止使用并联系供应商。工装只用于检测；手套出厂已完成零位标定并带零位记忆，正常情况下无需自行标定。

## 4. PXCap Studio 连接和实时验证

1. 打开左侧“设备管理”，点击“扫描设备”（或等待自动扫描）。
2. 在卡片上核对产品类型为 PXCap Pro、左/右手和当前串口；必要时在未连接状态修正设备类型/串口。
3. 点击“连接”，成功后进入“查看详情”。
4. 先只读确认 SN、主控/传感器版本和连接状态，不要先写 SN 或升级固件。
5. 在“实时数据”页确认 6 路触觉合力/分布力、17 路磁编码器/关节角、通道状态和曲线均在更新。
6. 点击“查看模型”和“查看分布力”，确认三维手部模型、整手分布力窗口有数据。
7. 点击“查看相机”，刷新相机列表，选择对应腕部相机；默认支持 MJPEG，预览帧率按主机性能设置。

“暂停数据同步”只暂停当前界面更新，不会停止设备采样；“暂停曲线更新”也不会停止采集。相机被其他程序占用时先关闭其他摄像头应用。

## 5. 跑通一次完整数据采集

1. 打开“数据采集”，勾选已连接的 PXCap Pro。
2. 为每台设备选择采集频率。该值是落盘目标频率，不保证等于实际帧率；硬件参考采样率为触觉 83.3 Hz、角度 78 Hz。首次用界面提供的中低档频率做稳定性验收，再逐步提高。
3. 如需视频，先在设备详情中选好视频源和 MJPEG/预览帧率。
4. 点击“开始采集”，做一个动作任务，首次建议持续 10 秒以上（评分至少需要约 1 秒共同有效数据）。
5. 观察持续时间、配置频率和落盘状态。
6. 点击“停止采集”，等待“正在停止”结束、质量评分完成和回放索引就绪；评分完成前不要强制退出应用。
7. 在采集记录中查看“评分”。评分检查时间戳、稳定性、同步配对和数据完整度；有视频时还检查视频。总分取各设备/视频结果中的最低分。出现 0 或“不可用”时先看评分详情。
8. 在采集记录点击“回放”，选择会话和设备，用时间轴同步查看视频、URDF 手部模型和整手分布力。

标定维护会独占设备通信：磁编码器检测约 5–6 秒，触觉重新标定约 7 秒；执行前必须停止采集和普通轮询。全部标零会把当前姿态定义为零位，姿态错误会导致后续角度和模型整体偏移。

## 6. 采集文件、数据含义和归档

上位机默认记录目录（Linux 客户机）：

    ~/.config/pxcap-studio/DataLogging/records/

也可在“数据采集”页打开记录目录并修改存储目录。一次会话典型结构：

    <session-id>/
    ├─ manifest.json             # 会话、设备、时间、文件、评分/同步信息
    ├─ <SN>/
    │  ├─ sensor.csv             # 6 路触觉合力 + 分布力 JSON
    │  └─ encoder.csv            # 17 路磁编原始值 + 17 路角度
    ├─ replay/
    │  ├─ replay-index.json
    │  └─ <device-id>/*-camera.mkv 或 *.mp4
    └─ raw/                      # 评分裁剪前的原始 CSV（如生成）

PXCap Pro 主要看 sensor.csv、encoder.csv、manifest.json 和 replay/。CSV 首列为 Timestamp；力值单位为 0.1 N，编码器角度单位为度；分布力按每个区域的有效点数写入 JSON。始终保留 raw、manifest.json 和回放索引，不要只导出截图或单个 CSV。

## 7. “上传数据”的实际做法

当前资料没有云端账号、HTTP 上传地址或自动上传接口；SDK 只负责设备接入和回调，上位机只负责本地落盘、评分和回放。因此上传应按项目的数据管理系统执行：

1. 打开会话目录，确认评分、manifest.json、sensor.csv、encoder.csv、raw/（如生成）和 replay/ 齐全。
2. 停止上位机写入后，把整个 <session-id> 目录复制到 Windows 归档盘或项目服务器，不要只复制一张 CSV。
3. 大文件可先压缩；在 Windows 上校验：
   
       Get-FileHash .\<session-id>.zip -Algorithm SHA256

4. 登记 SHA256、设备 SN、左右手、采集时间、上位机/SDK/固件版本、采集频率、评分和动作说明。
5. 服务端回传后再核对哈希；归档完成前不要在上位机记录区删除。上位机“删除记录”是永久删除。

## 8. 可视化路线

### 8.1 首选：PXCap Studio 回放

在“采集记录 → 回放”中选择会话和设备，使用播放/暂停、前后帧和时间轴查看腕部视频、URDF 手部模型、整手分布力；多设备会话可切换设备。缺失的视频/关节/分布力文件会在对应面板显示“无数据”，其他面板仍可用。

### 8.2 Windows 外部分析

把 sensor.csv 和 encoder.csv 复制到 Windows，用 Excel、Power BI 或 Python（pandas + matplotlib）绘制 Timestamp 对 17 路角度、6 路合力的曲线。解析 sensor.csv 的“分布力JSON”时先按 JSON 展开，再按触觉区域和点位做热力图；绘图前把 0.1 N 原始值乘以 0.1。

### 8.3 URDF 模型

项目中的 PXCap Pro URDF.zip 含左右手 URDF、mesh、关节名 YAML 和 Gazebo/rviz 启动文件。它用于离线模型/仿真显示，不是设备驱动，也不替代上位机实时连接。Windows 侧建议把 URDF 解压到 Ubuntu/ROS 环境或只把 CSV 导出到 Windows 做曲线分析。

## 9. 可选：SDK 只读/连续采集路线

SDK 也只支持 Linux。首次先跑包内示例：

    /usr/bin/python3 /usr/share/pxhandsdk/examples/amd64/python/pxcappro_demo.py /dev/ttyACM0

最小只读调用形态：

    from pxhandsdk import pxcappro

    glove = pxcappro.PxCapPro()
    rc = glove.connect_device('/dev/ttyACM0')
    if rc == 0:
        print(glove.get_sensor_data())
        print(glove.get_encoder_raw_data())
        print(glove.get_encoder_angles())
        glove.disconnect_device()
    else:
        print(glove.get_last_error())

连续采集使用 start_collection(frequency, callback) / stop_collection()（具体参数以交付包中的公开头文件和示例为准）。回调只做快速复制或入队，不能在回调内写盘、网络发送、阻塞等待、调用同一 handle 的其他 API 或销毁 handle。应用必须自己把回调帧写成 CSV/数据库；SDK 不负责业务侧持久化、模态对齐和质量评分。

## 10. 排障顺序

| 现象 | 优先处理 |
|---|---|
| 扫描不到设备 | 确认 12 V 供电、USB 直通、/dev/ttyACM*；重插后重新扫描。 |
| 连接失败/串口忙 | 关闭串口助手、旧 SDK 示例和其他上位机；同一物理设备只能有一个活动连接。 |
| 权限错误 | 重新执行 setup-serial-access.sh，确认用户在 dialout；相机确认 video 组并重新登录。 |
| 实时值不动 | 确认设备仍连接且“数据同步/曲线更新”未暂停。 |
| 相机无画面 | 关闭其他相机应用，刷新相机，确认 MJPEG 源和 /dev/video* 权限。 |
| 评分为 0/不可用 | 确认采集时长 ≥1 秒、必需 CSV 存在、时间戳有效；降低频率/主机负载后重试。 |
| 标定后姿态异常 | 停止业务，按规定姿态重新标零；不要在错误姿态下保存数据。 |
| 升级失败 | 保持供电和连接，等待终态后重新读版本；不要立即反复升级。 |

SDK 常见错误码：100 端口不存在、101 无权限、102 端口忙、103 串口 I/O、105 超时、4000 采集进行中、4010 固件升级中。反馈问题时保留 SDK/固件版本、SN、端口、失败 API、直接返回值、get_last_error()、复现步骤和脱敏日志。

## 11. 最终验收清单

- [ ] Ubuntu 22.04 虚拟机/双系统能看到 /dev/ttyACM* 和相机 /dev/video*。
- [ ] SDK、上位机均为本项目同一交付版本，串口权限已生效。
- [ ] PXCap Pro 连接成功，SN/版本可读，6 路触觉和 17 路角度实时更新。
- [ ] 零位工装检测全部关节在 0±3°。
- [ ] 完成一次 ≥10 秒采集，停止后评分有效且回放索引就绪。
- [ ] 会话目录包含 manifest.json、sensor.csv、encoder.csv、raw/（如生成）和 replay/。
- [ ] 上位机回放能同时看到视频、手部模型和分布力（缺失模态要有记录）。
- [ ] 整个会话已归档/上传并完成 SHA256 校验。
- [ ] 归档确认前没有删除上位机记录。

