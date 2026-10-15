# PxCapPro

# PxCapPro SDK Linux amd64 使用手册

|**修订页**|||
|---|---|---|
|**版本号**|**修订（内容）说明**|**修订时间**|
|V1.0.0.0|同步 1.0.0.0 交付版本与当前公开语义|2026/08|
|V1.0.8|同步当前安装包版本、公开调用约定与升级流程说明|2026/07|
|V1.0.4|完善 Linux 安装、连续采集、固件升级及运行期间连接状态查询说明|2026/07|

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

具身智能系统需要稳定、可解释的真实触觉与手部姿态数据。PxCapPro 是 PXHandSDK 面向五指 Pro 数据采集手套提供的 Linux 离线 SDK，用于连接设备、读取六路分布式触觉、十七路磁编码器与关节角，并支持诊断维护、连续采集和固件升级。

本手册面向应用开发人员、集成工程师和测试人员，覆盖统一 DEB 系统安装、tar.gz 免安装部署、串口权限、设备连接、单次读取、连续采集、标定维护、在线/离线升级和错误恢复。PxCapPro SDK 负责设备接入和实时数据输出，不负责业务侧的数据持久化、模态对齐、质量评估或模型训练。

首次接入应先完成只读验证，再启用连续采集、写 SN、标定和升级。采集与升级期间部分接口受限；调用方应依据 `4000`、`4010`、其他返回值和回调终态管理业务状态。

### 阅读建议

首次接入时，先阅读第 3 章确认设备、串口、并发和回调限制，再按第 4 章运行只读示例；需要接入完整功能时查阅第 5 章，发生错误时按第 7 章排查。

编写程序时，使用当前交付包中的 `pxcapPro.h` 和 `pxcapPro_types.h` 查询函数参数、数据类型、数组长度、单位和返回值，使用本手册查询设备准备、推荐调用顺序、采集与升级限制和故障处理。不要混用不同版本或不同平台的头文件、库、Python 包、示例和手册。

本文只说明公开 API、输入输出、使用条件和安全事项；设备通信细节及 SDK 处理方式不属于客户接入范围。

## 2. SDK 简介

### 2.1 数据与能力

PxCapPro 对外提供以下能力：

|类别|内容|
|---|---|
|设备会话|创建、连接、连接状态、断开、销毁和最近错误。|
|设备信息|SDK 版本、设备固件版本、设备 SN 读写。|
|触觉数据|六路固定槽位的合力、分布力及完整触觉帧。|
|手部姿态|十七路磁编码器数据和十七路关节角。|
|连续采集|异步输出编码器、关节角、触觉数据和两类主机纳秒时间戳。|
|诊断维护|故障汇总、磁编码器标零、传感器标零和静态磁检测。|
|固件升级|HTTP 在线升级、本地 ZIP 离线升级、目标版本查询、异步进度和取消。|

### 2.2 数据与并发约束

连续采集通过回调提供完整帧。应用应以收到的数据和时间戳为准，回调保持轻量。时间戳表示主机侧帧可用时间，不是设备硬件采样时间。

### 2.3 对外接口与安装目录

|交付内容|安装位置或入口|
|---|---|
|公开头文件|`/usr/include/pxhandsdk/pxcapPro.h`、`pxcapPro_types.h`|
|动态库|`/usr/lib/pxhandsdk/libpxcappro_sdk.so`|
|CMake package|`/usr/lib/cmake/PxCapProSDK/`，target 为 `pxcapprosdk::pxcappro_sdk`|
|pkg-config|`/usr/lib/pkgconfig/pxhandsdk/pxcappro-sdk.pc`|
|Python 包|`from pxhandsdk import pxcappro`|
|C++ 示例|`/usr/share/pxhandsdk/examples/amd64/C++/pxcappro_demo.cpp`|
|Python 示例|`/usr/share/pxhandsdk/examples/amd64/python/pxcappro_demo.py`|
|Linux 手册|`/usr/share/doc/pxhandsdk/pxcappro使用手册.md`|

