# PxDex3

# PxDex3 SDK Linux amd64 使用手册

|**修订页**|||
|---|---|---|
|**版本号**|**修订（内容）说明**|**修订时间**|
|V1.0.0.0|同步 1.0.0.0 交付版本与当前公开语义|2026/08|
|V1.0.8|同步当前安装包版本、公开调用约定与连续采集完整字段说明|2026/07|
|V1.0.4|完善 Linux 安装、运动控制、连续采集磁编/故障数据说明|2026/07|

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

PxDex3 是 PXHandSDK 面向三指执行器提供的 Linux 离线 SDK。它同时包含执行器控制、四路电机状态、四路磁编码器、十路触觉、故障诊断、标定维护和异步连续采集能力，可用于机器人末端控制、遥操作、触觉闭环和数据采集。

与纯数据采集手套不同，PxDex3 接口可能直接驱动机械结构。接入工作不仅要保证串口和数据正确，还必须建立电机使能、控制模式、位置限位、回零、故障停机和人员安全流程。任何示例都不能替代目标设备上的机械安全验证。

本手册覆盖统一 DEB 系统安装、tar.gz 免安装部署、串口权限、只读验收、运动控制、连续采集、维护和错误恢复。建议先完成无运动的版本、状态和触觉读取，再在受控环境中逐步启用电机。

### 阅读建议

本文只说明公开 API、输入输出、使用条件和安全事项；设备通信细节及 SDK 处理方式不属于客户接入范围。

首次接入时，先阅读第 3 章确认机械安全、设备、串口和并发限制，再按第 4 章完成只读验证；需要接入运动控制或完整功能时查阅第 5 章，发生错误时按第 7 章排查。

编写程序时，使用当前交付包中的 `pxdex3.h` 和 `pxdex3_types.h` 查询函数参数、数据类型、数组长度、单位和返回值，使用本手册查询设备准备、安全措施、推荐调用顺序、采集限制和故障处理。不要混用不同版本或不同平台的头文件、库、Python 包、示例和手册。

## 2. SDK 简介

### 2.1 核心能力

|类别|内容|
|---|---|
|设备会话|创建、连接、连接查询、断开、销毁和最近错误。|
|版本与标识|SDK 版本、主固件、四路电驱版本、传感器版本和设备 SN。|
|电机状态|四路当前位置、温度、电流、目标位置、控制模式、使能状态和位置限位。|
|位置控制|读取四路当前关节角反馈，切换控制模式、使能/失能并下发四路绝对位置。|
|触觉与编码器|十路触觉合力/分布力、四路编码器数据和角度。|
|连续采集|时间戳、当前位置、电流、温度、合力、444 点分布力、四路编码器数据和传感器故障汇总。|
|维护诊断|传感器故障、磁编码器标零/回零和传感器标零。|

### 2.2 通道与数据约定

四路电机和编码器固定顺序为：食指指腹、食指指尖、中指指腹、中指指尖。十路触觉固定槽位的分布力点数依次为 `49、20、49、20、49、20、49、20、119、49`，共 444 点。

连续采集期间部分接口受限，实际采集频率取决于目标频率、系统负载和回调处理时间。采集回调应快速复制数据并返回，耗时处理应放在回调外完成。

### 2.3 安装目录

|交付内容|安装位置或入口|
|---|---|
|公开头文件|`/usr/include/pxhandsdk/pxdex3.h`、`pxdex3_types.h`|
|动态库|`/usr/lib/pxhandsdk/libpxdex3_sdk.so`|
|CMake package|`/usr/lib/cmake/PxDex3SDK/`，target 为 `pxdex3sdk::pxdex3_sdk`|
|pkg-config|`/usr/lib/pkgconfig/pxhandsdk/pxdex3-sdk.pc`|
|Python 包|`from pxhandsdk import pxdex3`|
|C++ 示例|`/usr/share/pxhandsdk/examples/amd64/C++/pxdex3_demo.cpp`|
|Python 示例|`/usr/share/pxhandsdk/examples/amd64/python/pxdex3_demo.py`|
|Linux 手册|`/usr/share/doc/pxhandsdk/pxdex3使用手册.md`|

