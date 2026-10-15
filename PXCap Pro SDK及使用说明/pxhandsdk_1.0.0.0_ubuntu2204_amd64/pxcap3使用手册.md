# PxCap3

# PxCap3 SDK Linux amd64 使用手册

|**修订页**|||
|---|---|---|
|**版本号**|**修订（内容）说明**|**修订时间**|
|V1.0.0.0|同步 1.0.0.0 交付版本与当前公开语义|2026/08|
|V1.0.8|同步当前安装包版本、公开调用约定与在线/离线升级说明|2026/07|
|V1.0.4|完善公开头约定；支持采集和升级期间查询连接状态|2026/07|

**帕西尼感知科技（深圳）有限公司**

对应公开接口与类型头：`include/pxcap3.h`、`include/pxcap3_types.h`（文档版本 `1.0.0.0`，归属 `PaXini SDK Team`）。

---

# 目录

1. **引言**
2. **SDK 简介**
3. **运行前注意事项**
4. **快速使用**
5. **使用介绍**
6. **注意事项**
7. **错误码与排障**
8. **总结**
9. **版权声明**

## 1. 引言

PxCap3 是 PXHandSDK 面向三指数据采集手套提供的 Linux 离线 SDK，也是触觉与手部自体感知数据采集链路中的设备接入组件。它为上位机应用提供稳定的 C ABI 和 Python 接口，用于建立串口通信、读取触觉与编码器数据、执行设备维护，并在需要时启动连续采集或固件升级。

本手册面向应用开发人员、集成工程师和测试人员，覆盖从安装包部署、串口权限配置、设备连接、数据读取到采集、维护和升级的标准流程，说明如何通过 PxCap3 SDK 稳定获取设备侧数据。首次接入时，建议先使用安装包内示例完成端口、供电和数据读取验证，再接入业务程序。

PxCap3 的连续采集和固件升级期间部分接口受限。业务程序应根据接口返回值、`pxcap3_get_last_error()` 的错误信息和回调终态安排调用顺序，并在任务结束后恢复普通操作。错误码含义和逐项排障方法见本手册第 7 章“错误码与排障”。

### 阅读建议

首次接入时，先阅读第 3 章确认设备、串口、并发和回调限制，再按第 4 章运行只读示例；需要接入完整功能时查阅第 5 章，发生错误时按第 7 章排查。

编写程序时，使用当前交付包中的 `pxcap3.h` 和 `pxcap3_types.h` 查询函数参数、数据类型、数组长度、单位和返回值，使用本手册查询设备准备、推荐调用顺序、采集与升级限制和故障处理。不要混用不同版本或不同平台的头文件、库、Python 包、示例和手册。

本文只说明公开 API、输入输出、使用条件和安全事项；设备通信细节及 SDK 处理方式不属于客户接入范围。

## 2. SDK 简介

PxCap3 是 PXHandSDK 中面向三指数据采集手套的设备接入组件，负责将设备输出的触觉、磁编码器、关节角、版本和诊断信息转换为稳定的 C ABI 与 Python 数据对象。开发者可以在统一接口下完成设备连接、单次读取、连续采集、维护检测和固件升级，并将采集结果接入上位机、数据记录系统或后续的数据处理链路。

### 2.1 数据内容

PxCap3 公开数据以固定设备槽位和显式有效数量表示，主要包括以下内容：

|数据类别|具体内容|用途与说明|
|---|---|---|
|触觉合力|10 路固定触觉槽位的 `x/y/z` 三轴合力|用于分析接触方向和整体受力；单位为 `0.1N`。|
|触觉分布力|10 路固定触觉槽位的分布式测点|用于分析接触区域和压力分布；每路应按有效点数读取。|
|磁编码器原始值|4 路公开编码器数据|用于设备状态查看和应用侧数据处理。|
|关节角|4 路磁编码器对应的关节角度|单位为度，用于描述手套关节姿态。|
|连续采集时间戳|Unix 纳秒时间戳与单调纳秒时间戳|由主机在完整帧可用时记录；分别用于外部事件关联和帧间隔计算。|
|设备信息|SDK 版本、设备固件版本、升级源目标版本和设备 SN|用于环境记录、版本核对和设备追溯。|
|诊断信息|传感器故障、磁编码器故障、静态磁检测结果和最近错误|用于设备状态检查和问题定位。|

版本信息中的传感器物理模组与 10 路触觉数据槽位不是同一层级：当前设备版本按 7 个传感器物理模组组织，而公开触觉数据按 10 路数据通道输出。调用方不应使用版本条目下标推导触觉槽位。

### 2.2 核心功能

PxCap3 SDK 提供六类核心功能：

- **会话与连接**：创建和销毁 handle，连接、查询和断开指定 CDC 串口设备；
- **数据读取**：读取触觉聚合数据、合力、分布力、磁编码器原始值、关节角、版本和 SN；
- **连续采集**：按指定目标频率异步输出完整采集帧，并提供主机侧双时间戳；
- **诊断与维护**：读取设备故障，执行磁编码器标零、传感器标零和静态磁检测；
- **固件升级**：支持 HTTP 在线升级和 ZIP 离线升级，通过回调报告进度与最终结果；
- **错误诊断**：通过稳定整数返回值和 `pxcap3_get_last_error()` 获取错误码及本次失败上下文。

### 2.3 对外使用边界

连续采集和固件升级期间部分普通接口不可用，具体以公开返回值和回调终态为准。采集回调应快速复制或转交数据，耗时处理放在回调外完成。

### 2.4 对外接口与集成方式

SDK 以公开 C ABI 作为稳定接口基线，并提供对应的 Python 包装。C / C++ 项目可以通过 CMake package 或 pkg-config 集成；Python 项目统一从 `pxhandsdk.pxcap3` 导入。固定槽位、字段类型、单位、缓冲区容量和回调数据结构以安装包中的公开头文件为准，Python 字段与对应公开 C 数据模型保持一致。

|集成方式|公开入口|适用场景|
|---|---|---|
|C|`pxcap3.h`、`pxcap3_types.h`|需要稳定 C ABI 或跨语言封装的应用。|
|C++|C API + `pxcap3sdk::pxcap3_sdk`|采用 CMake 构建的原生上位机和采集程序。|
|Python|`from pxhandsdk import pxcap3`|数据读取、自动化测试和快速集成。|
|pkg-config|`pxcap3-sdk`|简单编译命令或非 CMake 构建系统。|

### 2.5 DEB 交付与安装目录

PxCap3 随 PXHandSDK Linux 统一 DEB 总包交付。安装后可通过 `dpkg -L pxhandsdk` 查看当前系统中的实际文件清单。

|交付内容|安装位置|用途|
|---|---|---|
|公开头文件|`/usr/include/pxhandsdk/pxcap3.h`、`/usr/include/pxhandsdk/pxcap3_types.h`|C / C++ 编译和公开数据模型查询。|
|动态库|`/usr/lib/pxhandsdk/libpxcap3_sdk.so`|运行时和手工链接使用；安装脚本会执行 `ldconfig`。|
|CMake package|`/usr/lib/cmake/PxCap3SDK/`|供 `find_package(PxCap3SDK CONFIG REQUIRED)` 查找。|
|pkg-config 文件|`/usr/lib/pkgconfig/pxhandsdk/pxcap3-sdk.pc`|供 `pkg-config --cflags --libs pxcap3-sdk` 查找。|
|Python 包|`/usr/lib/python3/pxhandsdk/dist-packages/pxhandsdk/`|包含 `pxhandsdk.pxcap3`；入口 `.pth` 位于 `/usr/lib/python3/dist-packages/`。|
|C++ 示例|`/usr/share/pxhandsdk/examples/amd64/C++/pxcap3_demo.cpp`|C / C++ 接口、错误处理和升级流程参考。|
|Python 示例|`/usr/share/pxhandsdk/examples/amd64/python/pxcap3_demo.py`|Python 接口与数据对象参考。|
|Linux 使用手册|`/usr/share/doc/pxhandsdk/pxcap3使用手册.md`|安装后离线查阅。|