安装后的实际文件以 `dpkg -L pxhandsdk` 为准。运行约束见第 3 章，首次验证见第 4 章，全部接口分类见第 5 章。

## 3. 运行前注意事项

### 3.1 运行前检查

|检查项|要求|不满足时的处理|
|---|---|---|
|交付一致性|头文件、动态库、Python 包和示例来自同一 DEB。|清理旧安装并重新安装统一总包。|
|设备节点|使用当前实际枚举的 `/dev/ttyACM*`。|设备重插后重新枚举，不沿用旧端口号。|
|串口权限|当前用户属于 `dialout`，目标端口可读写。|配置用户组并重新登录。|
|端口占用|没有串口助手、旧进程或其他 handle 占用设备。|关闭占用方，一个设备只保留一个活动连接。|
|任务状态|普通读取、采集、维护和升级不会在同一 handle 上冲突。|先停止上一任务并等待其终态。|
|回调消费|回调只复制或转交数据。|由应用自行管理存储和丢帧记录。|

### 3.2 生命周期与状态互斥

- `pxcappro_create()` 仅创建会话，不表示已连接；在线设备操作必须在 `pxcappro_connect()` 返回 `0` 后执行。
- 连续采集期间，允许连接状态、停止采集、断开连接和最近错误查询；`disconnect` 会先等待采集停止再断开，其他接口返回 `4000`。
- 应以回调收到的完整数据和时间戳为准；回调应保持轻量并及时返回。
- 固件升级期间，允许连接状态、取消升级和最近错误查询，其他普通接口返回 `4010`。
- 升级期间应以接口返回值和回调终态判断当前任务状态。
- `pxcappro_stop_collection()` 可在回调中请求停止；回调外调用会等待停止完成。复杂生命周期操作应在回调外执行。
- 采集回调中的 `data` 仅在本次回调期间有效；长期使用前必须复制。
- 升级回调中不得再次启动升级；销毁和其他生命周期操作应在回调外执行。
- 成功调用不会清除历史最近错误；必须以本次 API 的直接返回值判断成功与否。

### 3.3 数据和维护约束

- 六路触觉固定顺序为 `thumb_tip`、`index_tip`、`middle_tip`、`ring_tip`、`pinky_tip`、`palm`。
- 力值单位为 `0.1N`；`x/y` 为有符号分量，`z` 为无符号分量。分布力必须按每路 `count` 读取有效项。
- 编码器和关节角固定为十七路；角度单位为度。
- 标零、静态磁检测、写 SN 和固件升级会改变设备状态或持久化内容，执行前应停止业务轮询。
- 静态磁检测需保持设备静止约 6 秒；十七路状态全部为 `0` 才表示通过。
- 离线升级使用交付说明规定的 ZIP 来源。

## 4. 快速使用

### 4.1 推荐环境

```text
操作系统：Ubuntu 22.04 LTS 64-bit
处理器架构：x86_64（amd64）
C++：支持 C++17
CMake：推荐 3.22 及以上
Python：系统 CPython >= 3.10 且 < 3.11
设备连接：USB CDC 串口 /dev/ttyACM*
GPU、Docker、Conda：不需要
网络：仅在线固件升级需要
```

### 4.2 安装和串口权限

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

tar.gz 不写入 `/usr`、不自动安装 udev 规则；包内示例位于
`$PXHANDSDK_ROOT/share/pxhandsdk/examples/amd64/`，C++ 示例构建时设置
`-DCMAKE_PREFIX_PATH="$PXHANDSDK_ROOT"`。完整命令见包根 `README.md`，不得与其他版本或架构混用。

如需编译 C++ 示例，安装 `build-essential cmake pkg-config`。不要使用 `chmod 777` 作为正式权限方案。

### 4.3 安装示例的编译与运行

DEB 同时安装 C++ 和 Python 示例。两个 PxCapPro 示例默认只读取设备信息、六路触觉、十七路编码器、角度和故障，不执行标定、写 SN 或升级。

