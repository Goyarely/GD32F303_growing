# 09 · RS485 + 超声波 + 位段操作

> 对应课程：09-RS485+超声波+位段操作
> 前置要求：第 07 章（串口）、第 03 章（中断）
> 建议耗时：5-7 天

---

## 本章实板资源

| 资源 | 引脚 | 说明 |
|---|---|---|
| RS485 收发器 | USART1(PA2/PA3) + **PC5=RS485_RE/DE** | 半双工；RE/DE 高=发送、低=接收 |
| 超声波 | 外接 HC-SR04：Trig=PC0、Echo=PC1（均空闲） | 5V 供电，Echo 分压到 3V3 或确认模块 3V3 容忍 |
| 位段 | M4 特性 | 外设别名区 0x42000000 / SRAM 别名区 0x22000000 |

---

## 一、学习内容

### 1. RS485 总线

- 差分传输（A/B 双线），抗共模干扰，**总线式多机**，距离可达千米级
- 本板 U5 SSP485：信号接 USART1(PA2/PA3)，**方向控制 PC5（RE/DE）**
- **半双工**：同一时刻只能一个方向；MCU 发送前拉高 DE，发完拉低
- 帧与普通 USART 完全一样——RS485 只是"物理层"，协议层还是第 07 章那套

### 2. RS485 发送时序（关键）

```
主机：拉高 PC5(DE) → 等 ≥ 若干 us → 发数据 → 等 TC(发送完成) → 拉低 PC5
从机：收到 → 处理 → （若需应答）同样流程回包
```

**发完立刻拉低会切掉最后一字节的停止位**——等 `USART_FLAG_TC` 或加一点延时。

### 3. 超声波 HC-SR04

- Trig 给 **≥10us 高电平**触发
- Echo 回一个高电平脉冲，**宽度 = 单程时间**
- 距离(cm) = Echo 高电平时间(us) / **58**（声速 340m/s 往返）
- 量程 2cm~4m；超时要保护（Echo 不回或一直高）

### 4. 位段操作（Bit-Band）

M4 把两个 1MB 区域的每个 bit 膨胀成一个 32bit 别名字：

| 区域 | 别名区基址 | 覆盖 |
|---|---|---|
| 外设 0x40000000~0x400FFFFF | **0x42000000** | GPIO/RCU/EXTI 等 |
| SRAM 0x20000000~0x200FFFFF | **0x22000000** | 变量位操作 |

```
别名地址 = 别名基址 + (目标字节地址 - 区域基址) × 32 + 位号 × 4
```

例：PA8 的 OCTL（0x4001080C）bit8：

```
0x42000000 + (0x4001080C - 0x40000000)×32 + 8×4
= 0x42000000 + 0x1080C×32 + 0x20
= 0x42000000 + 0x210C00 + 0x20
= 0x42210C20
```

```c
#define BITBAND_PERIPH(addr, bit) \
    (*(volatile uint32_t *)(0x42000000U + ((uint32_t)(addr) - 0x40000000U) * 32U + (bit) * 4U))

BITBAND_PERIPH(&GPIO_OCTL(GPIOA), 8) = 1U;    /* PA8 置 1，等价 gpio_bit_set */
```

**用途**：ISR 里单周期置位（无读-改-写）、多任务共享标志位（SRAM 位段）。
**读-改-写的坑**：`OCTL |= (1<<8)` 是三步（读/改/写），中断里可能被打断；位段写是一步。

---

## 二、学习目标

- [ ] 能画出 RS485 半双工收发时序，并写对 DE 方向控制
- [ ] 能实现"485 发送一帧 → 等回显"的闭环
- [ ] 能写出超声波测距驱动（Trig 触发 + Echo 捕获/轮询 + 超时保护）
- [ ] 能口算任意外设/SRAM 地址的位段别名地址
- [ ] 能解释位段相比读-改-写的优势和使用场景

---

## 三、学习方法

1. **示波器/逻辑分析仪看 DE 与 TX**：观察发完立刻拉低丢停止位的现象，再加 TC 等待。
2. **两台设备对发**：USB-485 模块接 PC，用串口工具验证收发闭环。
3. **Echo 波形实测**：示波器抓 Echo 脉宽，与算出的距离对账（用手在传感器前晃动）。
4. **位段对账**：同一个 PA8 置位，分别用 `gpio_bit_set`、`OCTL |= ...`、位段写，反汇编对比指令数。

---

## 四、标准示例

### 1. RS485 发送一帧（USART1 + PC5 方向）

