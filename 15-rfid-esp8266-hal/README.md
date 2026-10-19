# 15 · ESP8684 WiFi + RFID + 工程化

> 对应课程：15-RFID+ESP8266+HAL+CubeMX
> 前置要求：第 07 章（串口）、第 14 章（SPI）
> 建议耗时：5-7 天

---

## 本章实板资源

| 资源 | 引脚 | 说明 |
|---|---|---|
| ESP8684-MINI-1 WiFi | USART2：PB10=TX、PB11=RX；**PG7=WiFi_EN** | 板载，ESP32-C2 内核，出厂 **AT 固件** |
| J26 跳线 | 模组侧 | **短接=固件升级模式**；上电 1-2s 后须拔掉 |
| RC522 RFID | 无板载 | 外接；注意 SPI0 已被 GD25Q32 占用，用空闲 SPI（排针引出） |
| 上位机/云平台 | PC + MQTT/HTTP | ESP8684 走 TCP |

> F103 时代外接 ESP8266；本板 **WiFi 模组直接板载**，
> 而且从 ESP8266 升级成了 **ESP8684（ESP32-C2，AT 固件）**，RISC-V 内核但用法一样。

---

## 一、学习内容

### 1. ESP8684 上电时序（本板特有）

```
① PG7(WiFi_EN) 拉高            → 开 WiFi 独立电源域
② 等 1~2 秒                    → 模组初始化（AT 固件启动）
③ （正常模式）J26 跳线帽拔掉   → 短接 J26 = 进下载模式，AT 固件不跑
④ USART2 @115200 8N1 发 AT     → 应回 OK
```

升级固件时反过来：断开 WiFi 电源 → 短接 J26 → 上电 → 用 ESP 工具烧 → 烧完断电拔 J26。

### 2. AT 命令套路（与 ESP8266 同源）

| 命令 | 作用 |
|---|---|
| `AT` | 握手，回 `OK` |
| `AT+RST` | 复位模组 |
| `AT+GMR` | 查版本 |
| `AT+CWMODE=1` | Station 模式 |
| `AT+CWJAP="ssid","pwd"` | 连路由器 |
| `AT+CIPSTART="TCP","ip",port` | 建 TCP 连接 |
| `AT+CIPSEND=n` → 数据 → （透传等 `>`） | 发数据 |
| `AT+CIPCLOSE` | 关连接 |
| `AT+CIPSTATUS` | 查连接状态 |

**工程要点**：

- 一条一发，**发完等 `OK`/`SEND OK` 再发下一条**（状态机！）
- 用第 07 章的**中断接收 + 行缓冲**，主循环状态机解析
- 超时保护：每条命令 2~5s 没回 OK 就重发/报错
- WiFi_EN 拉高后模组没起来就发 AT → 永远 `ERROR`

### 3. RFID（RC522，外接）

- SPI 接口，13.56MHz，读 MIFARE S50 卡（16 扇区/64 块）
- 流程：寻卡（`REQA`）→ 防冲突 → 选卡 → 认证（KeyA/KeyB）→ 读块（16 字节）
- 寄存器操作多，用现成驱动（`rc522.c`）比裸调寄存器现实
- **接线注意**：SPI0 被 Flash 占了 → RC522 接空闲 SPI（如排针上的 SPI1/SPI2）+ 独立 CS

### 4. HAL / CubeMX 与 GD32 生态（概念对齐）

| 问题 | 事实 |
|---|---|
| GD32F30x 有官方 HAL 吗 | 官方主线是 **SPL**（本工作区用的）；HAL 主要在 GD32F4xx/MC23 等新系列 |
| CubeMX 支持 GD32F30x 吗 | **不支持**。STM32CubeMX 只出 ST 芯片工程 |
| GD 自己的工具 | **GD32 MCU ISP**（串口下载）、**GD32 All-in-One Programmer**、**GD-Link** |
| EIDE 里怎么管 | 器件 Pack `GD32F30x_DFP`（已装），工程用 `eide.yml` 管，比 CubeMX 轻 |
| "HAL 化"怎么落地 | 自己按 HAL 风格封装：`MX_GPIO_Init()` 等一层薄封装，业务代码只调 `HAL_风格` API |

> 本章的"工程化"指：**驱动分层 + 状态机 + 错误处理**，不是换库。
> 真需要 HAL 风格，就在 SPL 上包一层（例程见下）。

### 5. 状态机写法（AT 命令引擎雏形）

```
IDLE → 发命令 → WAIT_OK/WAIT_DATA → 解析回包 → IDLE
                 └─ 超时 → 重发 n 次 → ERROR
```