#### C++ 示例

```bash
cp -r /usr/share/pxhandsdk/examples/amd64/C++ "$PWD/pxhandsdk-cpp-examples"
cmake -S "$PWD/pxhandsdk-cpp-examples" -B "$PWD/pxhandsdk-cpp-examples/build" \
  -DCMAKE_PREFIX_PATH=/usr
cmake --build "$PWD/pxhandsdk-cpp-examples/build" --target pxcappro_demo -j
"$PWD/pxhandsdk-cpp-examples/build/pxcappro_demo" /dev/ttyACM0
```

使用 tar.gz 时：

```bash
cp -r "$PXHANDSDK_ROOT/share/pxhandsdk/examples/amd64/C++" "$PWD/pxhandsdk-cpp-examples"
cmake -S "$PWD/pxhandsdk-cpp-examples" -B "$PWD/pxhandsdk-cpp-examples/build" \
  -DCMAKE_PREFIX_PATH="$PXHANDSDK_ROOT"
cmake --build "$PWD/pxhandsdk-cpp-examples/build" --target pxcappro_demo -j
"$PWD/pxhandsdk-cpp-examples/build/pxcappro_demo" /dev/ttyACM0
```

#### Python 示例

```bash
/usr/bin/python3 /usr/share/pxhandsdk/examples/amd64/python/pxcappro_demo.py /dev/ttyACM0
```

tar.gz 运行命令为：

```bash
/usr/bin/python3 "$PXHANDSDK_ROOT/share/pxhandsdk/examples/amd64/python/pxcappro_demo.py" /dev/ttyACM0
```

首次接入建议只执行只读验证；标定、静态磁检测、写 SN 和固件升级等会改变设备状态的能力，应在完成安全检查后通过公开 API 按需调用。

### 4.4 C++ 只读验证

默认 C++ 示例就是只读验收程序。也可使用 pkg-config 单独编译：

```bash
cp /usr/share/pxhandsdk/examples/amd64/C++/pxcappro_demo.cpp ./
export PKG_CONFIG_PATH="/usr/lib/pkgconfig/pxhandsdk${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"
c++ -std=c++17 pxcappro_demo.cpp -o pxcappro_demo \
  $(pkg-config --cflags --libs pxcappro-sdk)
./pxcappro_demo /dev/ttyACM0
```

版本、SN、触觉、编码器、角度和故障读取均返回 `0`，且最终断开成功，才表示只读验收通过。失败后读取 `pxcappro_get_last_error()`，不要使用失败调用的输出。

### 4.5 Python 只读验证

```python
from pxhandsdk import pxcappro

glove = pxcappro.PxCapPro()
rc = glove.connect_device('/dev/ttyACM0')
if rc == 0:
    rc, data = glove.get_sensor_data()
    if rc == 0:
        print(data.thumb_tip_force.resultant_force.z)
    else:
        print(glove.get_last_error())
    glove.disconnect_device()
else:
    print(glove.get_last_error())
```

验收时至少确认导入、连接、版本、单帧触觉、编码器和断开均成功，并且失败路径能输出直接返回值及最近错误。

### 4.6 C++ 项目集成

```cmake
cmake_minimum_required(VERSION 3.16)
project(my_pxcappro_app LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)

find_package(PxCapProSDK REQUIRED CONFIG)
add_executable(my_pxcappro_app main.cpp)
target_link_libraries(my_pxcappro_app PRIVATE pxcapprosdk::pxcappro_sdk)
```

```bash
cmake -S . -B build -DCMAKE_PREFIX_PATH=/usr
cmake --build build -j
./build/my_pxcappro_app /dev/ttyACM0
```

### 4.7 Python 项目集成

Python 无需 CMake 链接。DEB 安装后使用系统 Python 直接导入：

```python
import pxhandsdk

glove = pxhandsdk.PxCapPro()
# 等价写法：glove = pxhandsdk.pxcappro.PxCapPro()
```