## 3. 运行前注意事项

### 3.1 安全检查

|检查项|要求|不满足时的处理|
|---|---|---|
|机械空间|手指全行程无人员、线缆和障碍物。|禁止使能，先清理并设置物理防护。|
|急停与失能|业务具备停止运动和断电方案。|完成安全措施后再测试运动。|
|设备状态|供电、线束、关节和传感器连接可靠。|修复硬件异常后只读验证。|
|串口|端口存在、用户有权限且没有其他进程占用。|重新枚举、配置 `dialout`、关闭占用方。|
|目标位置|四路目标均在公开范围及设备限位内。|先读取 `get_position_limit()` 并在业务侧校验。|
|调用顺序|控制、维护和采集应避免相互冲突。|同一 handle 不要同时执行相互冲突的操作。|

#### 温度保护提示

上位机应通过 `pxdex3_get_motor_temperature()` 或连续采集帧中的 `motor_temperature[4]` 持续监控四路电机温度，单位为 `°C`。只要任一路温度高于 `80°C` 即开始计时；该路温度回落到 `80°C` 或以下时重新计时。若同一路温度连续超过 `80°C` 达到 5 秒，上位机应提示“电机温度持续超过 80°C，灵巧手不可控”，停止下发新的运动目标，并由现场安全流程决定失能或断电。

SDK 只返回温度数据，不自动停机、失能、断开连接或拦截运动目标。温度监控与安全处置由上位机负责；读取间隔应显式记录，不能把未采样的时间视为已确认安全。

### 3.2 上电、回零和运动前提

- 连接成功后，业务仍应调用 `pxdex3_get_position_limit()` 查看当前限位。
- 每次重新上电并连接后，位置控制前建议调用 `pxdex3_set_magnetic_encoder_zero()`，使设备回到磁编读数为零的物理位置。
- `pxdex3_set_encoder_calibration()` 用于保存当前零点；它不同于驱动设备回到零位的操作。
- 使用位置控制前应确认设备处于可控状态，并根据公开接口返回值判断是否可以继续。
- 切换控制模式或执行维护操作前，应先完成安全检查并按公开 API 的返回结果处理。

#### 标零与回零：是否需要断电

`pxdex3_set_encoder_calibration()` 与 `pxdex3_set_magnetic_encoder_zero()` 名称相近，但用途、机械风险和断电要求不同，不能互换使用。

|接口|实际作用|是否需要断电|推荐流程|
|---|---|---|---|
|`pxdex3_set_encoder_calibration()`（磁编标零）|保存当前零点，不主动驱动手指。|按当前固件和设备说明执行。|在安全环境中调用并确认返回值。|
|`pxdex3_set_magnetic_encoder_zero()`（磁编回零）|执行回零操作，可能产生机械运动。|按当前固件和设备说明执行。|确认机械空间安全后调用，并检查返回结果。|

执行标零或回零前，应确认机械空间安全、设备状态稳定且具备失能措施。过程中不要施加外力或同时执行其他改变设备状态的操作；调用失败、姿态异常或出现故障时，应立即停止后续操作并按第 7 章记录和排障。

### 3.3 并发与回调

- 连续采集期间请减少同一设备上的并发操作，避免影响数据稳定性。
- 不要在采集回调中调用 `pxdex3_stop_collection()`；停止操作应在回调外执行。
- 回调仅复制数据或快速转交，不执行写盘、网络阻塞或耗时处理。
- C 回调中的 `data` 仅在本次回调期间有效；需要长期保存时必须复制。
- C++/Python 回调应自行捕获异常。
- 时间戳表示主机侧数据可用时间，不是设备采样时间。应用应以收到的完整数据和时间戳为准。

## 4. 快速使用

