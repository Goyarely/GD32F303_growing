# 07 · 串口 + 重定向 printf

> 对应课程：07-串口+重定向printf
> 前置要求：第 06 章（串口概念）
> 建议耗时：5-7 天

---

## 本章实板引脚

| 资源 | 引脚 | 说明 |
|---|---|---|
| USART0 | PA9(TX)/PA10(RX) | 板载 CH340C → USB(J10 Type-C)，**调试串口，115200 8N1** |
| USART1 | PA2(TX)/PA3(RX) | 排针引出（可接 USB-TTL 做第二串口实验） |
| USART2 | PB10(TX)/PB11(RX) | 板载 ESP8684 WiFi（第 15 章用） |

母本 `Driver/usart.c` + `App/syscalls.c` 已实现调试串口和 printf 重定向，**先读懂再自己写**。

---

## 一、学习内容

### 1. USART 寄存器与 SPL 配置

配置链（**顺序不能乱**）：

```c
rcu_periph_clock_enable(RCU_GPIOA);              /* 引脚时钟 */
rcu_periph_clock_enable(RCU_USART0);             /* 串口时钟（USART0 在 APB2） */
gpio_init(GPIOA, GPIO_MODE_AF_PP, GPIO_OSPEED_50MHZ, GPIO_PIN_9);   /* TX 复用推挽 */
gpio_init(GPIOA, GPIO_MODE_IPU,  GPIO_OSPEED_2MHZ,  GPIO_PIN_10);   /* RX 上拉输入 */
usart_baudrate_set(USART0, 115200U);
usart_parity_config(USART0, USART_PM_NONE);
usart_word_length_set(USART0, USART_WL_8BIT);
usart_stop_bit_set(USART0, USART_STB_1BIT);
usart_transmit_config(USART0, USART_TRANSMIT_ENABLE);   /* ★本板实测大坑★ */
usart_receive_config(USART0, USART_RECEIVE_ENABLE);
usart_enable(USART0);
```

### 2. ★ 第一大坑：`usart_transmit_config` 必须调

`usart_deinit()` 会把 `CTL0.TEN/REN` 清零。`usart_enable()` 只置 UEN 位。
**只调 `usart_enable()` 时，`usart_data_transmit()` 只是写数据寄存器，TX 引脚不输出任何数据**
（现象：串口完全无输出，但程序在跑）。母本 `Driver/usart.c` 已处理，自己写时别忘。

### 3. 轮询发送 / 中断接收

```c
/* 轮询发一个字节 */
usart_data_transmit(USART0, (uint16_t)ch);
while (usart_flag_get(USART0, USART_FLAG_TBE) == RESET) { }   /* 等发送缓冲区空 */

/* 轮询收一个字节 */
while (usart_flag_get(USART0, USART_FLAG_RBNE) == RESET) { }  /* 等收到 */
ch = (uint8_t)usart_data_receive(USART0);

/* 中断收 */
usart_interrupt_config(USART0, USART_INT_RBNE, ENABLE);
nvic_irq_enable(USART0_IRQn, 1U, 1U);

void USART0_IRQHandler(void)
{
    if (usart_interrupt_flag_get(USART0, USART_INT_FLAG_RBNE) != RESET) {
        uint8_t ch = (uint8_t)usart_data_receive(USART0);   /* 读 DR 自动清 RBNE */
        /* 处理 ch */
    }
}
```

### 4. printf 重定向（母本链路）

```
printf() → newlib → _write()（App/syscalls.c）→ usart_send()（Driver/usart.c）→ USART0 → CH340C
```

两个条件缺一不可：

| 条件 | 配置 |
|---|---|
| `_write` 被链接 | EIDE 全局设置 **`not-use-syscalls: false`**（母本注释："使用系统调用"关闭）——否则 `printf` 无任何输出 |
| 串口 TX 真使能 | `usart_transmit_config(..., USART_TRANSMIT_ENABLE)`（见上） |

### 5. 常用格式化与技巧

```c
printf("tick=%u adc=%d hex=0x%08X str=%s\r\n", g_tick, val, val, "ok");
/* %u 无符号 %d 有符号 %x/%X 十六进制 %f 浮点（开了 FPU+uvisor？newlib-uClibc 需
   LDFLAGS -u _printf_float；初学阶段建议避开 %f，先自己写定点输出） */
```

---

## 二、学习目标