```bash
/usr/bin/python3 -c "import pxhandsdk; print(pxhandsdk.PxCapPro)"
/usr/bin/python3 -m venv --system-site-packages .venv
.venv/bin/python -c "import pxhandsdk; print(pxhandsdk.PxCapPro)"
```

不要从 PyPI 安装同名包。Conda、不同 CPython 小版本或未启用 `--system-site-packages` 的 venv 默认无法加载 DEB 绑定。

### 4.8 首次接入验收

- C++ 和 Python 默认示例均能连接正确设备并正常断开；
- SDK/固件版本、SN、六路触觉、十七路编码器/角度和故障读取均成功；
- 失败路径能够输出直接返回值和最近错误；
- 首次验收未执行标定、写 SN、静态磁检测或固件升级。

## 5. 使用介绍

### 5.1 数据对象

|对象|内容|
|---|---|
|`PxCapProSensorData`|六路合力和分布力完整帧。|
|`PxCapProSensorResultantForce`|六路三轴合力。|
|`PxCapProSensorDistributeForce`|六路分布力及有效数量。|
|`PxCapProEncoderRaw` / `PxCapProEncoderAngles`|十七路编码器数据和角度。|
|`PxCapProCollectionData`|编码器、角度、六路触觉和两类时间戳。|
|`PxCapProVersionInfo`|当前设备版本或升级源目标版本，由调用接口决定。|
|`PxCapProFaultInfo`|传感器和磁编码器故障项。|
|`PxCapProUpgradeProgress`|升级阶段、进度、固件目标和消息。|

### 5.2 全部接口分类

以下分类覆盖全部 PxCapPro 公开接口。除特别说明外，设备读写均要求已连接。

#### 5.2.1 会话、版本与 SN

|C API / Python|属性|功能与限制|
|---|---|---|
|`pxcappro_create()` / `PxCapPro()`|创建|创建会话，不建立连接。|
|`pxcappro_destroy()` / 对象析构|销毁|释放资源；销毁前应停止新的调用。|
|`pxcappro_connect()` / `connect_device()`|连接|连接非空串口路径。|
|`pxcappro_is_connected()` / `is_connected()`|读取|查询当前连接状态；任务运行期间以接口返回值和回调终态为准。|
|`pxcappro_disconnect()` / `disconnect_device()`|断开|采集中先停止采集再断开设备；升级结束后才能断开。|
|`pxcappro_get_last_error()` / `get_last_error()`|读取|读取最近失败；成功调用不会清除。|
|`pxcappro_get_sdk_version()` / `get_sdk_version()`|读取|读取 SDK 版本与打包时间，不要求设备在线。|
|`pxcappro_get_firmware_versions()` / `get_firmware_versions()`|读取|读取当前主控和传感器版本。|
|`pxcappro_get_sn()` / `get_sn()`|读取|读取设备 SN。|
|`pxcappro_set_sn()` / `set_sn()`|写入|持久化 SN；授权维护后写入并回读核验。|

#### 5.2.2 触觉、编码器与采集

|C API / Python|属性|功能与限制|
|---|---|---|
|`pxcappro_get_sensor_data()` / `get_sensor_data()`|读取|一次返回六路完整触觉帧。|
|`pxcappro_get_sensor_resultant_force()` / `get_sensor_resultant_force()`|读取|返回六路合力。|
|`pxcappro_get_sensor_distribute_force()` / `get_sensor_distribute_force()`|读取|返回六路分布力，按每路有效数量使用。|
|`pxcappro_get_encoder_raw_data()` / `get_encoder_raw_data()`|读取|读取十七路编码器数据。|
|`pxcappro_get_encoder_angles()` / `get_encoder_angles()`|读取|读取十七路关节角，单位为度。|
|`pxcappro_start_collection()` / `start_collection()`|启动|频率大于 0，具体能力以当前设备和公开接口说明为准。|
|`pxcappro_stop_collection()` / `stop_collection()`|停止|未采集时为成功 no-op。|

#### 5.2.3 诊断与维护