通过上述交付内容，开发者可以完成从设备连接、数据验证到连续采集和维护升级的完整接入。运行约束见第 3 章，快速验证步骤见第 4 章，接口调用示例和详细流程见第 5 章。

## 3. 运行前注意事项

每次启动 PxCap3 应用前，应先确认设备、串口、进程和业务状态满足运行条件。运行前检查的目标不是简单确认“设备已插入”，而是确保同一物理设备只有一个明确的控制方、调用状态可追踪、异常能够安全恢复。

### 3.1 运行前检查清单

|检查项|确认内容|不满足时的处理|
|---|---|---|
|SDK 安装|头文件、动态库、Python 包和示例来自同一版本 DEB。|使用 `dpkg -L pxhandsdk` 核对安装内容，避免混用旧头文件或旧动态库。|
|设备与供电|PxCap3 已稳定上电，USB 线缆和接口连接可靠。|重新连接设备并等待系统枚举稳定。|
|串口节点|已确认本次实际使用的 `/dev/ttyACM*`，未沿用设备重插前的旧路径。|重新枚举设备节点并更新应用配置。|
|访问权限|当前用户属于 `dialout` 组，并具有目标串口读写权限。|重新登录使用户组生效，必要时重新加载随包 udev 规则。|
|端口占用|没有串口助手、旧业务进程或其他 handle 占用同一设备。|关闭占用方；一个物理设备只保留一个活动连接。|
|运行模式|启动普通读取、连续采集、维护或升级前，已确认当前没有冲突任务。|先停止上一种模式并等待其真正结束。|
|日志与存储|已配置错误日志并预留足够存储空间。|降低采集时长或频率，扩充存储，避免在回调中直接写盘。|

### 3.2 串口与 handle 生命周期

- 一个 PxCap3 handle 对应一个设备会话；同一物理串口不应同时被多个进程或多个 handle 打开，否则可能返回 `102`（`SERIAL_BUSY`）。
- `pxcap3_create()` 成功只表示 handle 已创建，不表示设备已连接。在线读取、维护、连续采集和固件升级必须在 `pxcap3_connect()` 返回 `0` 后执行。
- `pxcap3_is_connected()` 用于查询当前连接状态；升级或设备状态变化期间应以接口返回值和回调终态为准。
- 设备断开、I/O 错误或 USB 重插后，应停止当前业务循环，重新确认端口并建立连接；不要在失效 handle 上持续高频重试。
- 销毁 handle 前，应停止连续采集和新的调用，再执行断开和销毁。
- 普通模式下的多个调用方应由应用统一安排访问顺序，避免同一 handle 上的调用交错。

### 3.3 调用状态与互斥关系

|当前状态|允许的主要操作|限制与返回值|
|---|---|---|
|handle 已创建、设备未连接|SDK 版本查询、连接、连接状态查询、最近错误查询；可配置并解析离线 ZIP 升级源。|在线设备读取、维护、采集和启动升级需要先连接。|
|已连接、普通模式|设备信息与数据读取、诊断维护、启动连续采集、配置或启动升级。|同一 handle 的操作应由业务层有序安排。|
|连续采集中|`pxcap3_is_connected()`、`pxcap3_stop_collection()`、`pxcap3_disconnect()`、`pxcap3_get_last_error()`。|除 `disconnect` 会先停止采集再断开外，其他受限接口可能返回 `4000`（`COLLECTION_ACTIVE`），以返回值和回调终态为准。|
|固件升级中|`pxcap3_is_connected()`、`pxcap3_cancel_upgrade()`、`pxcap3_get_last_error()`。|其他普通接口返回 `4010`（`FIRMWARE_UPGRADING`）。|
|连接丢失或通信异常|错误查询、停止业务任务和重新连接流程。|不得继续使用失败调用对应的输出数据。|

采集停止和升级取消的完成语义不同：`pxcap3_stop_collection()` 返回 `0` 后可以恢复普通调用；`pxcap3_cancel_upgrade()` 返回 `0` 只表示取消请求已被接受，仍需等待升级回调终态。

### 3.4 回调约束

- 连续采集回调应只完成数据复制或快速转交，不执行文件写入、网络发送、耗时处理或阻塞等待。
- 回调内只做快速数据处理；不要调用同一 handle 的其他 PxCap3 API，也不要同步停止采集或销毁 handle。
- C++ 与 Python 回调都应捕获自身异常，不能让异常越过 C ABI 边界。
- 回调收到的数据指针只在本次回调期间有效；异步处理必须复制数据，不能长期保存 SDK 提供的指针。
- 回调数据如需长期保存，应复制到应用管理的对象；应用自行负责存储容量和丢帧记录。

### 3.5 数据有效性与单位

- 只有返回 `int` 的接口返回 `0` 时，本次输出数据才有效。失败后调用 `pxcap3_get_last_error()` 获取原因；成功调用不会清除之前保存的失败记录。
- 力值 `x/y/z` 的单位均为 `0.1N`，其中 `x/y` 为有符号分量，`z` 为无符号分量。
- 触觉数据按 10 路固定数据通道输出；版本信息当前按 7 个传感器物理模组组织，两者不能通过下标直接互相推导。
- 公开版本数组容量为 8，必须以 `sensor_version_count` 为有效条目数；分布力数组也必须按每路有效点数读取。
- 连续采集时间戳表示主机侧帧可用时间，不是设备硬件采样时间。Unix 时间戳用于外部事件关联，单调时间戳用于计算帧间隔。
- 不要在失败后继续使用输出结构中的旧值，也不要将上一次成功数据标记为本次读取结果。

### 3.6 维护与升级前置条件

- 标定、静态磁检测、写 SN 和固件升级会改变设备状态或持久化内容，执行前必须停止普通轮询与连续采集。
- 磁编码器标零和传感器标零前，应确认设备处于对应操作要求的姿态，并避免外力干扰。
- 静态磁检测期间设备应保持静止；触发后约等待 6 秒再读取结果，状态全部为 `0` 才表示通过。
- 离线升级使用交付说明规定的 ZIP 来源。
- 在线升级前应确认 HTTP 地址和网络可用；升级过程中严禁断电、拔线、关闭进程、主机休眠或并发访问串口。
- 升级接口同步返回 `0` 只表示任务已启动，最终结果必须以升级回调的成功、失败或取消终态为准。

### 3.7 异常处理准备

应用启动前应统一错误记录格式，至少包含时间戳、产品、设备 SN、串口、API 名称、直接返回值、`get_last_error()` 错误码及 `message`。发生异常后，应采用“停止业务调用 → 保存错误上下文 → 判断设备是否仍连接 → 必要时重新枚举和连接 → 只读验证 → 恢复业务”的顺序，不要通过无限重试掩盖设备或通信问题。

## 4. 快速使用

本章引导开发者完成 PxCap3 的首次接入，包括环境确认、DEB 安装、串口权限配置以及 C++ / Python 基础数据验证。PxCap3 是本地设备 SDK，不依赖 GPU、Docker、NVIDIA Container Toolkit、Conda、Isaac Sim 或 Open MPI。普通数据读取和 ZIP 离线升级不要求网络连接，只有 HTTP 在线固件升级需要访问升级服务器。

### 4.1 推荐环境

当前 Linux 统一 DEB 的推荐运行环境如下：

```text
操作系统：Ubuntu 22.04 LTS 64-bit
处理器架构：x86_64（amd64）
内存：推荐 8GB 及以上
可用磁盘：推荐 20GB 及以上；长期采集数据应单独规划存储空间
设备连接：可用 USB 接口，系统能够枚举 CDC 串口 /dev/ttyACM*
C++：支持 C++17 的编译器
CMake：推荐 3.22 及以上
Python：系统 CPython >= 3.10 且 < 3.11
GPU：不需要
网络：仅 HTTP 在线固件升级需要
```

以上磁盘容量包含 SDK、开发工具、示例构建和运行日志的预留空间，不代表连续采集数据的长期存储需求。实际数据容量取决于采集频率、采集时长和业务保存格式。

