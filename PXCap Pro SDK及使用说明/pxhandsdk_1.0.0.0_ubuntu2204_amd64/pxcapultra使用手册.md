# PxCapUltra

# PxCapUltra SDK Linux amd64 使用手册

|**修订页**|||
|---|---|---|
|**版本号**|**修订（内容）说明**|**修订时间**|
|V1.0.0.0|同步 1.0.0.0 交付版本与当前公开语义|2026/08|
|V1.0.8|同步当前安装包版本、公开调用约定与单手采集说明|2026/07|
|V1.0.4|完善 Linux 安装、单手设备模型及采集期间连接状态查询说明|2026/07|

**帕西尼感知科技（深圳）有限公司**

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

PxCapUltra 是 PXHandSDK 面向五指 Ultra 数据采集手套提供的 Linux SDK，用于获取十六个力区域、二十九路磁编码器、设备状态和诊断数据，并支持连续采集、设备标识读写与维护标定。

Ultra 采用“一个串口、一个单手设备、一个 handle”的模型。左右手是两台独立设备，应分别创建 handle 并连接各自 CDC 串口；SDK 会自动识别左右手。

本手册说明统一 DEB 系统安装、tar.gz 免安装部署、串口权限、设备识别、数据读取、连续采集、诊断维护和错误恢复。Ultra 当前不提供 PxCapPro 风格的固件升级接口，业务程序不得假定四条产品线能力完全相同。

### 阅读建议

首次接入时，先阅读第 3 章确认单手设备模型、串口、并发和回调限制，再按第 4 章运行只读示例；需要接入完整功能时查阅第 5 章，发生错误时按第 7 章排查。

编写程序时，使用当前交付包中的 `pxcapUltra.h` 和 `pxcapUltra_types.h` 查询函数参数、数据类型、数组长度、单位和返回值，使用本手册查询设备准备、推荐调用顺序、采集限制和故障处理。不要混用不同版本或不同平台的头文件、库、Python 包、示例和手册。

本文只说明公开 API、输入输出、使用条件和安全事项；设备通信细节及 SDK 处理方式不属于客户接入范围。

## 2. SDK 简介

### 2.1 数据与能力

|类别|内容|
|---|---|
|单手设备信息|左右手、主控版本、十二个传感器版本、设备 SN 和传感器 SN。|
|触觉数据|十六个固定力区域的合力和分布力。|
|编码器|二十九路磁编码器值和十四个主板端口原始状态字节。|
|诊断数据|故障汇总、通讯成功率、模组时间戳、磁状态、测点状态和标定结果。|
|维护能力|磁编码器标零、传感器重标定、静态磁检测。|
|连续采集|输出手别、触觉、编码器、端口状态和两类主机时间戳。|

### 2.2 设备与数据模型

```text
左手 Ultra -- 串口 A -- handle A --+
                                    +-- 上位机采集 / 多模态应用
右手 Ultra -- 串口 B -- handle B --+
```

每个 handle 分别维护连接和采集状态。需要双手采集时，业务层负责协调两个回调流；SDK 不将左右手组合为一个同步帧。两类时间戳均为主机收到单手完整帧的时刻。

### 2.3 安装目录

|交付内容|安装位置或入口|
|---|---|
|公开头文件|`/usr/include/pxhandsdk/pxcapUltra.h`、`pxcapUltra_types.h`|
|动态库|`/usr/lib/pxhandsdk/libpxcapultra_sdk.so`|
|CMake package|`/usr/lib/cmake/PxCapUltraSDK/`，target 为 `pxcapultrasdk::pxcapultra_sdk`|
|pkg-config|`/usr/lib/pkgconfig/pxhandsdk/pxcapultra-sdk.pc`|
|Python 包|`from pxhandsdk import pxcapultra`|
|C++ 示例|`/usr/share/pxhandsdk/examples/amd64/C++/pxcapultra_demo.cpp`|
|Python 示例|`/usr/share/pxhandsdk/examples/amd64/python/pxcapultra_demo.py`|
|Linux 手册|`/usr/share/doc/pxhandsdk/pxcapultra使用手册.md`|

## 3. 运行前注意事项