|C API / Python|属性|功能与限制|
|---|---|---|
|`pxcappro_get_fault_code()` / `get_fault_code()`|读取|按两类有效数量读取故障项。|
|`pxcappro_set_encoder_calibration()` / `set_encoder_calibration()`|写入|对十七路磁编码器标零。|
|`pxcappro_set_sensor_calibration()` / `set_sensor_calibration()`|写入|执行传感器标零。|
|`pxcappro_set_static_magnet_check()` / `set_static_magnet_check()`|触发|静止状态触发约 6 秒检测。|
|`pxcappro_get_static_magnet_check()` / `get_static_magnet_check()`|读取|读取十七路 `0/1/2` 状态。|

#### 5.2.4 固件升级

|C API / Python|属性|功能与限制|
|---|---|---|
|`pxcappro_set_upgrade_online_address()` / `set_upgrade_online_address()`|配置|保存非空 HTTP 地址。|
|`pxcappro_set_upgrade_offline_package()` / `set_upgrade_offline_package()`|配置|保存本地 ZIP 路径。|
|`pxcappro_get_upgrade_package_versions()` / `get_upgrade_package_versions()`|读取|解析升级源目标版本，不表示设备当前版本；不要求连接。|
|`pxcappro_upgrade_firmware()` / `upgrade_firmware()`|启动|要求连接、来源匹配和有效回调；同步成功仅表示已启动。|
|`pxcappro_cancel_upgrade()` / `cancel_upgrade()`|控制|请求取消；无活动升级时成功，仍需等待回调终态。|

升级源、包内容和进度状态以当前公开头文件及交付包说明为准。应用应根据回调终态判断整项任务成功、失败或取消，并在回调外执行其他生命周期操作。

### 5.3 回调使用建议

回调中只复制必要字段或转交数据。连续采集适合实时处理；如需存档，应由应用自行设计缓存和落盘策略。升级回调的 `user_data` 必须存活到终态，并应保存公开回调中的状态和消息字段。

## 6. 注意事项

- 上线前验证端口重插、权限不足、端口占用、断线、回调异常和进程退出路径。
- 不在采集回调中执行文件写入、网络阻塞或耗时处理；长期保存前复制数据。
- 维护和升级前停止采集及普通轮询；升级期间严禁断电、拔线、主机休眠或退出进程。
- 失败调用的输出不可使用；记录 API、直接返回值、最近错误、端口、SN、运行状态和时间戳。
- 升级失败或取消后先确认任务终止、重新连接并读取当前版本，不要立即循环升级。

## 7. 错误码与排障

### 7.1 错误语义与流程

返回 `0` 表示本次调用成功，非 `0` 表示失败。C 通过 `PxCapProErrorInfo` 读取最近错误；Python `get_last_error()` 返回 `(error_code, error_message)`。成功调用不会清除历史错误。

标准流程：停止依赖操作 → 记录直接返回值 → 读取最近错误 → 按类别修复 → 只读验证 → 有限恢复。参数错误修正前不重试，持续通信或解析错误应停止高频循环并保留上下文。

### 7.2 错误码表