### 4.2 准备系统依赖

仅运行已编译程序时，DEB 会声明所需运行时依赖。若需要编译安装包内的 C++ 示例，建议安装以下开发工具：

```bash
sudo apt update
sudo apt install -y build-essential cmake pkg-config
```

DEB 当前使用系统 CPython 3.10 运行 Python 绑定。不要默认将其他 CPython 小版本或 Conda 环境视为已验证环境；若业务必须使用其他 Python 环境，应先完成独立兼容性验证。

### 4.3 安装统一 DEB

在 DEB 所在目录执行：

```bash
sudo dpkg -i pxhandsdk_1.0.0.0.ubantu2204_amd64.deb
```

如果系统缺少 DEB 声明的依赖，并且当前软件源可用，可执行：

```bash
sudo apt-get -f install
```

在完全离线环境中，应提前准备 `libc6`、`libstdc++6`、系统 Python 3.10 和 `unzip` 等依赖包。安装完成后可检查 PxCap3 交付内容：

```bash
dpkg -L pxhandsdk | grep -E 'pxcap3|PxCap3SDK'
python3 -c "import pxhandsdk; print(pxhandsdk.pxcap3)"
```

完整安装目录见 2.5 节。

#### tar.gz 免安装方式

tar.gz 与 DEB 是同版本、同架构的两种部署方式。tar.gz 不写入 `/usr`，也不自动注册 Python 或
安装 udev 规则：

```bash
tar -xzf pxhandsdk_1.0.0.0.ubantu2204_amd64.tar.gz
export PXHANDSDK_ROOT="$PWD/pxhandsdk_1.0.0.0.ubantu2204_amd64"
export LD_LIBRARY_PATH="$PXHANDSDK_ROOT/lib/pxhandsdk:$PXHANDSDK_ROOT/lib/pxhandsdk/core${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export PYTHONPATH="$PXHANDSDK_ROOT/lib/python3/pxhandsdk/dist-packages${PYTHONPATH:+:$PYTHONPATH}"
```

编译包内 C++ 示例时使用 `-DCMAKE_PREFIX_PATH="$PXHANDSDK_ROOT"`；示例位于
`$PXHANDSDK_ROOT/share/pxhandsdk/examples/amd64/`。完整命令见 tar.gz 根目录 `README.md`。

### 4.4 配置串口权限

安装包提供串口权限配置脚本，可将当前登录用户加入 `dialout` 组并重新加载 udev 规则：

```bash
sudo /usr/share/pxhandsdk/scripts/setup-serial-access.sh
```

也可手动执行：

```bash
sudo usermod -aG dialout $USER
```

完成后必须注销并重新登录，使新的用户组权限生效。重新登录后检查：

```bash
groups
ls -l /dev/ttyACM* 2>/dev/null
```

不要把 `chmod 777` 作为正式部署方案；正式环境应使用 `dialout` 用户组和随包 udev 规则管理权限。

### 4.5 连接设备并确认串口

将 PxCap3 通过 USB 连接至主机并稳定供电，然后确认设备节点：

```bash
ls -l /dev/ttyACM*
```

示例中的 `/dev/ttyACM0` 必须替换为实际枚举到的设备节点。设备重插后端口号可能变化；如果未出现预期节点，应先检查供电、线缆、USB 接口和系统枚举状态，不要直接沿用历史端口路径。

### 4.6 安装示例的编译与运行

DEB 同时安装 C++ 和 Python 示例。两个 PxCap3 示例默认只执行设备查询和数据读取；首次验证建议保持只读。

#### C++ 示例

```bash
cp -r /usr/share/pxhandsdk/examples/amd64/C++ "$PWD/pxhandsdk-cpp-examples"
cmake -S "$PWD/pxhandsdk-cpp-examples" -B "$PWD/pxhandsdk-cpp-examples/build" \
  -DCMAKE_PREFIX_PATH=/usr
cmake --build "$PWD/pxhandsdk-cpp-examples/build" --target pxcap3_demo -j
"$PWD/pxhandsdk-cpp-examples/build/pxcap3_demo" /dev/ttyACM0
```

使用 tar.gz 时：

```bash
cp -r "$PXHANDSDK_ROOT/share/pxhandsdk/examples/amd64/C++" "$PWD/pxhandsdk-cpp-examples"
cmake -S "$PWD/pxhandsdk-cpp-examples" -B "$PWD/pxhandsdk-cpp-examples/build" \
  -DCMAKE_PREFIX_PATH="$PXHANDSDK_ROOT"
cmake --build "$PWD/pxhandsdk-cpp-examples/build" --target pxcap3_demo -j
"$PWD/pxhandsdk-cpp-examples/build/pxcap3_demo" /dev/ttyACM0
```

#### Python 示例

```bash
/usr/bin/python3 /usr/share/pxhandsdk/examples/amd64/python/pxcap3_demo.py /dev/ttyACM0
```

tar.gz 运行命令为：

```bash
/usr/bin/python3 "$PXHANDSDK_ROOT/share/pxhandsdk/examples/amd64/python/pxcap3_demo.py" /dev/ttyACM0
```

在线和离线升级分别使用 HTTP 地址或 ZIP 包作为升级源；标定、静态磁检测和写 SN 等能力会改变设备状态，应在只读验收完成后按第 3、5 章通过公开 API 执行。

### 4.7 C++ 只读验证

上述 C++ 示例的默认路径就是完整只读验证，覆盖 SDK/固件版本、SN、触觉、磁编码器、关节角、故障和正常断开。也可单独复制源文件后用 pkg-config 编译：

```bash
cp /usr/share/pxhandsdk/examples/amd64/C++/pxcap3_demo.cpp ./
export PKG_CONFIG_PATH="/usr/lib/pkgconfig/pxhandsdk${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"
c++ -std=c++17 pxcap3_demo.cpp -o pxcap3_demo \
  $(pkg-config --cflags --libs pxcap3-sdk)
./pxcap3_demo /dev/ttyACM0
```

每项接口返回 `0` 且最终断开成功，才表示该项通过；任何失败都应立即查看 `pxcap3_get_last_error()`，失败调用的输出不能继续使用。

### 4.8 Python 只读验证

以下代码完成 Python 包导入、设备连接、传感器读取、错误查询和正常断开：

```bash
python3 - <<'PY'
from pxhandsdk import pxcap3

glove = pxcap3.PxCap3()
rc = glove.connect_device('/dev/ttyACM0')
print(f'connect rc={rc}')

if rc == 0:
    rc, data = glove.get_sensor_data()
    if rc == 0:
        force = data.thumb_one_force.resultant_force
        print(f'thumb_one force: x={force.x}, y={force.y}, z={force.z}')
    else:
        print('get_sensor_data failed:', glove.get_last_error())
    glove.disconnect_device()
else:
    print('connect failed:', glove.get_last_error())
PY
```

只有接口返回 `0` 时才能使用本次输出数据。连接、读取或断开失败时，应记录直接返回值以及 `get_last_error()` 的错误码和 `message`，再按第 7 章排查。

### 4.9 C++ 项目集成

```cmake
cmake_minimum_required(VERSION 3.16)
project(my_pxcap3_app LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)

find_package(PxCap3SDK REQUIRED CONFIG)
add_executable(my_pxcap3_app main.cpp)
target_link_libraries(my_pxcap3_app PRIVATE pxcap3sdk::pxcap3_sdk)
```

```bash
cmake -S . -B build -DCMAKE_PREFIX_PATH=/usr
cmake --build build -j
./build/my_pxcap3_app /dev/ttyACM0
```

### 4.10 Python 项目集成

Python 无需链接 CMake target，也不要从 PyPI 安装同名包。DEB 安装后直接导入：

```python
import pxhandsdk

glove = pxhandsdk.PxCap3()
# 等价写法：glove = pxhandsdk.pxcap3.PxCap3()
```