### 3.1 运行前检查

|检查项|要求|不满足时的处理|
|---|---|---|
|设备模型|一个 handle 只连接一只手。|双手分别创建 handle 和状态管理。|
|设备连接|使用随包配置连接设备。|不要由业务侧修改连接方式。|
|串口节点|使用当前枚举的 `/dev/ttyACM*`。|重插后重新识别，不沿用旧端口。|
|权限与占用|当前用户可访问端口，且没有其他进程占用。|加入 `dialout`，关闭串口工具或旧进程。|
|固件能力|诊断接口满足公开头注明的最低固件版本。|先读取版本，再按功能门槛启用界面。|
|采集状态|连接状态、停止采集和最近错误查询可与采集并存；其他普通接口不并发。|受限操作应先停止采集并等待返回 `0`。|

### 3.2 状态、回调和数据约束

- `pxcapultra_create()` 仅创建 handle；在线读取和维护必须先成功连接。
- 采集期间允许 `is_connected()`、停止采集、断开连接和最近错误查询；`disconnect()` 会先等待采集停止再断开，其他交互 API 返回 `4000`。
- 应以回调收到的完整数据和时间戳为准；回调应保持轻量并及时返回。
- `is_connected()` 用于查询当前连接状态；任务运行期间应以接口返回值和回调终态为准。
- `pxcapultra_stop_collection()` 不得在采集回调中调用，应在回调外调用。
- `pxcapultra_is_connected()` 只读 SDK 会话状态，可在采集回调内外调用；回调内不得调用其他同 handle API。
- 回调数据仅在本次回调有效，应复制后再长期保存；不得保存 SDK 指针。
- 触觉区域固定为十六路；分布力数组必须按每路 `count` 使用有效项。
- `PxCapUltraForceVector` 的 `x/y` 为有符号原始分量，`z` 为无符号原始分量；当前公开头未声明物理单位或换算系数，调用方不得自行假定为牛顿值。
- 故障汇总提供端口断联信息；原始状态可通过编码器数据接口查看。

### 3.3 固件版本门槛

|功能|最低设备固件|
|---|---|
|通讯成功率、传感器时间戳|V1.1.9|
|磁编码器状态、传感器测点状态|V1.2.1|
|传感器 SN|V1.2.2|
|传感器重标定结果|V1.3.0|
|静态磁检测|V1.3.2|

低于门槛时不应高频重试对应接口；应在上位机功能层禁用入口或提示升级设备固件。

## 4. 快速使用

### 4.1 推荐环境与安装

```text
操作系统：Ubuntu 22.04 LTS 64-bit
架构：x86_64（amd64）
C++：C++17
CMake：推荐 3.22 及以上
Python：系统 CPython >= 3.10 且 < 3.11
GPU、Docker、Conda：不需要
```

```bash
sudo dpkg -i pxhandsdk_1.0.0.0.ubantu2204_amd64.deb
sudo /usr/share/pxhandsdk/scripts/setup-serial-access.sh
# 重新登录后
groups
ls -l /dev/ttyACM*
```

#### tar.gz 免安装方式

```bash
tar -xzf pxhandsdk_1.0.0.0.ubantu2204_amd64.tar.gz
export PXHANDSDK_ROOT="$PWD/pxhandsdk_1.0.0.0.ubantu2204_amd64"
export LD_LIBRARY_PATH="$PXHANDSDK_ROOT/lib/pxhandsdk:$PXHANDSDK_ROOT/lib/pxhandsdk/core${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export PYTHONPATH="$PXHANDSDK_ROOT/lib/python3/pxhandsdk/dist-packages${PYTHONPATH:+:$PYTHONPATH}"
```

tar.gz 不自动安装 udev 规则或注册 Python 路径。包内示例位于
`$PXHANDSDK_ROOT/share/pxhandsdk/examples/amd64/`，C++ 示例构建时设置
`-DCMAKE_PREFIX_PATH="$PXHANDSDK_ROOT"`。完整命令见包根 `README.md`。

### 4.2 安装示例的编译与运行

DEB 同时安装 C++ 和 Python 只读示例。Ultra 一个 handle 只连接一只手；双手应分别创建 handle。