### 4.1 环境与安装

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
ls -l /dev/ttyACM* /dev/ttyUSB* 2>/dev/null
```

#### tar.gz 免安装方式

如果交付物为 `pxhandsdk_1.0.0.0.ubantu2204_amd64.tar.gz`，不要执行 `dpkg`。解压后设置：

```bash
tar -xzf pxhandsdk_1.0.0.0.ubantu2204_amd64.tar.gz
export PXHANDSDK_ROOT="$PWD/pxhandsdk_1.0.0.0.ubantu2204_amd64"
export LD_LIBRARY_PATH="$PXHANDSDK_ROOT/lib/pxhandsdk:$PXHANDSDK_ROOT/lib/pxhandsdk/core${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export PYTHONPATH="$PXHANDSDK_ROOT/lib/python3/pxhandsdk/dist-packages${PYTHONPATH:+:$PYTHONPATH}"
```

后续示例中的 `/usr/share/pxhandsdk` 替换为 `$PXHANDSDK_ROOT/share/pxhandsdk`，CMake 的
`CMAKE_PREFIX_PATH` 替换为 `$PXHANDSDK_ROOT`。tar.gz 不自动配置 udev 和用户组；串口权限仍需单独处理。
DEB 与 tar.gz 不得跨版本或跨架构混用。

### 4.2 安装示例的编译与运行

DEB 同时安装 C++ 和 Python 示例。默认流程只执行连接、读取和错误检查，不标零、不写 SN，也不启动连续采集。

#### C++ 示例

直接使用安装目录中的示例和随 DEB 安装的 CMake package 编译：

```bash
cmake -S /usr/share/pxhandsdk/examples/amd64/C++ -B "$PWD/pxhandsdk-cpp-build" \
  -DCMAKE_PREFIX_PATH=/usr
cmake --build "$PWD/pxhandsdk-cpp-build" --target pxdex3_demo -j

# 默认连接与读取验证
"$PWD/pxhandsdk-cpp-build/pxdex3_demo" /dev/ttyUSB0
```

#### C++ 角度控制

完成第 3 章安全检查后，可通过 `pxdex3_set_motor_angles()` 提交公开范围内的角度目标，并根据返回值和位置读取结果确认状态。涉及运动、标定或 SN 的操作应在受控环境中按公开 API 执行。

使用 tar.gz 时，将示例复制和 CMake 路径替换为包根目录：

```bash
cmake -S "$PXHANDSDK_ROOT/share/pxhandsdk/examples/amd64/C++" -B "$PWD/pxhandsdk-cpp-build" \
  -DCMAKE_PREFIX_PATH="$PXHANDSDK_ROOT"
cmake --build "$PWD/pxhandsdk-cpp-build" --target pxdex3_demo -j
"$PWD/pxhandsdk-cpp-build/pxdex3_demo" /dev/ttyUSB0
```

#### Python 示例

DEB 绑定由系统 Python 3.10 加载，推荐显式使用 `/usr/bin/python3`：

```bash
# 默认连接与读取验证
/usr/bin/python3 /usr/share/pxhandsdk/examples/amd64/python/pxdex3_demo.py /dev/ttyUSB0
```

tar.gz 使用同一套包内运行库环境：

```bash
/usr/bin/python3 "$PXHANDSDK_ROOT/share/pxhandsdk/examples/amd64/python/pxdex3_demo.py" /dev/ttyUSB0
```

首次接入建议只执行连接、读取和错误检查；运动、标定及 SN 等会改变设备状态的能力，应在只读验收完成后按公开 API 按需调用。

### 4.3 C++ 连接与读取验证

以下最小程序创建会话、连接、读取公开信息，然后断开：

```cpp
#include <pxdex3.h>

#include <iostream>