```bash
/usr/bin/python3 -c "import pxhandsdk; print(pxhandsdk.PxCap3)"
/usr/bin/python3 -m venv --system-site-packages .venv
.venv/bin/python -c "import pxhandsdk; print(pxhandsdk.PxCap3)"
```

Conda、不同 CPython 小版本或未启用 `--system-site-packages` 的 venv 默认看不到 DEB 绑定。正式部署应使用 `/usr/bin/python3`，或使用同版本系统 Python 创建上述虚拟环境。

### 4.11 首次接入验收

完成快速使用后，应至少确认以下结果：

- `import pxhandsdk` 和 `pxhandsdk.pxcap3` 可正常使用；
- 当前用户拥有目标串口的读写权限；
- C++ 或 Python 示例能够连接正确的 PxCap3 设备；
- 能够成功读取一帧触觉数据，并按返回值判断数据是否有效；
- 程序退出前能够正常断开设备，且没有其他进程继续占用串口。

首次验证仅执行只读操作。连续采集、标定、静态磁检测、写 SN 和固件升级应在理解第 3 章约束与第 5 章流程后再启用。

## 5. 使用介绍

本章从 PxCap3 的公开数据模型出发，说明各类 API 的输入、输出和使用流程。PxCap3 返回的是实时设备数据与设备状态，不负责将数据写入 HDF5、DF-1、DF-2、DF-2R 或 DF-3，也不执行视觉解析、位姿估计、数据重定向和可视化回放。若上层系统需要这些能力，应在复制 SDK 输出后自行完成数据组织与后处理。

### 5.1 数据基础信息

PxCap3 的单次读取由触觉、磁编码器、关节角、设备信息和诊断信息组成；连续采集帧则将触觉、编码器、关节角和主机侧时间戳组合为一个回调对象。

|数据对象|公开类型|主要内容|
|---|---|---|
|完整触觉数据|`PxCap3SensorData`|10 路固定槽位，每路包含三轴合力、分布力数组和有效点数。|
|触觉合力|`PxCap3SensorResultantForce`|10 路固定槽位的 `x/y/z` 三轴合力。|
|触觉分布力|`PxCap3SensorDistributeForce`|10 路固定槽位的分布力数组及每路有效点数。|
|编码器原始值|`PxCap3EncoderRaw`|4 路公开编码器数据。|
|关节角|`PxCap3EncoderAngles`|与 4 路编码器对应的角度值，单位为度。|
|连续采集帧|`PxCap3CollectionData`|编码器、关节角、10 路合力、10 路分布力及两类主机时间戳。|
|设备版本|`PxCap3VersionInfo`|主控版本、传感器版本数组和有效版本数量。|
|设备故障|`PxCap3FaultInfo`|传感器故障项和磁编码器故障项。|
|升级进度|`PxCap3UpgradeProgress`|当前阶段、步骤进度、总体进度、固件名称、索引、总数和消息。|

#### 5.1.1 触觉数据槽位

触觉数据固定按以下 10 路数据通道组织。单个分布力点由 `x/y/z` 三个分量构成，单位为 `0.1N`；`x/y`
使用 `int8_t`，取值范围为 `-128..127`；`z` 使用 `uint8_t`，取值范围为 `0..255`。

|顺序|槽位字段|当前分布力有效点数|
|---:|---|---:|
|1|`thumb_one`|49|
|2|`thumb_two`|20|
|3|`index_zero`|49|
|4|`index_one`|20|
|5|`middle_zero`|49|
|6|`middle_one`|20|
|7|`middle_two`|49|
|8|`middle_three`|20|
|9|`palm_zero`|119|
|10|`palm_one`|49|

10 路槽位合计包含 444 个分布力点。公开结构为兼容不同槽位，单路数组容量统一按最大值 119 定义；调用方必须使用每路 `distribute_force_count` 或 `count` 读取有效数据，不能遍历全部容量。

#### 5.1.2 编码器与关节角

4 路编码器及角度字段使用相同顺序：

|顺序|字段|含义|
|---:|---|---|
|1|`index_proximal`|食指指腹磁编码器。|
|2|`index_distal`|食指指尖磁编码器。|
|3|`middle_proximal`|中指指腹磁编码器。|
|4|`middle_distal`|中指指尖磁编码器。|

磁编码器原始值和关节角均按公开接口返回；关节角单位为度。

#### 5.1.3 连续采集帧与时间戳

`PxCap3CollectionData` 每帧包含 4 路编码器原始值、4 路关节角、10 路合力、10 路分布力，以及：

- `timestamp_unix_ns`：主机 Unix 纳秒时间，用于和其他系统事件建立时间关联；
- `timestamp_monotonic_ns`：主机单调纳秒时间，用于计算帧间隔，不受系统校时影响。

两类时间戳表示主机侧帧可用时间，不是设备硬件采样时间。

### 5.2 功能模块与接口

本节按业务职责覆盖全部 PxCap3 公开接口。表中 Python 方法与对应 C API 使用相同设备语义；Python 对象负责持有设备实例，C / C++ 调用方则必须显式管理 handle 生命周期。

通用限制如下：

- 除创建和销毁外，返回 `int` 的接口均以 `0` 表示成功；只有成功时才能使用本次输出数据。
- 连续采集期间，除连接状态、停止采集、断开连接和读取最近错误外，其他接口返回 `4000`；断开连接会先停止采集。
- 固件升级期间，除连接状态、请求取消和读取最近错误外，其他普通接口返回 `4010`。
- 凡是会与设备通信的读取、写入、诊断、维护和启动升级接口，均要求先成功连接。创建/销毁、SDK 版本查询、连接状态查询、最近错误查询以及升级源配置不依赖设备在线；离线目标版本解析也不要求连接，但在线目标版本查询需要连接设备以识别传感器型号。

#### 5.2.1 会话与连接模块

|C API / Python|属性|功能与限制|
|---|---|---|
|`pxcap3_create()` / `PxCap3()`|创建|创建一个独立会话；C 返回空指针表示创建失败。创建成功不代表设备已连接。|
|`pxcap3_destroy()` / Python 对象析构|销毁|释放会话资源。C 接口允许空指针；销毁前应停止采集并停止新的调用。|
|`pxcap3_connect()` / `connect_device()`|连接|连接非空串口路径。一个物理串口只允许一个活动连接；成功后才能执行在线设备操作。|
|`pxcap3_is_connected()` / `is_connected()`|读取|查询当前连接状态；任务运行期间以接口返回值和回调终态为准。|
|`pxcap3_disconnect()` / `disconnect_device()`|断开|采集中先停止采集，再断开设备并重置连接相关状态；升级中需等待终态。|
|`pxcap3_get_last_error()` / `get_last_error()`|读取|读取最近一次失败的错误码和消息；采集或升级期间也允许调用。成功调用不会清除历史失败记录。|

#### 5.2.2 版本模块

|C API / Python|属性|功能与限制|
|---|---|---|
|`pxcap3_get_sdk_version()` / `get_sdk_version()`|读取|返回 SDK 语义版本和打包时间。C 调用方提供输出缓冲区，容量不足时不会写入截断字符串。|
|`pxcap3_get_firmware_versions()` / `get_firmware_versions()`|读取|读取设备当前主控和传感器固件版本；要求设备已连接，并以 `sensor_version_count` 判断有效条目。|

设备当前版本与升级源目标版本是两类不同信息。目标版本应通过升级模块的 `get_upgrade_package_versions()` 查询。

#### 5.2.3 SN 模块

|C API / Python|属性|功能与限制|
|---|---|---|
|`pxcap3_get_sn()` / `get_sn()`|读取|读取设备当前 SN；要求已连接。C 输出缓冲区建议至少 33 字节，用于容纳最多 32 字节 SN 和结尾 NUL 字符。|
|`pxcap3_set_sn()` / `set_sn()`|写入|将 SN 持久化到设备；要求已连接。输入不能为空，最大 32 字节，且必须是正确结束的字符串。|

写 SN 会修改设备持久化信息，应限制为授权维护流程。写入成功后建议立即调用读取接口核对，并在业务系统中记录操作者、时间和新旧 SN。