#### C++ 示例

```bash
cp -r /usr/share/pxhandsdk/examples/amd64/C++ "$PWD/pxhandsdk-cpp-examples"
cmake -S "$PWD/pxhandsdk-cpp-examples" -B "$PWD/pxhandsdk-cpp-examples/build" \
  -DCMAKE_PREFIX_PATH=/usr
cmake --build "$PWD/pxhandsdk-cpp-examples/build" --target pxcapultra_demo -j
"$PWD/pxhandsdk-cpp-examples/build/pxcapultra_demo" /dev/ttyACM0
```

使用 tar.gz 时：

```bash
cp -r "$PXHANDSDK_ROOT/share/pxhandsdk/examples/amd64/C++" "$PWD/pxhandsdk-cpp-examples"
cmake -S "$PWD/pxhandsdk-cpp-examples" -B "$PWD/pxhandsdk-cpp-examples/build" \
  -DCMAKE_PREFIX_PATH="$PXHANDSDK_ROOT"
cmake --build "$PWD/pxhandsdk-cpp-examples/build" --target pxcapultra_demo -j
"$PWD/pxhandsdk-cpp-examples/build/pxcapultra_demo" /dev/ttyACM0
```

#### Python 示例

```bash
/usr/bin/python3 /usr/share/pxhandsdk/examples/amd64/python/pxcapultra_demo.py /dev/ttyACM0
```

tar.gz 运行命令为：

```bash
/usr/bin/python3 "$PXHANDSDK_ROOT/share/pxhandsdk/examples/amd64/python/pxcapultra_demo.py" /dev/ttyACM0
```

两个客户示例均不写 SN、不标零、不重标定、不触发静态磁检测，也不启动连续采集；有副作用的真机维护必须使用专用验证程序并明确开启对应选项。

### 4.3 C++ 只读验证

默认 C++ 示例覆盖连接、左右手识别、SDK/固件/SN、十六路触觉、二十九路编码器、故障和只读诊断。也可通过 pkg-config 单独编译：

```bash
cp /usr/share/pxhandsdk/examples/amd64/C++/pxcapultra_demo.cpp ./
export PKG_CONFIG_PATH="/usr/lib/pkgconfig/pxhandsdk${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"
c++ -std=c++17 pxcapultra_demo.cpp -o pxcapultra_demo \
  $(pkg-config --cflags --libs pxcapultra-sdk)
./pxcapultra_demo /dev/ttyACM0
```

每个 `[OK]` 项及最终 `disconnect rc=0` 都成功，才表示只读验收通过。若出现 `[FAIL]`，读取 `PxCapUltraErrorInfo` 的 `code/message` 并停止使用本次输出。

### 4.4 Python 只读验证

Ultra Python 方法名为 `connect()` / `disconnect()`，不同于 Cap3/CapPro 的 `connect_device()` / `disconnect_device()`。

```python
from pxhandsdk import pxcapultra

glove = pxcapultra.PxCapUltra()
rc = glove.connect('/dev/ttyACM0')
if rc == 0:
    rc, info = glove.get_hand_info()
    if rc == 0:
        print(info.side, info.version, info.sn)
    rc, data = glove.get_sensor_data()
    if rc == 0:
        print(data.regions[0].resultant_force.z)
    glove.disconnect()
else:
    error = glove.get_last_error()
    print(error.code, error.message)
```

首次验收至少确认连接、左右手识别、版本、SN、十六路触觉、二十九路编码器和断开正常。

### 4.5 C++ 项目集成

```cmake
cmake_minimum_required(VERSION 3.16)
project(my_pxcapultra_app LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)

find_package(PxCapUltraSDK REQUIRED CONFIG)
add_executable(my_pxcapultra_app main.cpp)
target_link_libraries(my_pxcapultra_app PRIVATE pxcapultrasdk::pxcapultra_sdk)
```

```bash
cmake -S . -B build -DCMAKE_PREFIX_PATH=/usr
cmake --build build -j
./build/my_pxcapultra_app /dev/ttyACM0
```

### 4.6 Python 项目集成

Ultra Python 的连接方法是 `connect()` / `disconnect()`，不同于 Cap3/CapPro 的 `connect_device()` / `disconnect_device()`：