int main(int argc, char* argv[]) {
  const char* port = argc > 1 ? argv[1] : "/dev/ttyUSB0";
  pxdex3_handle_t* hand = pxdex3_create();
  if (hand == nullptr) return 1;

  if (pxdex3_connect(hand, port) != 0) {
    PxDex3ErrorInfo error{};
    pxdex3_get_last_error(hand, &error);
    std::cerr << error.code << ": " << error.message << '\n';
    pxdex3_destroy(hand);
    return 1;
  }

  PxDex3VersionInfo version{};
  int16_t position[PXDEX_MOTOR_NUM]{};
  const int version_rc = pxdex3_get_firmware_versions(hand, &version);
  const int position_rc = pxdex3_get_current_motor_position(hand, position);
  if (version_rc == 0) std::cout << "firmware=" << version.firmware_version << '\n';
  if (position_rc == 0) {
    std::cout << "position=" << position[0] << ',' << position[1] << ','
              << position[2] << ',' << position[3] << '\n';
  }

  const int disconnect_rc = pxdex3_disconnect(hand);
  pxdex3_destroy(hand);
  return version_rc == 0 && position_rc == 0 && disconnect_rc == 0 ? 0 : 1;
}
```

保存为 `pxdex3_read_only.cpp` 后，可使用 `pkg-config` 直接编译运行：

```bash
export PKG_CONFIG_PATH="/usr/lib/pkgconfig/pxhandsdk${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"
c++ -std=c++17 pxdex3_read_only.cpp -o pxdex3_read_only \
  $(pkg-config --cflags --libs pxdex3-sdk)
./pxdex3_read_only /dev/ttyUSB0
```

### 4.4 Python 只读验证

```python
from pxhandsdk import pxdex3

hand = pxdex3.PxDex3()
rc = hand.connect_device('/dev/ttyUSB0')
if rc == 0:
    rc, version = hand.get_firmware_versions()
    if rc == 0:
        print(version.firmware_version)
    rc, position = hand.get_current_motor_position()
    if rc == 0:
        print(position.index_proximal_pos, position.index_distal_pos)
    hand.disconnect_device()
else:
    print(hand.get_last_error())