---

## 二、学习目标

- [ ] 能按正确时序初始化板载 ESP8684 并 `AT` 握手成功
- [ ] 能用状态机 + 行缓冲实现"发命令 → 等回 → 解析"的 AT 引擎
- [ ] 能连路由器并建立 TCP，把传感器数据发到 PC 上位机（网络调试助手）
- [ ] 能说出 RC522 的接线约束（SPI0 被占）和认证-读块流程
- [ ] 能解释 GD32F30x 生态里"HAL/CubeMX"的真实情况，不背错概念

---

## 三、学习方法

1. **先裸发 AT**：主循环 `printf` 式逐条发，看回什么——建立"模组在干什么"的直觉。
2. **再状态机化**：把逐条发送改状态机，加超时重试。
3. **抓串口时序**：逻辑分析仪抓 PB10/PB11，确认发的字节和回包时序。
4. **J26 实验**：短接 J26 上电，观察 AT 无响应；拔掉恢复正常——理解启动模式。
5. **RC522 先跑现成驱动**：能读卡后再回头看寄存器流程。

---

## 四、标准示例

### 1. ESP8684 初始化（USART2 + WiFi_EN）

```c
#include "gd32f30x.h"

#define WIFI_EN_GPIO  GPIOG
#define WIFI_EN_PIN   GPIO_PIN_7

void wifi_en_init(void)
{
    rcu_periph_clock_enable(RCU_GPIOG);
    gpio_init(WIFI_EN_GPIO, GPIO_MODE_OUT_PP, GPIO_OSPEED_2MHZ, WIFI_EN_PIN);
    gpio_bit_reset(WIFI_EN_GPIO, WIFI_EN_PIN);       /* 先断电 */
}

void usart2_init(void)
{
    rcu_periph_clock_enable(RCU_GPIOB);
    rcu_periph_clock_enable(RCU_USART2);
    gpio_init(GPIOB, GPIO_MODE_AF_PP, GPIO_OSPEED_50MHZ, GPIO_PIN_10);
    gpio_init(GPIOB, GPIO_MODE_IPU,  GPIO_OSPEED_2MHZ,  GPIO_PIN_11);

    usart_deinit(USART2);
    usart_baudrate_set(USART2, 115200U);
    usart_parity_config(USART2, USART_PM_NONE);
    usart_word_length_set(USART2, USART_WL_8BIT);
    usart_stop_bit_set(USART2, USART_STB_1BIT);
    usart_transmit_config(USART2, USART_TRANSMIT_ENABLE);
    usart_receive_config(USART2, USART_RECEIVE_ENABLE);
    usart_enable(USART2);
}

void wifi_power_on(void)
{
    gpio_bit_set(WIFI_EN_GPIO, WIFI_EN_PIN);   /* 开 WiFi 电源域 */
    delay_1ms(2000);                           /* 等模组起来（1~2s） */
    /* 确认 J26 未短接 */
}

void wifi_send_cmd(const char *cmd)
{
    printf_usart2(cmd);        /* 走 USART2 的 printf（自实现 _write 分支或 usart_send_string） */
    printf_usart2("\r\n");
}
```

### 2. AT 引擎（状态机 + 行缓冲，基于第 07 章）

```c
typedef enum {
    WIFI_IDLE = 0,
    WIFI_WAIT_OK,
    WIFI_WAIT_DATA,
    WIFI_ERROR,
} wifi_state_t;

static wifi_state_t s_state = WIFI_IDLE;
static uint32_t     s_timeout;

void wifi_poll(void)                    /* 主循环周期调 */
{
    if (s_state == WIFI_IDLE) {
        /* 取出下一个待发命令（队列/状态表驱动） */
        wifi_send_cmd(next_cmd());
        s_state = WIFI_WAIT_OK;
        s_timeout = g_tick_ms + 3000U;
    } else if (s_state == WIFI_WAIT_OK) {
        if (g_tick_ms > s_timeout) {
            s_state = WIFI_ERROR;       /* 超时 */
        }
    }
    /* 行到达时（USART2 中断置 g_rx_line_ready）解析：
       strstr(line, "OK")     → s_state = WIFI_IDLE（下一步）
       strstr(line, "ERROR")  → s_state = WIFI_ERROR
       strstr(line, "+IPD")   → 收到网络数据，处理 payload */
}
```

### 3. 上传一帧数据到 TCP 服务器