```python
import pxhandsdk

glove = pxhandsdk.PxCapUltra()
rc = glove.connect('/dev/ttyACM0')
if rc == 0:
    glove.disconnect()
```

```bash
/usr/bin/python3 -c "import pxhandsdk; print(pxhandsdk.PxCapUltra)"
/usr/bin/python3 -m venv --system-site-packages .venv
.venv/bin/python -c "import pxhandsdk; print(pxhandsdk.PxCapUltra)"
```

Python 无需链接 CMake target，也不要从 PyPI 安装同名包。Conda、不同 CPython 小版本或未启用 `--system-site-packages` 的 venv 默认看不到 DEB 绑定。

### 4.7 首次接入验收

- C++ 和 Python 默认示例均能连接设备并正常断开；
- 左右手、主控和十二个传感器版本、SN 均可读取；
- 十六路触觉合计 1030 个有效压力点，二十九路编码器顺序与公开头一致；
- 固件满足门槛的只读诊断接口返回成功；
- 首次验收未执行写 SN、标定、重标定、静态磁检测或连续采集。

## 5. 使用介绍

### 5.1 数据对象与固定容量

|对象|固定内容|
|---|---|
|`PxCapUltraVersionInfo`|主控版本和十二个传感器版本。|
|`PxCapUltraSensorData`|十六个力区域，每路含合力、分布力和有效数量。|
|`PxCapUltraEncoderData`|二十九路编码器和十四个端口原始状态字节。|
|`PxCapUltraFaultInfo`|最多十二个传感器断联项和两个独立磁编码器端口断联项。|
|`PxCapUltraSensorPointStates`|十二个模组，每个模组固定 56 字节状态。|
|`PxCapUltraCollectionData`|手别、触觉、编码器及两类主机时间戳。|

触觉数据按十六个力区域展平输出，固定顺序和每路分布力有效点数如下；全部区域合计为 1030 个压力传感点。

|槽位|力区域|分布力有效点数|
|---:|---|---:|
|0|拇指远端|116|
|1|拇指近端/小指腹|25|
|2–4|食指近端 / 中节 / 远端|55 / 25 / 96|
|5–7|中指近端 / 中节 / 远端|55 / 25 / 96|
|8–10|无名指近端 / 中节 / 远端|55 / 25 / 96|
|11–12|小拇指近端 / 远端|55 / 96|
|13–15|掌心带轴三角形 / 独立三角形 / 菱形|63 / 63 / 84|

每路只读取 `distribute_force_count` 个有效分布力数据。12 个物理传感器模组用于版本、SN、时间戳、测点状态和重标定等模组类接口，**不等同于** 16 个触觉力区域；模组顺序以公开头 `pxcapultra_get_firmware_versions()` 注释为准。

29 路磁编码器的 `values[0..28]` 固定顺序为：

|槽位|ID|槽位|ID|槽位|ID|
|---:|---|---:|---|---:|---|
|0|M4L|1|M5L|2|S4L|
|3|S5L|4|S2L|5|S3L|
|6|Z4L|7|Z5L|8|Z2L|
|9|Z3L|10|J1L|11|J2L|
|12|W4L|13|W5L|14|W2L|
|15|W3L|16|X4L|17|X5L|
|18|X2L|19|X3L|20|J4L|
|21|J3L|22|M1L|23|S1L|
|24|W1L|25|Z1L|26|X1L|
|27|M2L|28|M3L|||

### 5.2 全部接口分类

#### 5.2.1 会话、设备信息与 SN