#### 5.2.4 触觉模块

|C API / Python|属性|功能与限制|
|---|---|---|
|`pxcap3_get_sensor_data()` / `get_sensor_data()`|读取|一次读取 10 路合力和分布力，适合需要完整触觉帧的场景。|
|`pxcap3_get_sensor_resultant_force()` / `get_sensor_resultant_force()`|读取|仅读取并返回 10 路三轴合力，适合无需分布力的业务。|
|`pxcap3_get_sensor_distribute_force()` / `get_sensor_distribute_force()`|读取|仅读取 10 路分布力；每路必须按 `count` 使用有效点，不能遍历统一最大容量。|

三类接口都要求已连接，且不能在连续采集或升级期间调用。力值单位为 `0.1N`。如果同一业务周期同时需要合力和分布力，优先使用一次完整读取，避免重复设备通信。

#### 5.2.5 编码器模块

|C API / Python|属性|功能与限制|
|---|---|---|
|`pxcap3_get_encoder_raw_data()` / `get_encoder_raw_data()`|读取|读取 4 路公开编码器数据。|
|`pxcap3_get_encoder_angles()` / `get_encoder_angles()`|读取|读取 4 路关节角，单位为度。|

两类接口都要求已连接，字段顺序固定为 `index_proximal`、`index_distal`、`middle_proximal`、`middle_distal`。标零会改变后续原始值和角度的参考零点。

#### 5.2.6 连续采集模块

|C API / Python|属性|功能与限制|
|---|---|---|
|`pxcap3_start_collection()` / `start_collection()`|启动|按目标频率异步输出完整帧；要求已连接、频率大于 0 且回调有效，建议不超过 `300Hz`。|
|`pxcap3_stop_collection()` / `stop_collection()`|停止|停止采集并等待停止完成；未启动采集时返回成功。不得在采集回调中同步调用。|

采集期间部分接口不可用。回调只能快速复制或转交数据；不要调用同一 handle 的其他接口、阻塞等待、写文件或执行耗时处理。

#### 5.2.7 故障诊断模块

|C API / Python|属性|功能与限制|
|---|---|---|
|`pxcap3_get_fault_code()` / `get_fault_code()`|读取|返回传感器故障项和磁编码器故障项；要求已连接。应分别按两类有效数量遍历，不要读取数组容量之外或无效区域。|

故障查询结果描述设备当前报告的异常项；API 返回失败则表示本次故障信息本身不可用，应先处理通信或参数错误。
`source_name` 始终以 `\0` 结尾，`source_index` 是对应设备槽位从 0 开始的索引。
`sensor_fault_count` 不超过 10，`magnetic_encoder_fault_count` 不超过 4；请只遍历有效项数。

#### 5.2.8 标定与维护模块

|C API / Python|属性|功能与限制|
|---|---|---|
|`pxcap3_set_encoder_calibration()` / `set_encoder_calibration()`|写入|执行磁编码器标零；要求已连接。执行前停止轮询并确认设备姿态，完成后重新读取编码器验证。|
|`pxcap3_set_sensor_calibration()` / `set_sensor_calibration()`|写入|执行传感器标零；要求已连接。操作期间不应读取触觉数据，完成后重新读取确认。|
|`pxcap3_set_static_magnet_check()` / `set_static_magnet_check()`|触发|启动静态磁检测；要求已连接，触发后设备保持静止约 6 秒。|
|`pxcap3_get_static_magnet_check()` / `get_static_magnet_check()`|读取|读取 4 路检测状态：`0` 正常、`1` 异常、`2` 检测中；全部为 `0` 才表示通过。|

维护接口会改变设备状态或检测流程，不能和普通轮询、连续采集或升级并发。业务侧应记录维护操作前后的版本、SN、状态和结果。

#### 5.2.9 固件升级模块

|C API / Python|属性|功能与限制|
|---|---|---|
|`pxcap3_set_upgrade_online_address()` / `set_upgrade_online_address()`|配置|保存非空 HTTP 基础地址，不会立即启动升级。在线目标版本查询时设备需连接，以识别传感器型号。|
|`pxcap3_set_upgrade_offline_package()` / `set_upgrade_offline_package()`|配置|保存非空本地 ZIP 路径，不会立即启动升级。|
|`pxcap3_get_upgrade_package_versions()` / `get_upgrade_package_versions()`|读取|读取升级源目标版本。在线模式要求连接；离线模式可在未连接时解析 ZIP。必须传入与已配置来源一致的模式。|
|`pxcap3_upgrade_firmware()` / `upgrade_firmware()`|启动|异步启动全量升级；要求设备已连接、来源已配置、模式匹配且回调有效。同步返回 `0` 不代表升级完成。|
|`pxcap3_cancel_upgrade()` / `cancel_upgrade()`|控制|请求取消当前升级；无活动升级时为成功 no-op。返回成功仅表示请求已接受，仍需等待升级回调终态。|

升级进度回调通过公开字段报告阶段、进度、消息和终态。应用应以 `SUCCESS`、失败或取消终态判断结果，并从 `message` 获取可展示的原因。

### 5.3 基础调用流程

```text
创建 handle -> 连接设备 -> 查询设备信息 -> 读取数据或启动采集
      -> 停止后台任务 -> 断开设备 -> 销毁 handle
```

每个返回 `int` 的接口都应检查返回值。任一调用失败后，应停止依赖该结果的后续操作，读取最近错误，并且不再使用该次调用对应的输出结构。

### 5.4 C / C++ 使用

使用 CMake 集成：

```cmake
find_package(PxCap3SDK REQUIRED CONFIG)
target_link_libraries(app PRIVATE pxcap3sdk::pxcap3_sdk)
```

最小生命周期与触觉读取示例：

```cpp
#include <pxcap3.h>

pxcap3_handle_t* handle = pxcap3_create();
if (handle == nullptr) return -1;

int rc = pxcap3_connect(handle, "/dev/ttyACM0");
const bool connected = rc == 0;
if (connected) {
  PxCap3SensorData sensor{};
  rc = pxcap3_get_sensor_data(handle, &sensor);
  if (rc == 0) {
    // 按 sensor.thumb_one_force.distribute_force_count 使用有效数据。
  }
}
if (rc != 0) {
  PxCap3ErrorInfo error{};
  pxcap3_get_last_error(handle, &error);
  // 记录 error.code 和 error.message。
}
if (connected) pxcap3_disconnect(handle);
pxcap3_destroy(handle);
```

完整示例见 `/usr/share/pxhandsdk/examples/amd64/C++/pxcap3_demo.cpp`。

### 5.5 Python 使用

```python
from pxhandsdk import pxcap3

glove = pxcap3.PxCap3()
rc = glove.connect_device('/dev/ttyACM0')
if rc != 0:
    raise RuntimeError(f'connect failed: {glove.get_last_error()}')

rc, sensor = glove.get_sensor_data()
if rc == 0:
    force = sensor.thumb_one_force.resultant_force
    print(force.x, force.y, force.z)
else:
    print('read failed:', glove.get_last_error())

glove.disconnect_device()
```

Python 返回的数据、版本和状态对象仅在对应调用返回 `0` 时有效。完整示例见 `/usr/share/pxhandsdk/examples/amd64/python/pxcap3_demo.py`。

### 5.6 连续采集模块

连续采集按目标频率读取编码器、关节角和触觉数据，并通过回调输出组合帧。建议频率不超过 `300Hz`；实际帧率受设备处理时间、系统负载和其他运行条件影响。

```text
start_collection(frequency, callback)
        -> 公开采集回调
        -> callback(frame)
        -> 调用方快速复制或入队
        -> 应用保存或处理
        -> stop_collection()
```

Python 示例：