```c
#include "gd32f30x.h"

#define RS485_DE_GPIO  GPIOC
#define RS485_DE_PIN   GPIO_PIN_5

void rs485_init(void)
{
    rcu_periph_clock_enable(RCU_GPIOC);
    rcu_periph_clock_enable(RCU_GPIOA);
    rcu_periph_clock_enable(RCU_USART1);

    /* DE 方向控制：推挽输出 */
    gpio_init(RS485_DE_GPIO, GPIO_MODE_OUT_PP, GPIO_OSPEED_50MHZ, RS485_DE_PIN);
    gpio_bit_reset(RS485_DE_GPIO, RS485_DE_PIN);        /* 默认接收 */

    /* USART1：PA2=TX(AF_PP), PA3=RX(IPU) */
    gpio_init(GPIOA, GPIO_MODE_AF_PP, GPIO_OSPEED_50MHZ, GPIO_PIN_2);
    gpio_init(GPIOA, GPIO_MODE_IPU,  GPIO_OSPEED_2MHZ,  GPIO_PIN_3);

    usart_deinit(USART1);
    usart_baudrate_set(USART1, 9600U);                  /* 485 长线用 9600 更稳 */
    usart_parity_config(USART1, USART_PM_NONE);
    usart_word_length_set(USART1, USART_WL_8BIT);
    usart_stop_bit_set(USART1, USART_STB_1BIT);
    usart_transmit_config(USART1, USART_TRANSMIT_ENABLE);
    usart_receive_config(USART1, USART_RECEIVE_ENABLE);
    usart_enable(USART1);
}

void rs485_send_buf(const uint8_t *buf, uint16_t len)
{
    gpio_bit_set(RS485_DE_GPIO, RS485_DE_PIN);          /* 切发送 */
    /* 简单延时等收发器翻转（~us 级；要求高可用定时器定时） */
    for (volatile uint16_t i = 0; i < 200U; i++) { }

    for (uint16_t i = 0; i < len; i++) {
        usart_data_transmit(USART1, (uint16_t)buf[i]);
        while (usart_flag_get(USART1, USART_FLAG_TBE) == RESET) { }
    }

    while (usart_flag_get(USART1, USART_FLAG_TC) == RESET) { }  /* 等最后一字节发完 */
    gpio_bit_reset(RS485_DE_GPIO, RS485_DE_PIN);        /* 切接收 */
}
```

### 2. 超声波测距（Trig=PC0 轮询 + Echo=PC1 轮询，含超时）

```c
#define HCSR04_TRIG_GPIO  GPIOC
#define HCSR04_TRIG_PIN   GPIO_PIN_0
#define HCSR04_ECHO_GPIO  GPIOC
#define HCSR04_ECHO_PIN   GPIO_PIN_1

void hcsr04_init(void)
{
    rcu_periph_clock_enable(RCU_GPIOC);
    gpio_init(HCSR04_TRIG_GPIO, GPIO_MODE_OUT_PP, GPIO_OSPEED_50MHZ, HCSR04_TRIG_PIN);
    gpio_init(HCSR04_ECHO_GPIO, GPIO_MODE_IPD,  GPIO_OSPEED_2MHZ,  HCSR04_ECHO_PIN);
    gpio_bit_reset(HCSR04_TRIG_GPIO, HCSR04_TRIG_PIN);
}

/* 返回距离(cm)，0 = 超时/失败。us 时基用 delay_us（SysTick 120M 下 1us≈120 拍，需校准）
   精度要求高时改用 TIMER 捕获（见拓展） */
uint16_t hcsr04_measure(void)
{
    uint32_t timeout, echo_us = 0U;

    /* 触发：≥10us 高电平 */
    gpio_bit_set(HCSR04_TRIG_GPIO, HCSR04_TRIG_PIN);
    for (volatile uint8_t i = 0; i < 12U; i++) { }       /* ~10us @120MHz */
    gpio_bit_reset(HCSR04_TRIG_GPIO, HCSR04_TRIG_PIN);

    /* 等 Echo 变高（超时 30ms ≈ 5m 量程） */
    timeout = 30000U;
    while (gpio_input_bit_get(HCSR04_ECHO_GPIO, HCSR04_ECHO_PIN) == RESET) {
        if (--timeout == 0U) return 0U;
    }

    /* 数 Echo 高电平 us 数（1us 计数环，需实测校准） */
    while (gpio_input_bit_get(HCSR04_ECHO_GPIO, HCSR04_ECHO_PIN) == SET) {
        echo_us++;
        for (volatile uint8_t i = 0; i < 1U; i++) { }    /* 每个 ~1us */
        if (echo_us > 38000U) return 0U;                 /* 超时保护 */
    }

    return (uint16_t)(echo_us / 58U);                    /* cm */
}
```

> 轮询版只用于理解流程；**精度版用 TIMER 输入捕获**（Echo 接 TIMER2_CH0/CH1，
> 记录上升/下降沿 CNT 差值，1us/计数），放到拓展练习。