- [ ] 能独立配好 USART0 115200 8N1 并有输出
- [ ] 能解释 `usart_transmit_config` 不调会发生什么（背下来）
- [ ] 能说清 printf 从调用到引脚输出的完整链路
- [ ] 能写出中断接收 + 环形缓冲（或行缓冲）的回显程序
- [ ] 能实现"收到 1 点亮 LED、收到 2 熄灭"的串口控制

---

## 三、学习方法

1. **先读母本**：`Driver/usart.c`（发送/初始化）+ `App/syscalls.c`（_write）+ `Driver/usart.h`（6 行配置）。
2. **单步看 STAT**：在 `usart_data_transmit` 后看 `USART0_STAT0` 的 TBE/TC 位变化。
3. **自己重写一遍**：不看母本，从零写 `usart0_init` + `usart_send_byte`，现象对账。
4. **抓一次乱码**：故意把波特率配错，看乱码长什么样，理解帧错位。
5. **中断接收**：写回显（echo），再升级成"行缓冲 + 简单命令解析"。

---

## 四、标准示例

### 1. 最小串口初始化 + 发送（SPL）

```c
#include "gd32f30x.h"

void usart0_init(void)
{
    rcu_periph_clock_enable(RCU_GPIOA);
    rcu_periph_clock_enable(RCU_USART0);

    /* TX = PA9 复用推挽；RX = PA10 上拉输入（悬空会误触发起始位） */
    gpio_init(GPIOA, GPIO_MODE_AF_PP, GPIO_OSPEED_50MHZ, GPIO_PIN_9);
    gpio_init(GPIOA, GPIO_MODE_IPU,  GPIO_OSPEED_2MHZ,  GPIO_PIN_10);

    usart_deinit(USART0);                                   /* 干净起点 */
    usart_baudrate_set(USART0, 115200U);
    usart_parity_config(USART0, USART_PM_NONE);
    usart_word_length_set(USART0, USART_WL_8BIT);
    usart_stop_bit_set(USART0, USART_STB_1BIT);
    usart_transmit_config(USART0, USART_TRANSMIT_ENABLE);   /* ★必调★ */
    usart_receive_config(USART0, USART_RECEIVE_ENABLE);
    usart_enable(USART0);
}

void usart0_send_byte(uint8_t ch)
{
    usart_data_transmit(USART0, (uint16_t)ch);
    while (usart_flag_get(USART0, USART_FLAG_TBE) == RESET) { }
}

int main(void)
{
    systick_config();
    usart0_init();

    while (1) {
        usart0_send_byte('H');
        usart0_send_byte('i');
        usart0_send_byte('\r');
        usart0_send_byte('\n');
        delay_1ms(1000);
    }
}
```

### 2. printf 重定向（`App/syscalls.c` 的核心）

```c
#include <stdio.h>
#include <errno.h>
#include <sys/stat.h>
#include "gd32f30x.h"

int _write(int file, char *ptr, int len)
{
    if (file != STDOUT_FILENO && file != STDERR_FILENO) {
        errno = EBADF;
        return -1;
    }
    for (int i = 0; i < len; i++) {
        usart_data_transmit(USART0, (uint16_t)ptr[i]);
        while (usart_flag_get(USART0, USART_FLAG_TBE) == RESET) { }
    }
    return len;
}
```

> 母本 `App/syscalls.c` 就是这套；别忘了 EIDE 里 `not-use-syscalls: false`。

### 3. 中断接收 + 行缓冲 + 命令解析

```c
#define RX_BUF_SIZE 64U

volatile uint8_t  g_rx_buf[RX_BUF_SIZE];
volatile uint8_t  g_rx_len = 0U;
volatile uint8_t  g_rx_line_ready = 0U;

void usart0_rx_irq_init(void)
{
    nvic_priority_group_set(NVIC_PRIGROUP_PRE2_SUB2);
    nvic_irq_enable(USART0_IRQn, 1U, 1U);
    usart_interrupt_config(USART0, USART_INT_RBNE, ENABLE);
}

void USART0_IRQHandler(void)
{
    if (usart_interrupt_flag_get(USART0, USART_INT_FLAG_RBNE) != RESET) {
        uint8_t ch = (uint8_t)usart_data_receive(USART0);      /* 读 DR 清 RBNE */
        if (ch == '\n' || ch == '\r') {
            if (g_rx_len > 0U) {
                g_rx_buf[g_rx_len] = '\0';
                g_rx_line_ready = 1U;
            }
        } else if (g_rx_len < RX_BUF_SIZE - 1U) {
            g_rx_buf[g_rx_len++] = ch;
        }
    }
}

int main(void)
{
    systick_config();
    usart0_init();
    usart0_rx_irq_init();
    printf("ready\r\n");

    while (1) {
        if (g_rx_line_ready) {
            g_rx_line_ready = 0U;
            printf("recv: %s\r\n", (char *)g_rx_buf);
            if (strcmp((char *)g_rx_buf, "on") == 0) {
                gpio_bit_set(GPIOA, GPIO_PIN_8);
            } else if (strcmp((char *)g_rx_buf, "off") == 0) {
                gpio_bit_reset(GPIOA, GPIO_PIN_8);
            }
            g_rx_len = 0U;
        }
    }
}
```