```python
import time
from pxhandsdk import pxcap3

def on_frame(frame: pxcap3.PxCap3CollectionData) -> None:
    force = frame.resultant_force.thumb_one
    snapshot = (
        frame.timestamp_unix_ns,
        frame.timestamp_monotonic_ns,
        force.x,
        force.y,
        force.z,
    )
    print(snapshot)

glove = pxcap3.PxCap3()
if glove.connect_device('/dev/ttyACM0') == 0:
    if glove.start_collection(100, on_frame) == 0:
        time.sleep(1.0)
        glove.stop_collection()  # 必须在回调外调用。
    glove.disconnect_device()
```

采集期间部分接口可能返回 `4000`（`COLLECTION_ACTIVE`）。回调中仅复制或转交数据，不要调用同一 handle 的其他 PxCap3 API；若需要长期使用帧数据，应复制到调用方管理的对象。

### 5.7 诊断与维护模块

- `pxcap3_get_fault_code()` 返回传感器和磁编码器故障汇总；业务应同时检查有效故障数量和每项设备状态值。
- `pxcap3_set_encoder_calibration()` 执行磁编码器标零，完成后重新读取编码器原始值和角度确认结果。
- `pxcap3_set_sensor_calibration()` 执行传感器标零，期间停止触觉轮询，完成后重新读取传感器数据。
- `pxcap3_set_static_magnet_check()` 触发静态磁检测；保持设备静止约 6 秒后，通过 `pxcap3_get_static_magnet_check()` 读取 4 路状态。`0` 为正常、`1` 为异常、`2` 为检测中。
- `pxcap3_set_sn()` 会持久化设备 SN，字符串不能为空，最大为 32 字节且必须正确结束。

维护操作的统一流程为：停止采集和轮询 -> 确认姿态与供电 -> 执行操作 -> 检查返回值 -> 重新读取相关状态 -> 恢复业务。

### 5.8 固件升级模块

|模式|升级源|版本查询前提|启动升级前提|
|---|---|---|---|
|在线|HTTP 基础地址|先设置在线地址并选择在线模式。|按回调终态判断结果。|
|离线|交付说明规定的 ZIP 来源|先设置 ZIP 路径并选择离线模式。|启动升级前设备必须连接，并传入回调。|

`pxcap3_get_firmware_versions()` 返回当前设备已安装版本；`pxcap3_get_upgrade_package_versions()` 返回升级源中的目标版本，两者不能混用。查询版本和启动升级必须传入与已设置升级源一致的模式。

`pxcap3_upgrade_firmware()` 返回 `0` 只表示异步任务已启动。最终结果必须以回调的成功、失败或取消终态为准。升级期间，除连接状态、取消升级和查询最近错误外，其他普通接口返回 `4010`；连接状态查询成功不代表升级串口当前可用于普通通信，取消请求被接受后仍需等待回调终态。

### 5.9 错误处理

同步接口失败时，通过直接返回值和 `pxcap3_get_last_error()` 判断原因；连续采集和升级的异步失败还应结合回调终态及 `message`。推荐统一记录：API 名称、返回值、错误码、错误消息、串口、设备 SN、运行模式和时间戳。完整错误码与处理建议见第 7 章。

## 6. 注意事项

### 6.1 上线前检查

在将 SDK 接入正式业务前，建议至少完成以下检查：

- 确认目标 Linux 用户已具备串口访问权限，且设备重插后可正确识别新的端口节点；
- 使用安装包内示例完成一次连接、传感器读取、编码器读取和断开验证；
- 确认业务侧对所有非零返回值都会记录 `get_last_error()` 的 `code` 与 `message`；
- 确认采集回调只做轻量数据转交，且停止采集、销毁 handle、文件写入和网络发送均不在回调中执行；
- 为端口断开、设备重插、进程重启和升级失败设计可控的恢复流程，而不是无限重试。

### 6.2 供电、线缆与设备状态

- 读取异常、间歇超时或传感器解析失败时，先检查供电、USB 线缆、转接器和接口松动，再检查软件调用顺序。
- 不要在设备未稳定上电、正在枚举或端口频繁变化时持续创建连接；等待设备节点稳定后再连接。
- 标定、静态磁检测、写 SN 和固件升级前，应保证设备处于允许操作的姿态和状态，并由业务侧禁止其他人员或进程同时访问设备。

### 6.3 采集数据使用

- 连续采集目标频率不等于必然获得的实际帧率；应使用回调中的单调时间戳计算实际帧间隔，并记录异常和处理耗时。
- 回调数据应在本次回调内复制到调用方管理的对象。不要保存 SDK 回调指针。
- 若业务需要可追溯数据，建议同时记录 Unix 时间戳、单调时间戳、产品线、设备 SN、端口、SDK 版本和采集配置。
- 接口失败时，本次输出数据不应写入业务记录或用于控制决策；不要将上一次成功数据误标记为本次采集结果。

### 6.4 维护与固件升级

- 静态磁检测、标定、写 SN 和固件升级均可能改变设备状态或设备内持久化内容；执行前应完成业务确认和必要的数据备份。
- 升级期间严禁拔线、断电、关闭进程、休眠主机或并发访问该串口。升级回调未到达终态前，设备仍可能处于不可进行普通通信的状态。
- 在线升级前核对地址可访问；离线升级前按交付说明核对 ZIP 来源。
- 升级失败或取消后，先读取最近错误和重新查询设备版本，再决定是否重新连接、重新升级或联系技术支持；不要立即循环发起升级。

### 6.5 异常恢复与技术支持信息

通信或设备异常的推荐恢复顺序为：停止业务轮询 → 停止采集（如已启动）→ 记录错误信息 → 断开并重新连接 → 只读验证设备状态 → 恢复业务。如果问题持续出现，请提供以下信息：

- SDK 版本、产品型号、设备 SN、操作系统版本；
- 串口路径、调用的 API 名称、完整返回值与 `get_last_error()` 内容；
- 发生时间、操作阶段、是否正在采集或升级；
- 可复现步骤，以及脱敏后的业务日志。

## 7. 错误码与排障

PxCap3 使用统一的整数错误码表示失败类别，并通过最近错误信息补充本次调用的上下文。错误码适合程序分支和统计，`message` 适合定位具体参数、串口或升级文件问题；应用程序应同时保存两者。

### 7.1 返回值与最近错误语义

- 大多数公开 API 返回 `int`，`0` 表示本次调用成功，非 `0` 表示失败。业务控制流必须首先判断本次 API 的直接返回值。
- `pxcap3_create()` 返回句柄，返回 `NULL` 表示创建失败；`pxcap3_destroy()` 没有返回值。
- C 接口通过 `pxcap3_get_last_error(handle, &error)` 读取 `PxCap3ErrorInfo.code` 和 `message`。应先确认错误查询接口自身返回 `0`，再使用输出结构。
- Python 的 `get_last_error()` 返回 `(error_code, error_message)`；第一个值是最近一次失败的错误码，不是一个额外的查询状态码。
- 成功调用不会清除最近错误。旧错误会保留到下一次失败覆盖，因此不能在一个成功调用后仅凭 `get_last_error()` 判断当前操作失败。
- 接口返回失败后，本次输出参数不具备有效性。不得继续使用输出结构中的旧值，也不得把上一次成功结果当成本次数据。
- 连续采集和固件升级属于异步流程：启动接口返回 `0` 只表示任务已启动；运行期错误还需要结合最近错误、采集停止状态或升级回调终态判断。

### 7.2 错误码分类速查

|范围或数值|错误类别|优先检查|
|---:|---|---|
|`0`|成功|可以使用本次输出数据。|
|`100–111`|串口、权限、连接和系统 I/O|端口是否存在、用户权限、端口占用、供电线缆和设备是否重插。|
|`112–118`|句柄、指针、缓冲区和参数|handle 生命周期、空指针、缓冲区容量、字符串长度和输入范围。|
|`119–121`|设备识别或未分类异常|产品型号、设备状态、SDK 与交付文件一致性及完整日志。|
|`140–142`|固件升级|升级来源、ZIP 内容、网络、升级回调和终态消息。|
|`150–151`|传感器或编码器数据|设备返回载荷、模组状态、供电和连接稳定性。|
|`160`|通用设备操作失败|失败 API、操作阶段、设备连接和最近错误消息。|
|`4000`|连续采集状态冲突|先在回调外停止采集。|
|`4010`|固件升级状态冲突|等待升级终态，必要时请求取消。|