|C API / Python|属性|功能与限制|
|---|---|---|
|`pxcapultra_create()` / `PxCapUltra()`|创建|创建单手会话。|
|`pxcapultra_destroy()` / 对象析构|销毁|停止采集和新的调用后释放资源。|
|`pxcapultra_connect()` / `connect()`|连接|建立连接并读取版本信息。|
|`pxcapultra_is_connected()` / `is_connected()`|读取|查询当前连接状态；任务运行期间以接口返回值和回调终态为准。|
|`pxcapultra_disconnect()` / `disconnect()`|断开|停止采集后断开。|
|`pxcapultra_get_last_error()` / `get_last_error()`|读取|C 返回状态并填结构；Python 直接返回 `PxCapUltraErrorInfo`。|
|`pxcapultra_get_sdk_version()` / `get_sdk_version()`|读取|不要求设备连接。|
|`pxcapultra_get_hand_info()` / `get_hand_info()`|读取|返回手别、版本、SN 和十二个传感器版本。|
|`pxcapultra_get_firmware_versions()` / `get_firmware_versions()`|读取|返回主控和十二个模组版本。|
|`pxcapultra_get_sn()` / `get_sn()`|读取|读取设备 SN。|
|`pxcapultra_set_sn()` / `set_sn()`|写入|最大 32 字节；量产 SN 已验证为 12 个可打印字节，写后约 1 秒回读。|

#### 5.2.2 触觉、编码器与连续采集

|C API / Python|属性|功能与限制|
|---|---|---|
|`pxcapultra_get_sensor_data()` / `get_sensor_data()`|读取|十六路合力和分布力完整帧。|
|`pxcapultra_get_sensor_resultant_force()` / `get_sensor_resultant_force()`|读取|十六路合力。|
|`pxcapultra_get_sensor_distribute_force()` / `get_sensor_distribute_force()`|读取|十六路分布力，按 `count` 使用。|
|`pxcapultra_get_encoder_data()` / `get_encoder_data()`|读取|二十九路编码器和十四个状态字节。|
|`pxcapultra_get_encoder_raw_data()` / `get_encoder_raw_data()`|读取|仅二十九路原始值。|
|`pxcapultra_start_collection()` / `start_collection()`|启动|频率大于 0，具体能力以当前设备和公开接口说明为准。|
|`pxcapultra_stop_collection()` / `stop_collection()`|停止|回调外调用并等待退出。|

#### 5.2.3 诊断接口

|C API / Python|最低固件|功能|
|---|---:|---|
|`pxcapultra_get_fault_code()` / `get_fault_code()`|基础|汇总端口断联信息。|
|`pxcapultra_get_sensor_success_rates()` / `get_sensor_success_rates()`|V1.1.9|十四路通讯成功率。|
|`pxcapultra_get_sensor_timestamps()` / `get_sensor_timestamps()`|V1.1.9|十二个模组上电运行时间戳。|
|`pxcapultra_get_magnetic_encoder_states()` / `get_magnetic_encoder_states()`|V1.2.1|二十七个模组侧磁编码器压缩状态。|
|`pxcapultra_get_sensor_point_states()` / `get_sensor_point_states()`|V1.2.1|十二个模组的测点状态位图。|
|`pxcapultra_get_sensor_serial_numbers()` / `get_sensor_serial_numbers()`|V1.2.2|十二个模组 SN。|
|`pxcapultra_get_sensor_calibration_results()` / `get_sensor_calibration_results()`|V1.3.0|最近一次重标定结果。|

#### 5.2.4 标定与维护

|C API / Python|属性|功能与限制|
|---|---|---|
|`pxcapultra_set_encoder_calibration()` / `set_encoder_calibration()`|写入|对二十九路磁编码器标零，设备处理约 2 秒。|
|`pxcapultra_get_encoder_calibration()` / `get_encoder_calibration()`|读取|读取标零状态和累计次数原始文本。|
|`pxcapultra_set_sensor_calibration()` / `set_sensor_calibration()`|写入|重标定十二个传感器模组。|
|`pxcapultra_recalibrate_sensors()` / `recalibrate_sensors()`|兼容写入|与 `set_sensor_calibration()` 同义。|
|`pxcapultra_set_static_magnet_check()` / `set_static_magnet_check()`|触发|V1.3.2；静止约 3 秒。|
|`pxcapultra_get_static_magnet_check()` / `get_static_magnet_check()`|读取|二十九路 `0/1/2` 状态。|

Ultra 没有公开固件升级 API。上层界面应依据产品能力显示功能，不能复用 CapPro 的升级按钮和调用路径。

## 6. 注意事项