|错误码|稳定错误名|常见原因与处理|
|---:|---|---|
|100|`SERIAL_NOT_EXIST`|端口不存在；重新枚举当前 `/dev/ttyACM*`。|
|101|`SERIAL_PERMISSION_DENIED`|无串口权限；加入 `dialout` 并重新登录。|
|102|`SERIAL_BUSY`|端口被占用；关闭串口工具、旧进程或重复 handle。|
|103|`SERIAL_IO_ERROR`|串口 I/O 失败；检查供电线缆，停止轮询并重连。|
|104|`SERIAL_INVALID_PARAM`|端口或字符串参数无效；修正输入。|
|105|`SERIAL_TIMEOUT`|设备超时；有限重试后重连。|
|106|`SERIAL_NOT_OPEN`|未连接或连接失效；先成功连接。|
|107|`SERIAL_CONFIG_FAIL`|串口配置失败；检查驱动和系统日志。|
|109|`SERIAL_BAD_DESCRIPTOR`|串口会话失效；停止当前会话并重新连接。|
|110|`SERIAL_NO_SUCH_DEVICE`|设备移除或未就绪；重新枚举。|
|111|`SERIAL_OPEN_FAILED`|端口打开失败；结合 `message` 检查路径、权限和占用。|
|112|`INVALID_HANDLE`|handle 为空或已销毁；修正生命周期。|
|113 / 114|`INPUT_POINTER_NULL` / `OUTPUT_POINTER_NULL`|必填输入、回调或输出为空。|
|115 / 116|`OUTPUT_BUFFER_INVALID` / `COUNT_POINTER_NULL`|输出缓冲或计数指针无效。|
|117|`BUFFER_TOO_SMALL`|扩大缓冲区后重试，不使用截断输出。|
|118|`VALUE_OUT_OF_RANGE`|频率、枚举或字符串长度超范围。|
|119|`DEVICE_IDENTIFY_FAILED`|设备识别失败；核对产品型号和版本。|
|120|`UNKNOWN_EXCEPTION`|未知未分类异常；保存完整日志并反馈。|
|121|`DEVICE_VERSION_MISMATCH`|兼容保留；核对库、头和 Python 包版本。|
|140|`FIRMWARE_INVALID_CONFIG`|地址、ZIP、模式或来源未配置。|
|141|`FIRMWARE_UPGRADE_FAILED`|升级阶段失败；以当前目标 `*_FAILED` 和 `message` 为准。|
|142|`FIRMWARE_CALLBACK_FAILED`|升级回调异常；捕获异常并简化回调。|
|150|`SENSOR_PARSE_ERROR`|传感器数据异常；持续出现时停止采集并检查设备。|
|151|`ENCODER_DEVICE_ERROR`|编码器模组报告异常；停止依赖该数据的业务。|
|160|`DEVICE_OPERATION_FAILED`|通用设备或回调操作失败；结合 API 和消息定位。|
|4000|`COLLECTION_ACTIVE`|采集状态冲突；先停止采集。|
|4010|`FIRMWARE_UPGRADING`|升级状态冲突；连接状态仍可查询，其他受限接口等待成功、失败或取消终态。|

反馈问题时提供 SDK 版本、设备 SN、固件版本、端口、失败 API、直接返回值、最近错误、运行状态、复现步骤和脱敏日志。

## 8. 总结

本手册说明了 PxCapPro 从安装、连接、六路触觉与十七路姿态读取，到连续采集、诊断维护和在线/ZIP 升级的完整接入流程。开发者应先完成只读验收，再以明确的状态管理和轻量回调接入业务。

我司希望本手册帮助开发者稳定获取触觉与手部姿态数据，并将其用于上位机采集和应用集成。遇到问题时请按第 7 章保留完整上下文后排查或反馈。

## 9. 版权声明

1. **知识产权归属：** PXHandSDK、PxCapPro SDK 及其配套软件、动态库、头文件、绑定、示例、文档和图表的相关知识产权归帕西尼感知科技有限公司或相应权利人所有。授权范围外不得复制、修改、反向工程、再许可、销售或分发 SDK 本身。
2. **版本更新与变更：** SDK、固件和文档可能随正式版本更新。开发者应使用同一交付版本的头文件、库、Python 包和手册。
3. **无担保条款：** 在适用法律允许范围内，本 SDK、示例和文档按“现状”（AS IS）提供，具体保证以正式协议为准。
4. **责任限制：** 开发者应完成目标环境验证、异常保护、数据备份和上线风险评估；责任边界以双方正式协议为准。
5. **问题反馈：** 反馈时请提供版本、SN、端口、API、返回值、最近错误、复现步骤和脱敏日志。
6. **授权与合作：** 商业授权、产品采购和合作需求请联系 [mkt@paxini.com](mailto:mkt@paxini.com)。

版权所有 © 帕西尼感知科技有限公司。保留所有权利。