```

首次验收应覆盖版本、当前位置、温度、电流、触觉、编码器、故障读取和正常断开。只有建立机械安全条件后，才验证失能、模式、使能、回零和小范围位置目标。

### 4.5 C++ 项目集成

推荐使用随 DEB 安装的 CMake imported target。它会传递头文件、SDK 动态库及所需运行时依赖：

```cmake
cmake_minimum_required(VERSION 3.16)
project(my_pxdex3_app LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(PxDex3SDK REQUIRED CONFIG)
add_executable(my_pxdex3_app main.cpp)
target_link_libraries(my_pxdex3_app PRIVATE pxdex3sdk::pxdex3_sdk)
```

```bash
cmake -S . -B build -DCMAKE_PREFIX_PATH=/usr
cmake --build build -j
./build/my_pxdex3_app /dev/ttyUSB0
```

### 4.6 Python 项目集成

Python 无需链接 CMake target，也不要从 PyPI 另装同名包。DEB 将 `pxhandsdk` 安装到系统 Python 路径；应用直接导入聚合类或产品子模块：

```python
import pxhandsdk

hand = pxhandsdk.PxDex3()
# 等价写法：hand = pxhandsdk.pxdex3.PxDex3()
```

部署前先做导入检查：

```bash
/usr/bin/python3 -c "import pxhandsdk; print(pxhandsdk.PxDex3)"
```

若项目需要虚拟环境，应使用同版本的系统 Python 并允许访问系统安装包：

```bash
/usr/bin/python3 -m venv --system-site-packages .venv
.venv/bin/python -c "import pxhandsdk; print(pxhandsdk.PxDex3)"
.venv/bin/python app.py
```

Conda、不同 Python 小版本或未启用 `--system-site-packages` 的 venv 默认看不到 DEB 安装的绑定；应使用 `/usr/bin/python3`，或重新创建符合上述条件的环境。

## 5. 使用介绍

### 5.1 公开数据对象

|对象|内容|
|---|---|
|`PxDex3MotorPosition`|四路当前位置或目标位置。|
|`PxDex3PositionLimit`|四路最小/最大位置限位。|
|`PxDex3VersionInfo`|主固件、四路电驱版本和有效传感器版本。|
|`PxDex3SensorData`|单个固定触觉槽位的合力、分布力和有效数量。|
|`PxDex3EncoderRaw` / `PxDex3EncoderAngles`|四路编码器数据和角度。|
|`PxDex3CollectionData`|时间戳、位置、电流、温度、合力、444 点分布力、四路编码器数据及故障汇总。|
|`PxDex3FaultInfo`|传感器故障；磁编码器故障字段当前为 ABI 保留且数量固定为 0。|

力值 `x/y/z` 单位均为 `0.1N`，其中 `x/y` 为有符号分量，`z` 为无符号分量。触觉接口使用输入容量/输出实际数量语义，容量不足时应依据返回数量重新分配。

### 5.2 全部接口分类

#### 5.2.1 会话、版本和 SN

|C API / Python|属性|功能与限制|
|---|---|---|
|`pxdex3_create()` / `PxDex3()`|创建|创建会话，不连接设备。|
|`pxdex3_destroy()` / 对象析构|销毁|停止业务和采集后释放。|
|`pxdex3_connect()` / `connect_device()`|连接|连接指定串口并建立设备会话。|
|`pxdex3_is_connected()` / `is_connected()`|读取|查询当前连接状态；连续采集期间以接口返回值和回调终态为准。|
|`pxdex3_disconnect()` / `disconnect_device()`|断开|停止采集后断开设备；不得在采集回调中调用。|
|`pxdex3_get_last_error()` / `get_last_error()`|读取|最近失败，成功调用不会清除。|
|`pxdex3_get_sdk_version()` / `get_sdk_version()`|读取|SDK 版本和打包时间。|
|`pxdex3_get_firmware_versions()` / `get_firmware_versions()`|读取|主固件、电驱和传感器版本。|
|`pxdex3_get_sn()` / `get_sn()`|读取|读取 SN；C 缓冲区建议至少 247 字节。|
|`pxdex3_set_sn()` / `set_sn()`|写入|写入最长 246 字节的 SN；成功后建议重新读取核对。|

#### 5.2.2 电机状态与控制

|C API / Python|属性|功能与限制|
|---|---|---|
|`pxdex3_get_current_motor_position()` / `get_current_motor_position()`|读取|四路当前位置。|
|`pxdex3_get_motor_temperature()` / `get_motor_temperature()`|读取|四路温度，单位 °C。|
|`pxdex3_get_motor_current()` / `get_motor_current()`|读取|四路电流，单位 mA。|
|`pxdex3_get_motor_control_mode()` / `get_motor_control_mode()`|读取|当前控制模式。|
|`pxdex3_set_motor_control_mode()` / `set_motor_control_mode()`|配置|切换控制模式；切换期间不要并发下发运动目标。|
|`pxdex3_is_motor_enabled()` / `is_motor_enabled()`|读取|查询整体电机使能状态。|
|`pxdex3_enable_motor()` / `enable_motor()`|控制|使能全部电机；执行前确认机械安全。|
|`pxdex3_disable_motor()` / `disable_motor()`|控制|失能全部电机。|
|`pxdex3_get_target_position()` / `get_target_position()`|读取|当前四路目标位置。|
|`pxdex3_get_position_limit()` / `get_position_limit()`|读取|读取四路最小/最大限位。|
|`pxdex3_set_motor_position()` / `set_motor_position()`|写入|设备和电机均已使能时写绝对目标；SDK 不检查或切换控制模式，目标必须在四路范围内。|
|`pxdex3_get_motor_angles()` / `get_motor_angles()`|读取|位置控制模块的四路当前关节角反馈，单位为度；只读，不会驱动电机。|
|`pxdex3_set_motor_angles()` / `set_motor_angles()`|读写|接收四路 degree 目标；提交后立即返回，不等待机械到位。|

`pxdex3_get_motor_angles()` / `get_motor_angles()` 只读取位置控制使用的四路当前位置反馈，
输出单位为 degree，不会写目标或驱动电机；合并后的角度写接口目标输入单位也为 degree。

`pxdex3_get_position_limit()` / `get_position_limit()` 返回当前四路位置范围。位置 `0` 可用于回零和张开端目标；业务安全范围如更严格，应取两者交集。未连接时的设备访问返回 `DEVICE_NOT_CONNECTED (122)`；连接后的访问失败按 `SERIAL_IO_ERROR (103)` 或对应专用设备错误处理。

`pxdex3_set_motor_angles()` 接收四路 `target_angles_deg`，顺序为食指近端、食指远端、中指近端和中指远端。目标必须是有限值，指腹通道范围为 `0..58 degree`，指尖通道范围为 `0..42 degree`，并受设备位置限位约束。

位置和角度目标接口要求设备与电机已使能；SDK 不检查或切换电机控制模式。目标位置越过设备限位返回 `VALUE_OUT_OF_RANGE (118)`，实际目标写入或通信失败返回 `MOTOR_TARGET_FAILED (164)`。

调用 `pxdex3_set_motor_angles()` / `set_motor_angles()` 是非阻塞目标提交；返回 `0` 表示目标已接受，不表示机械已经到位。失败时通过 `pxdex3_get_last_error()` / `get_last_error()` 获取错误信息。

角度目标以设备当前零点为基准。调用方应为机械运动预留时间，再读取角度反馈；读取或写入失败时通过 `pxdex3_get_last_error()` 获取原因。每次设备重新上电后，应先完成公开的回零流程再进行角度控制。

**警告**：角度接口会产生实际运动，不得与同一 handle 上的其他运动写接口并发调用。首次使用时，必须在受控环境中验证运动方向、目标范围和安全限位。设备重启后应重新连接并再次回零。

#### 5.2.3 触觉、编码器与采集

采集帧同时提供 `encoder_raw` 和 `angles_deg`；`angles_deg` 为四路角度反馈，单位为度。

|C API / Python|属性|功能与限制|
|---|---|---|
|`pxdex3_get_sensor_data()` / `get_sensor_data()`|读取|最多十六组容量，当前固定返回十路完整触觉。|
|`pxdex3_get_sensor_resultant_force()` / `get_sensor_resultant_force()`|读取|平铺返回十路合力。|
|`pxdex3_get_sensor_distribute_force()` / `get_sensor_distribute_force()`|读取|平铺返回 444 个分布力点。|
|`pxdex3_get_encoder_raw_data()` / `get_encoder_raw_data()`|读取|读取四路编码器数据。|
|`pxdex3_start_collection()` / `start_collection()`|启动|频率大于 0；允许其他接口，并发访问会影响实际采集频率。|
|`pxdex3_stop_collection()` / `stop_collection()`|停止|未采集时返回成功；回调外调用。|

#### 5.2.4 诊断和维护

|C API / Python|属性|功能与限制|
|---|---|---|
|`pxdex3_get_fault_code()` / `get_fault_code()`|读取|传感器故障；磁编故障数量当前固定为 0。|
|`pxdex3_set_encoder_calibration()` / `set_encoder_calibration()`|写入|保存当前磁编零点；具体生效条件以当前设备说明为准。|
|`pxdex3_set_magnetic_encoder_zero()` / `set_magnetic_encoder_zero()`|运动|驱动到已生效磁编零点对应的物理位置；执行前确认机械空间安全。|
|`pxdex3_set_sensor_calibration()` / `set_sensor_calibration()`|写入|执行传感器标零。|

PxDex3 当前没有公开固件升级接口。错误目录中的 `140–142/4010` 为统一目录兼容项，不代表本产品提供升级入口。

### 5.3 连续采集建议

连续采集帧包含四路位置、电流和温度、十路合力、444 点分布力、四路编码器数据及传感器故障汇总。目标频率是期望值，实际频率受系统负载、回调耗时和接口调用影响；回调应快速复制数据后返回。

随包 C++/Python 示例提供连续采集 API 演示。实际采集结果受运行环境和设备状态影响；如数据不稳定，应先停止其他操作，再检查设备状态。

`pxdex3_stop_collection()` 返回 `0` 表示采集已停止。回调帧数不等同于应用已完成存储或网络发送，业务侧应单独确认数据消费结果。

## 6. 注意事项

- 任何运动前确认机械空间、限位、控制模式、使能状态和急停路径。
- 收到电机、编码器、过压、过流、过温或断联故障后停止新目标并优先失能。
- 每次上电连接后，在位置控制前完成磁编码器回零验证。
- 标零、写 SN、模式切换和回零属于有副作用操作，应记录操作者、时间、前后状态和结果。
- 采集与控制并发会影响频率，不能用回调次数作为无损采样证明。
- 断线后停止控制循环，重新连接和只读验证成功后再恢复运动。

## 7. 错误码与排障

### 7.1 错误语义和恢复原则

返回 `0` 表示本次调用成功。C 读取 `PxDex3ErrorInfo`，Python `get_last_error()` 返回 `(error_code, error_message)`；成功调用不会清除历史错误。运动接口失败后不得继续下发后续目标。

恢复顺序：停止目标写入 → 确保机械安全并尝试失能 → 记录 API、返回值和最近错误 → 检查串口/设备故障 → 重连后只读验证 → 回零和小范围运动验证。

### 7.2 主机与参数错误

|错误码|稳定错误名|处理|
|---:|---|---|
|100 / 101 / 102|端口不存在、无权限或被占用|重新枚举、配置 `dialout`、关闭占用方。|
|103|`SERIAL_IO_ERROR`：串口输入输出错误|停止控制，检查串口、供电和线缆，确认设备未被其他程序占用后重连。|
|105|`SERIAL_TIMEOUT`：串口操作超时|停止当前操作，检查设备供电、使能状态和线缆后重连。|
|104 / 107|参数或串口配置错误|修正端口字符串并检查驱动。|
|106 / 109 / 110 / 111|未打开、描述符失效、设备移除或打开失败|停止会话并重新创建连接。|
|108|`ALREADY_RUNNING`|流已启动；避免重复启动采集。|
|112|`INVALID_HANDLE`|修正 handle 生命周期。|
|113 / 114|输入或输出指针为空|提供有效结构、数组和回调。|
|115 / 116 / 117|缓冲区、计数或容量错误|按输入容量/输出数量约定重新分配。|
|118|`VALUE_OUT_OF_RANGE`|修正频率、位置、模式、字符串长度或其他输入；目标位置超出设备限位时，调整四路目标位置。|
|119 / 120|设备识别失败或未分类异常|核对产品并保存完整日志。|
|121|`DEVICE_VERSION_MISMATCH`|兼容保留；核对库、头和 Python 包版本。|
|122|`DEVICE_NOT_CONNECTED`|设备会话尚未建立；先成功调用 `pxdex3_connect()`。|

### 7.3 设备故障错误

|错误码|含义|建议处理|
|---:|---|---|
|200 / 201|电机过压 / 欠压|停止运动并检查电源质量。|
|202–204 / 208|U/V/W 相或 IQ 过流|立即停止目标并失能，检查负载、堵转和驱动。|
|205|电机过温|失能并等待冷却，检查负载与散热。|
|206 / 207|ADC 自校准或 FOC 计算错误|停止控制，重启仍存在时联系支持。|
|209–211|U/V/W 相开路|断电检查电机相线和连接器。|
|212 / 213|位置参考超上限 / 下限|修正目标和业务限位，不重复下发。|
|214–216|编码器 ABZ、Z 相或标定错误|停止运动，检查编码器并重新评估标定。|
|217 / 218|速度参考或电流参考超限|降低控制目标和限制参数。|
|219|关节磁编码器故障|停止依赖该关节的运动并检查连接。|
|220–230|设备保留故障位 4–14|按设备原始故障处理，保存日志并联系支持。|
|231|电机断开|立即停止控制并检查电机连接。|
|161|`MOTOR_ENABLE_FAILED`|电机使能状态未确认；检查设备使能和四路工作状态。|
|162|`MOTOR_DISABLE_FAILED`|电机失能状态未确认；停止目标下发并检查设备响应。|
|163|`MOTOR_MODE_FAILED`|控制模式切换失败；确认电机已失能并检查通信日志。|
|164|`MOTOR_TARGET_FAILED`|目标值写入或通信失败；目标位置超出设备限位时返回 `VALUE_OUT_OF_RANGE (118)`。|
|165|`ENCODER_READ_FAILED`|磁编码器读取失败；检查磁编连接、供电和串口响应。|
|166|`MOTOR_HOMING_FAILED`|电机回零失败；确认机械无阻挡并检查回零状态。|
|167|`SN_WRITE_FAILED`|SN 写入失败；检查设备连接及写入响应。|
|168|`SN_READBACK_MISMATCH`|SN 回读不一致；检查设备是否接受写入。|
|169|`COLLECTION_FRAME_FAILED`|连续采集帧获取失败。检查串口和设备状态。|
|170|`ANGLE_SETTLE_TIMEOUT`|兼容保留错误码；当前非阻塞角度接口不执行到位等待，也不返回该码。|
|171|`SN_READ_FAILED`|设备序列号读取失败；检查连接并保存日志。|
|172|`MOTOR_CONTROL_MODE_MISMATCH`|兼容保留错误码；位置和角度目标接口当前不再检查控制模式，不返回该码。|
|173|`MOTOR_NOT_ENABLED`|电机未使能；按公开 API 约定完成使能。|
|174|`DEVICE_NOT_ENABLED`|设备未使能，运动失败；先恢复设备使能状态。|

错误码 `140–142/4010` 属于全局固件升级目录，但当前 PxDex3 没有公开升级 API；若业务收到这些值，应核对是否混用了其他产品库、绑定或错误上下文。

反馈问题时提供 SDK 与固件版本、设备 SN、端口、控制模式、使能状态、四路位置与限位、失败 API、直接返回值、最近错误、复现步骤和脱敏日志。

## 8. 总结

本手册说明了 PxDex3 从安装、连接和状态读取，到触觉采集、磁编码器、维护标定与位置控制的完整流程。运动能力必须建立在机械安全、回零、限位、模式和使能状态均明确的基础上。

我司希望本手册帮助开发者安全、稳定地将三指执行器集成到机器人控制、数据采集和具身智能应用中。遇到异常时，应先确保机械安全，再依据第 7 章保存上下文并排障。

## 9. 版权声明

1. **知识产权归属：** PXHandSDK、PxDex3 SDK 及配套软件、动态库、头文件、绑定、示例和文档的相关知识产权归帕西尼感知科技有限公司或相应权利人所有。授权范围外不得复制、修改、反向工程、再许可、销售或分发 SDK 本身。
2. **版本更新与变更：** SDK、设备固件和文档可能随正式版本更新，应使用同一交付版本内容。
3. **无担保条款：** 在适用法律允许范围内，本 SDK、示例和文档按“现状”（AS IS）提供，具体保证以正式协议为准。
4. **责任限制：** 开发者应完成机械安全、目标环境、异常保护和上线风险评估；责任边界以双方正式协议为准。
5. **问题反馈：** 请提供版本、SN、端口、模式、使能状态、API、返回值、最近错误、复现步骤和脱敏日志。
6. **授权与合作：** 商业授权、产品采购和合作需求请联系 [mkt@paxini.com](mailto:mkt@paxini.com)。

版权所有 © 帕西尼感知科技有限公司。保留所有权利。