- 双手应用分别管理两个设备会话和错误状态。
- 版本读取失败使用错误码 `119`；串口打开或设备操作失败主要使用 `160`，应结合 `message` 定位。
- 固件门槛不满足时禁用对应诊断功能，不进行无限重试。
- 写 SN、标定和静态磁检测前停止采集与轮询，并记录操作前后状态。
- 回调应由调用方自行捕获异常并保持轻量；发现采集意外停止时，应查询最近错误。
- 时间戳是主机帧可用时间，双手或外部模态对齐需由业务层处理。

## 7. 错误码与排障

### 7.1 错误语义

返回 `0` 表示本次调用成功。C 的 `pxcapultra_get_last_error()` 填充 `PxCapUltraErrorInfo`；Python `get_last_error()` 直接返回错误对象。成功调用不会自动清除最近失败，业务必须优先判断本次直接返回值。

### 7.2 常见错误码

|错误码|稳定错误名或语义|处理|
|---:|---|---|
|100|`SERIAL_NOT_EXIST`|重新枚举当前端口。|
|101|`SERIAL_PERMISSION_DENIED`|加入 `dialout` 并重新登录。|
|102|`SERIAL_BUSY`|关闭占用进程，一个设备保留一个连接。|
|103 / 105|I/O 错误或超时|检查供电、线缆和端口，有限重试后重连。|
|104 / 107|参数或串口配置错误|检查端口字符串和系统驱动。|
|106 / 109 / 110 / 111|未打开、描述符失效、设备移除或打开失败|停止读取，重新枚举并重建会话。|
|112|`INVALID_HANDLE`|修正 handle 生命周期。|
|113 / 114|输入或输出指针为空|提供有效结构和回调。|
|115 / 117|输出缓冲无效或不足|扩大缓冲区，不使用截断输出。|
|118|`VALUE_OUT_OF_RANGE`|修正频率、长度或其他输入范围。|
|119|`DEVICE_IDENTIFY_FAILED`|版本读取/识别失败；确认设备、供电和串口。|
|120|`UNKNOWN_EXCEPTION`|保存完整日志并反馈。|
|150 / 151|传感器或编码器数据异常|持续出现时停止采集并检查设备。|
|160|`DEVICE_OPERATION_FAILED`|串口打开、设备操作或回调失败；结合 API 和 `message` 定位。|
|4000|`COLLECTION_ACTIVE`|在回调外停止采集，返回 `0` 后恢复普通调用。|

排障顺序为：停止依赖操作 → 保存 API 和直接返回值 → 读取最近错误 → 检查产品/固件门槛、端口、权限和状态 → 重新连接后只读验证。反馈时提供手别、版本、设备 SN、端口、失败 API、错误对象、调用状态、复现步骤和脱敏日志。

## 8. 总结

本手册说明了 PxCapUltra 单串口单手模型、左右手识别、十六路触觉、二十九路编码器、诊断维护和连续采集的完整接入方式。开发者应先确认设备版本和基础数据，再按固件门槛启用高级诊断能力。

我司希望本手册帮助开发者稳定获取 Ultra 触觉、姿态和设备状态数据，并正确集成到上位机、多模态采集和具身智能应用中。

## 9. 版权声明

1. **知识产权归属：** PXHandSDK、PxCapUltra SDK 及配套软件、动态库、头文件、绑定、示例和文档的相关知识产权归帕西尼感知科技有限公司或相应权利人所有。授权范围外不得复制、修改、反向工程、再许可、销售或分发 SDK 本身。
2. **版本更新与变更：** SDK、设备固件和文档可能随正式版本更新，应使用同一交付版本的内容。
3. **无担保条款：** 在适用法律允许范围内，本 SDK、示例和文档按“现状”（AS IS）提供，具体保证以正式协议为准。
4. **责任限制：** 开发者应完成目标环境验证、异常保护和上线风险评估；责任边界以双方正式协议为准。
5. **问题反馈：** 请提供版本、手别、SN、端口、API、返回值、最近错误、复现步骤和脱敏日志。
6. **授权与合作：** 商业授权、产品采购和合作需求请联系 [mkt@paxini.com](mailto:mkt@paxini.com)。

版权所有 © 帕西尼感知科技有限公司。保留所有权利。