---

## 五、自我检测

1. 写出 USART0 115200 8N1 的完整初始化（含引脚和时钟），不许翻上文。
2. 为什么必须调 `usart_transmit_config(USART0, USART_TRANSMIT_ENABLE)`？不调的现象是什么？
3. `USART_FLAG_TBE` 和 `USART_FLAG_TC` 有什么区别？发多个字节该等哪个？
4. printf 从调用到 PA9 输出，依次经过哪些函数？
5. EIDE 里哪个配置项会让 printf 完全无输出？值是什么？
6. 中断接收为什么要"读 DR"？RBNE 标志怎么清？
7. RX 引脚配 `GPIO_MODE_IPU` 和 `GPIO_MODE_IN_FLOATING` 的区别是什么？悬空会发生什么？
8. 波特率 115200、时钟 120MHz，SPL 内部分频系数怎么算？误差多大？

---

## 六、常见坑

| 现象 | 原因 |
|---|---|
| 串口完全无输出（程序在跑） | ① 忘 `usart_transmit_config(..., USART_TRANSMIT_ENABLE)`；② `not-use-syscalls` 不是 `false`（printf 链断） |
| 输出乱码 | 波特率不一致；`usart_baudrate_set` 前时钟树变了没重新设 |
| 只能发不能收 | RX 没配 `GPIO_MODE_IPU`；或 `usart_receive_config` 没调 |
| 中断收一个字节就停 | RBNE 中断里没读 DR（标志靠读 DR 清） |
| 收到的数据丢字节 | ISR 里做太长操作；或主循环处理太慢（用环形缓冲缓解） |
| 打开串口工具板子复位 | CH340C DTR/RTS 一键下载电路行为，**正常现象** |
| `%f` 打印 `?` 或不输出 | newlib 未开 float 支持；初学避开 `%f` |
| 中文/全角字符花屏 | 串口助手编码选 UTF-8；终端宽度不够 |

---

## 七、拓展练习

1. 实现 `usart0_send_string()` / `usart0_send_buf()`，用 printf 和它们各发一遍同样内容对比代码体积。
2. 升级命令解析：支持 `led on/off`、`tick?`（回当前 ms）、`reboot`（NVIC_SystemReset）。
3. 写一个环形缓冲队列：ISR 只入队，主循环出队打印，压测 115200 连发不丢。
4. 用 USART1(PA2/PA3) 接 USB-TTL 做第二串口，两个串口同时工作，互相转发。
5. 故意不调 `usart_transmit_config` 编译烧录，记录"完全无输出"现象，再加回来——把这个坑写进你的排错手册。
6. 测吞吐：主循环狂发 10000 字节，PC 端统计，算实际速率与理论 115200 的差距，解释原因。

---

## 八、本章速查卡模板（学完抄一页纸）

```
【第07章 串口速查】
函数  ：usart_baudrate_set/parity_config/word_length_set/stop_bit_set
        usart_transmit_config(...,USART_TRANSMIT_ENABLE)←必调！/usart_receive_config/usart_enable
        usart_data_transmit/usart_data_receive/usart_flag_get(USART_FLAG_TBE/RBNE)
        usart_interrupt_config(USART0,USART_INT_RBNE,ENABLE)
引脚  ：PA9=TX(AF_PP) PA10=RX(IPU)；USART0 挂 APB2(120M)
printf：printf→_write(syscalls.c)→usart_data_transmit；前提 not-use-syscalls:false + TX 使能
入口  ：USART0_IRQHandler（IRQn=37）
坑    ：忘 transmit_config 无输出；RX 悬空误触发；RBNE 靠读 DR 清
```