上述范围用于分类，不表示范围内的每个整数都已定义。调用方只应处理下文列出的稳定错误码，并为未知非零值保留统一兜底处理。

### 7.3 标准排障流程

1. **停止依赖操作：** 本次调用失败后，立即停止使用对应输出；控制、维护和升级场景不得带错继续执行。
2. **保存直接结果：** 记录 API 名称、直接返回值、发生时间，以及当前处于普通读取、采集、维护还是升级状态。
3. **读取最近错误：** 在 handle 仍有效时立即调用 `pxcap3_get_last_error()`，保存 `code` 和完整 `message`。
4. **按类别处理：** 先处理 `4000/4010` 状态互斥和 `112–118` 调用错误，再检查串口权限、端口占用、供电和通信。
5. **执行最小恢复：** 仅在原因允许时重试。重新连接后先执行连接状态、版本或单帧只读验证，不要直接恢复高频采集或再次升级。
6. **停止无效重试：** 同一错误连续出现时停止循环重试，保留设备 SN、SDK 版本、固件版本、端口、日志和可复现步骤。

遇到失败时按返回值和当前状态进行有限恢复；持续失败应先停止任务、检查连接或转人工处理。不要对所有非零错误无限重试。

### 7.4 串口与连接错误

|错误码|稳定错误名|含义与常见原因|建议处理|
|---:|---|---|---|
|100|`SERIAL_NOT_EXIST`|指定串口不存在，或设备重插后原端口路径已失效。|重新枚举 `/dev/ttyACM*`，确认设备上电并使用当前端口。|
|101|`SERIAL_PERMISSION_DENIED`|当前用户无权访问串口。|确认设备节点权限；将用户加入 `dialout` 组并重新登录。|
|102|`SERIAL_BUSY`|串口被其他进程、串口工具、其他 handle 或遗留进程占用。|关闭占用方；同一物理设备只保留一个活动连接。|
|103|`SERIAL_IO_ERROR`|已打开串口发生读写错误，常见于掉线、线缆异常或驱动错误。|停止轮询，检查供电和线缆；断开后重新枚举、连接并做只读验证。|
|104|`SERIAL_INVALID_PARAM`|串口路径或相关输入参数无效。|检查参数非空、字符串正确结束且路径格式有效。|
|105|`SERIAL_TIMEOUT`|设备未在通信期限内返回有效响应。|确认设备类型、供电、线缆和端口占用；有限重试后仍失败则重连。|
|106|`SERIAL_NOT_OPEN`|需要设备通信的接口在尚未连接或连接已经失效时调用。|先确认 `pxcap3_connect()` 返回 `0`；掉线后重新建立连接。|
|107|`SERIAL_CONFIG_FAIL`|系统无法按要求配置串口。|检查驱动、设备节点和系统日志；关闭其他串口程序后重试连接。|
|109|`SERIAL_BAD_DESCRIPTOR`|串口会话已失效。|停止当前会话，断开并重新连接。|
|110|`SERIAL_NO_SUCH_DEVICE`|设备节点存在过但设备当前已移除或未就绪。|检查 USB 枚举和供电，等待新节点稳定后再连接。|
|111|`SERIAL_OPEN_FAILED`|串口打开失败，但原因未映射为更具体的不存在、无权限或占用。|结合 `message` 和系统日志检查路径、权限、驱动与设备状态。|

Linux 下可使用系统工具辅助确认端口状态：

```bash
ls -l /dev/ttyACM*
id
lsof /dev/ttyACM0
dmesg --ctime | tail -n 50
```

如果设备重插，端口编号可能发生变化。业务配置应重新识别当前设备节点，不应永久假定设备始终位于 `/dev/ttyACM0`。

### 7.5 句柄、指针与参数错误

|错误码|稳定错误名|含义与常见原因|建议处理|
|---:|---|---|---|
|112|`INVALID_HANDLE`|传入空 handle、已销毁 handle 或非法会话对象。|修正创建、共享和销毁顺序；销毁后禁止继续调用。|
|113|`INPUT_POINTER_NULL`|必填输入指针或回调为空。|检查输入结构、字符串和回调函数，禁止传入 `NULL`。|
|114|`OUTPUT_POINTER_NULL`|必填输出结构指针为空。|分配有效输出对象并传入地址。|
|115|`OUTPUT_BUFFER_INVALID`|输出字符缓冲区为空或长度为零。|提供可写缓冲区和真实字节容量。|
|116|`COUNT_POINTER_NULL`|需要返回有效项数量时，计数指针为空。|同时提供数据缓冲区和计数输出地址。|
|117|`BUFFER_TOO_SMALL`|输出缓冲区不足，SDK 不写入截断字符串。|按接口约定扩大容量后重试；读取 SN 建议至少 33 字节。|
|118|`VALUE_OUT_OF_RANGE`|频率、字符串长度、枚举值或其他输入超出允许范围。|根据接口注释和 `message` 修正输入；连续采集频率必须大于 `0`。|

这类错误属于调用方问题，修改参数或生命周期前不应重试。C/C++ 应特别检查结构体地址、字符缓冲区容量和对象销毁时序；Python 应检查方法返回元组并确保回调对象在任务期间保持有效。

### 7.6 设备识别、数据与操作错误

|错误码|稳定错误名|含义与常见原因|建议处理|
|---:|---|---|---|
|119|`DEVICE_IDENTIFY_FAILED`|已连接设备无法完成所需的产品或版本信息识别。|确认连接的是 PxCap3，并记录设备版本、端口和完整消息后重连。|
|120|`UNKNOWN_EXCEPTION`|SDK 捕获到未能映射为更具体错误码的未分类异常。|停止当前流程并保存完整日志；若可稳定复现，提交技术支持处理。|
|121|`DEVICE_VERSION_MISMATCH`|设备版本标识与产品类型不匹配。该码当前主要作为兼容保留，公开连接流程默认不主动据此判型。|若实际收到，核对产品型号、SDK 库、头文件和 Python 包是否来自同一交付版本。|
|150|`SENSOR_PARSE_ERROR`|传感器或编码器数据异常。|检查连接稳定性；持续出现时停止采集并保存上下文。|
|151|`ENCODER_DEVICE_ERROR`|载荷已读取，但设备报告编码器或模组异常状态。|停止依赖该编码器数据的业务，读取故障信息并检查设备状态。|
|160|`DEVICE_OPERATION_FAILED`|设备操作失败，或采集回调异常等无法归入更细类别的运行期故障。|根据失败 API 和 `message` 判断阶段；停止相关任务，必要时重连后只读验证。|

回调应由调用方自行捕获异常并保持轻量；发现采集意外停止时，应查询最近错误。

### 7.7 连续采集与固件升级状态

|错误码|稳定错误名|含义与常见原因|建议处理|
|---:|---|---|---|
|4000|`COLLECTION_ACTIVE`|连续采集期间部分接口不可用。|在采集回调外调用 `pxcap3_stop_collection()`，返回 `0` 后再恢复普通接口。|
|4010|`FIRMWARE_UPGRADING`|固件升级仍在运行，受限普通接口当前不可用。|可继续查询连接状态；等待回调到达成功、具体失败或取消终态，必要时请求取消。|

`4000` 和 `4010` 是可预期的业务状态冲突，不表示串口或设备已经损坏。应用应通过明确的状态管理限制调用入口，不建议收到错误后反复轮询普通接口。

### 7.8 固件升级错误

|错误码|稳定错误名|含义与常见原因|建议处理|
|---:|---|---|---|
|140|`FIRMWARE_INVALID_CONFIG`|升级来源、模式、路径、在线地址或升级前置条件无效。|在线模式检查 HTTP 地址；离线模式只使用完整 ZIP；查询版本和启动升级必须使用同一模式。|
|141|`FIRMWARE_UPGRADE_FAILED`|固件升级失败。|以失败回调和 `message` 为准；保持供电，重新连接并查询当前版本。|
|142|`FIRMWARE_CALLBACK_FAILED`|调用方升级进度回调抛出异常，SDK 终止当前升级。|回调只做轻量复制，并捕获所有异常；检查 `message`。|