### 3. 位段操作

```c
/* 定义一次，到处用 */
#define BITBAND_PERIPH(addr, bit) \
    (*(volatile uint32_t *)(0x42000000U + ((uint32_t)(addr) - 0x40000000U) * 32U + (bit) * 4U))
#define BITBAND_SRAM(addr, bit) \
    (*(volatile uint32_t *)(0x22000000U + ((uint32_t)(addr) - 0x20000000U) * 32U + (bit) * 4U))

/* PA8 置 1 —— 单指令，无读-改-写 */
BITBAND_PERIPH(&GPIO_OCTL(GPIOA), 8) = 1U;

/* SRAM 标志位（中断/主循环共享的 bit 级信号量） */
volatile uint32_t g_flags = 0U;
#define FLAG_DATA_READY   0
BITBAND_SRAM(&g_flags, FLAG_DATA_READY) = 1U;
if (BITBAND_SRAM(&g_flags, FLAG_DATA_READY)) { ... }
```

### 4. 位段 vs 读-改-写（反汇编看差异）

```c
/* 读-改-写：3 步，ISR 打断中间态会丢别人的写 */
GPIO_OCTL(GPIOA) |= (1U << 8);

/* 位段：1 个 store，天然原子 */
BITBAND_PERIPH(&GPIO_OCTL(GPIOA), 8) = 1U;
```

---

## 五、自我检测

1. RS485 为什么需要 DE 方向控制？发完立刻拉低会出什么问题？
2. 画出"485 发 3 字节 → 从机回 3 字节"的完整时序（含 DE 电平）。
3. 超声波距离公式 `/58` 怎么来的？为什么量程上限约 4m？
4. 手算：GPIOB 的 OCTL（0x40010C0C）bit6 的位段别名地址。
5. 位段别名区为什么只覆盖 1MB 区域？SRAM 位段基址是多少？
6. `OCTL |= (1<<8)` 在什么场景下会出 bug？位段写为什么不会？
7. Echo 一直不回（超时）不保护会怎样？保护手段有哪两种？
8. 485 总线上多机通信，为什么建议"主从轮询"而不是"随意抢答"？

---

## 六、常见坑

| 现象 | 原因 |
|---|---|
| 485 发出去对方收不到/丢最后一字节 | DE 拉低太早，切掉停止位；等 `USART_FLAG_TC` 再拉低 |
| 485 完全不通 | A/B 线序反了；或没共地；或 DE 时序反了（高=发送） |
| 长线/高速误码多 | 波特率太高、没终端电阻（板端有 120R）、双绞线没用上 |
| 超声波距离跳变 | 轮询版时间基准不准（循环 us 数没校准）；用 TIMER 输入捕获 |
| 超声波读到 0 | 超时返回；检查 Trig 是否真的 10us、Echo 分压（5V→3V3） |
| Echo 5V 直接进 MCU | **可能烧引脚**；务必分压或确认模块电平 |
| 位段地址算错读写成别处 | 字节地址没对齐到位所属字节；×32 写成 ×4；用宏别手算 |
| 中断里 `OCTL |= ...` 偶发失效 | 读-改-写非原子；改位段或进临界区 |

---

## 七、拓展练习

1. TIMER2 输入捕获版超声波：Echo=PB0(TIMER2_CH0)，测上升/下降沿 CNT 差值，对比轮询版精度。
2. 写一个简单 485 主从协议：主机轮询 2 个从机（地址 0x01/0x02），带校验和。
3. 把 RS485 接收改成中断 + 帧协议（帧头+长度+数据+校验），主循环解析。
4. 位段改造：把工程里所有 ISR 的 GPIO 操作改位段版，反汇编对比指令数与耗时。
5. 用位段实现"软件 SPI"（SCK/MOSI 位段置位），与 SPL GPIO 版对比速率。
6. 测一次 RS485 最远距离/波特率组合：记录在什么距离下 115200 开始误码。

---

## 八、本章速查卡模板（学完抄一页纸）

```
【第09章 RS485/超声波/位段速查】
RS485 ：USART1(PA2/PA3) + DE=PC5（高发低收）；发完等 USART_FLAG_TC 再拉低 DE
超声波：Trig≥10us → Echo 高电平时间 us / 58 = cm；超时保护 30ms
位段  ：periph 别名 0x42000000；sram 别名 0x22000000
        别名 = 基址 + (addr-区域基址)*32 + bit*4
        例：PA8 OCTL bit8 = 0x42210C20
坑    ：DE 早拉丢停止位；Echo 5V 分压；读改写非原子用位段；(x & m)==0 要加括号
```