```c
/* 前置：AT+CWMODE=1 / AT+CWJAP="ssid","pwd"（等 OK）/ AT+CIPSTART="TCP","1.2.3.4",8080 */
void wifi_upload(const char *payload)
{
    char cmd[32];
    sprintf(cmd, "AT+CIPSEND=%d", (int)strlen(payload));
    wifi_send_cmd(cmd);
    /* 等 '>' 提示符 */
    wifi_send_cmd(payload);
    /* 等 "SEND OK" */
}
```

### 4. HAL 风格薄封装（在 SPL 上"假装 HAL"）

```c
/* hal_style.h —— 业务代码只调这些，不见 SPL */
void MX_GPIO_Init(void);
void MX_USART0_UART_Init(void);

void MX_GPIO_Init(void)
{
    rcu_periph_clock_enable(RCU_GPIOA);
    gpio_init(GPIOA, GPIO_MODE_OUT_PP, GPIO_OSPEED_50MHZ, GPIO_PIN_8);
}
/* 迁移到别的库（真 HAL/LL）时只改这一层，main.c 不动 —— 分层的意义 */
```

---

## 五、自我检测

1. 写出 ESP8684 上电初始化顺序（含 PG7 和 J26），说错一步会怎样。
2. 为什么 AT 命令要"一条一等"？并发发两条会出什么现象？
3. 画出 AT 引擎状态机的转换图（含超时分支）。
4. RC522 接不了 SPI0 的原因是什么？你可以怎么接？
5. `AT+CIPSEND=n` 之后模组回什么？数据发错的后果？
6. GD32F30x 能用 CubeMX 吗？官方推荐的工程/下载工具分别是什么？
7. "HAL 风格封装"和"真用 HAL 库"的区别是什么？分层的收益在哪？
8. WiFi 模块的 TX/RX 与 MCU 怎么接？为什么有时要交叉有时不交叉（模组已内置交叉）？

---

## 六、常见坑

| 现象 | 原因 |
|---|---|
| AT 全部无回 / 回 ERROR | ① PG7 没拉高；② 没等 1-2s；③ **J26 短接着**（进了下载模式）；④ 波特率不对 |
| 发第二条命令丢 | 上一条没等 `OK` 就发；模组忙 |
| 连路由器失败 | 只支持 2.4G；SSID/密码错；信号弱；等 `GOT IP` 再下一步 |
| `CIPSEND` 后没有 `>` | 上一步没建 TCP 连接；或模组在发别的 |
| 收不到网络数据 | 没使能 USART2 接收中断；或 `+IPD` 行没解析 |
| 偶发整个卡死 | 模组异常没复位；加看门狗 + `AT+RST` 恢复流程 |
| RC522 读不到卡 | SPI 波特率太高（RC522 ≤ 10MHz）；CS 接错；天线距离 |
| RFID 把 Flash 搞坏 | SPI0 共用冲突（CS 接反会同时选中两个从机） |

---

## 七、拓展练习

1. 完整 AT 引擎：命令表 + 超时重试 + 错误恢复（`AT+RST`），串口可视化状态。
2. 每 5s 上传一次 ADC 三通道到 PC 网络调试助手，带帧序号。
3. 简单应用协议：`{"t":123,"adc":[1,2,3]}` JSON 帧，PC 端 Python 解析画曲线。
4. OTA 思路：ESP8684 下载新固件写内部 FLASH 双分区（只做方案设计+流程图）。
5. RC522：跑通寻卡→认证→读块，把卡号显示到 OLED（外接）或串口。
6. 设计"驱动分层规范"：给本工作区写一份 `Driver/` 命名与接口约定（每个驱动头文件模板）。

---

## 八、本章速查卡模板（学完抄一页纸）

```
【第15章 WiFi/工程化速查】
上电  ：PG7=WiFi_EN 拉高 → 等 1-2s → 确认 J26 未短接 → USART2@115200 发 AT
AT    ：AT/CWMODE=1/CWJAP/CIPSTART/CIPSEND(n→'>'→data→SEND OK)/CIPCLOSE
引擎  ：IDLE→发命令→WAIT_OK(3s超时)→解析行(strstr "OK"/"ERROR"/"+IPD")→IDLE
RFID  ：RC522 外接空闲 SPI（SPI0 被 GD25Q32 占）；≤10MHz；REQA→防冲突→选卡→认证→读块
生态  ：GD32F30x 官方=S PL；无 CubeMX；下载=GD32 ISP/All-in-One；EIDE+DFP 管工程
分层  ：业务只调 MX_风格薄封装；换库只改封装层
坑    ：J26 短接无 AT；并发发命令；2.4G only；没等 '>'
```