升级接口的同步返回值与异步结果必须分开判断：

- `pxcap3_upgrade_firmware()` 返回非 `0`：任务未成功启动，立即读取最近错误；
- 返回 `0`：任务已启动，但尚不能判定升级成功；
- 回调收到当前目标的 `*_FAILED`：升级失败，具体原因位于 `message`；回调消费异常也归类为失败，不能按 `CANCELLED` 处理；
- 回调收到 `PXCAP3_UPGRADE_PHASE_CANCELLED`：调用方取消请求生效；
- 只有收到 `PXCAP3_UPGRADE_PHASE_SUCCESS`，才能判定整包升级成功。

升级失败或取消后，不要立即循环发起下一次升级。应先确认升级回调已到达终态、设备重新可连接，并读取当前固件版本。

### 7.9 错误记录示例

C / C++ 调用方应同时记录直接返回值和最近错误：

```cpp
PxCap3SensorData data{};
const int rc = pxcap3_get_sensor_data(handle, &data);
if (rc != 0) {
  PxCap3ErrorInfo error{};
  const int error_rc = pxcap3_get_last_error(handle, &error);
  if (error_rc == 0) {
    // 记录 rc、error.code 和 error.message；不要使用 data。
  }
}
```

Python 调用方应注意 `get_last_error()` 的返回结构：

```python
rc, data = glove.get_sensor_data()
if rc != 0:
    error_code, error_message = glove.get_last_error()
    print(f"get_sensor_data failed: rc={rc}, code={error_code}, message={error_message}")
    data = None
```

生产日志建议至少包含以下字段：

```text
timestamp, product, sdk_version, device_sn, port, api_name,
direct_rc, last_error_code, last_error_message, operation_state,
thread_or_task, firmware_versions
```

### 7.10 常见场景处理

|现象|判断方式|处理顺序|
|---|---|---|
|提示“device is not connected”|直接返回通常为 `106`，`message` 提示先连接。|确认 connect 返回值 → 检查端口 → 重新连接 → 单帧读取验证。|
|连接时报无权限|返回 `101`。|检查节点属组 → 加入 `dialout` → 重新登录 → 再次连接。|
|连接时报端口忙|返回 `102`。|用 `lsof` 查占用 → 关闭串口工具或旧进程 → 保留单一连接。|
|普通接口突然返回 `4000`|同一 handle 正在连续采集。|停止向回调发新任务 → 在回调外停止采集 → 等待返回 `0` → 恢复普通调用。|
|普通接口返回 `4010`|固件升级尚未结束。|停止普通轮询 → 等待升级回调终态 → 必要时请求取消 → 重新连接验证。|
|采集自行停止|最近错误为 `160` 且消息指向回调失败，或存在设备通信异常。|查询最近错误 → 检查回调异常和耗时 → 检查设备 → 修复后再启动。|
|升级启动成功但最终失败|同步返回 `0`，回调收到具体 `*_FAILED`。|保存固件名称、索引和 message → 确认设备状态 → 查询版本 → 决定是否重试。|
|传感器数据偶发无效|返回 `150` 或通信类错误。|停止采集并检查连接、供电和设备状态。|

### 7.11 技术支持信息清单

问题无法通过上述步骤解决时，请整理以下信息后通过产品供应方或授权服务渠道反馈：

- SDK 版本、DEB 文件名、操作系统版本和 CPU 架构；
- 产品型号、设备 SN、当前主控与传感器固件版本；
- 串口路径、设备重插情况、供电和线缆连接方式；
- 失败 API、直接返回值、最近错误码和完整 `message`；
- 发生前后的调用顺序，以及当时是否正在采集、标定、静态磁检测或升级；
- 升级问题需补充在线地址或离线包类型、固件目标名称、索引、回调阶段和脱敏消息；
- 最小复现步骤、发生频率、期望结果、实际结果及脱敏日志。

提交日志前应移除账号、令牌、内部网络地址和其他敏感信息。不要只提供截图中的最后一行错误；完整的调用上下文通常比单独错误码更有助于定位问题。

## 8. 总结

本手册围绕 PxCap3 SDK 在 Linux 环境下的完整使用流程，系统说明了 SDK 安装与交付目录、串口与设备连接、触觉和磁编码器数据读取、连续采集、设备诊断、标定维护、SN 管理、固件升级以及错误排查方法。通过这些内容，开发者可以建立从设备接入、数据获取到异常恢复的完整认识，并根据业务需求选择单次读取或连续采集方式。

PxCap3 SDK 为上位机采集、机器人遥操作、触觉分析和多模态数据记录提供统一的 C API 与 Python 接口。SDK 负责稳定输出设备侧触觉、关节和状态信息，但不替代业务层的数据持久化、模态对齐、质量评估与模型处理。开发者应结合固定槽位、有效数量、数据单位和时间戳语义，对采集结果进行正确解释和组织。

我司希望本手册能够为开发者提供清晰、准确且可执行的参考，帮助开发者完成 PxCap3 设备接入并稳定获取触觉与关节数据。遇到设备、通信或升级问题时，请优先依据第 7 章的错误码和排障流程定位，并保留 SDK 版本、设备 SN、接口返回值、最近错误及运行上下文，以便进一步分析和支持。

## 9. 版权声明

1. **知识产权归属：** PXHandSDK、PxCap3 SDK 及其配套交付内容，包括但不限于软件、动态库、公开头文件、Python 绑定、示例、文档、图表、商标及相关衍生成果，其版权、商标权和其他知识产权归帕西尼感知科技有限公司或相应权利人所有，并受适用法律法规及国际版权公约保护。开发者可在已获得的授权范围内调用 SDK 公开接口并开发应用；未经书面授权，不得对 SDK 本身进行复制、转载、修改、反向工程、反编译、再许可、销售或再次分发。

2. **版本更新与变更：** 本手册与 SDK 将根据产品功能、设备固件和交付方式持续审核与修订，相关更新随正式版本发布。接口能力、技术参数、数据结构、系统要求、错误处理和示例内容可能发生变化，恕不另行逐项通知。开发者应使用与已安装 SDK 版本相匹配的最新手册、公开头文件和示例，不应混用不同版本的交付内容。

3. **无担保条款：** 在适用法律允许的范围内，本 SDK、示例和文档按“现状”（AS IS）提供。尽管我司将尽力保证软件稳定性、接口说明准确性和交付内容完整性，但相关内容仍可能存在疏漏、技术错误或与特定软硬件环境不兼容的情况。我司不对其适销性、特定用途适用性、准确性、完整性、不间断运行或无错误作出超出正式授权协议约定的明示或默示保证。

4. **责任限制：** 在适用法律允许的最大范围内，对于因使用、误用或无法使用本 SDK、设备、示例或文档所引起的任何直接、间接、附带、特殊或后果性损失，我司承担的责任以双方签署的正式授权、销售或服务协议为准。开发者应自行完成目标环境验证、异常保护、数据备份和上线前风险评估，不应将未经验证的示例代码直接用于安全关键或生产控制场景。

5. **问题反馈：** 如对本手册内容有疑问，或在使用过程中发现接口描述不一致、程序异常、数据异常或文档错误，请通过产品供应方或我司授权服务渠道反馈。反馈时建议提供 SDK 版本、产品型号、设备 SN、操作系统、串口路径、调用接口、返回值、`get_last_error()` 内容、复现步骤和脱敏日志，以便快速定位和修正。

6. **授权与合作：** 如有 SDK 商业授权、产品采购、技术服务或合作需求，请联系 [mkt@paxini.com](mailto:mkt@paxini.com)。具体授权范围、支持内容和责任边界以双方正式签署的协议为准。

版权所有 © 帕西尼感知科技有限公司。保留所有权利。
