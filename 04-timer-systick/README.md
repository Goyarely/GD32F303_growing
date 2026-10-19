# 04 · 定时器 + SysTick

> 对应课程：04-定时器+SysTick
> 前置要求：第 03 章（中断）
> 建议耗时：5-7 天

---

## 本章实板引脚

| 资源 | 用途 | 说明 |
|---|---|---|
| TIMER2（PB0=CH2 / PB1=CH3） | 定时器时基实验 | 挂 APB1(60M)，**输入时钟 ×2 = 120MHz** |
| LED1(PA8) | 定时翻转验证 | 示波器/秒表测周期 |
| SysTick | 已有母本时基 | `Driver/systick.c`：`delay_1ms()` |

> 本章只练 TIMER2 的时基 + 更新中断；**PWM 输出放第 05 章**。

---

## 一、学习内容

### 1. SysTick（母本已实现）

`Driver/systick.c` 的套路（与 F103 完全一样）：

```c
SysTick_Config(SystemCoreClock / 1000U);   /* 1ms 一次中断 */
NVIC_SetPriority(SysTick_IRQn, 0x00U);     /* 最高优先级 */
```

- `delay_1ms(count)`：主循环轮询 ISR 递减的计数器
- `SysTick_Handler`（在 `Driver/gd32f30x_it.c`）里调 `delay_decrement()`
- **缺点**：`delay_1ms` 是忙等，CPU 干不了别的事——这正是要学 TIMER 的原因

### 2. TIMER2 时基三要素

| 参数 | SPL 字段 | 作用 |
|---|---|---|
| 预分频 PSC | `prescaler` | 输入时钟分频，计数器实际时钟 = TIMER_CLK/(PSC+1) |
| 周期 ARR | `period` | 计数器计到 ARR 产生更新事件 |
| 计数方向 | `counterdirection` | 上/下/中央对齐 |

```c
typedef struct {
    uint16_t prescaler;
    uint16_t alignedmode;
    uint16_t counterdirection;
    uint16_t clockdivision;
    uint32_t period;
    uint8_t  repetitioncounter;
} timer_parameter_struct;
```

### 3. PSC/ARR 计算（必须自己算，不许背）

**定时器输入时钟 = APB1 × 2 = 60M × 2 = 120MHz**（APB1 分频≠1 时翻倍）

```
计数频率 f_cnt = 120MHz / (PSC + 1)
中断周期 T   = (ARR + 1) / f_cnt
```

例：要 1s 一次更新中断：

- 先定 `f_cnt = 10kHz` → PSC = 120000000/10000 - 1 = **11999**
- 再定 ARR = 10000 - 1 = **9999**
- 验算：120M/12000 = 10kHz；10000/10kHz = 1s ✓

例：要 1ms 一次：

- PSC = 119（f_cnt = 1MHz），ARR = 999 → 1000/1M = 1ms ✓

### 4. 定时器中断链路

```
rcu_periph_clock_enable(RCU_TIMER2)
  → timer_init(TIMER2, &init)          /* PSC/ARR/方向 */
  → timer_interrupt_enable(TIMER2, TIMER_INT_UP)   /* 更新中断 */
  → nvic_irq_enable(TIMER2_IRQn, 1, 1)
  → timer_enable(TIMER2)               /* 最后使能！ */
ISR: timer_interrupt_flag_get(TIMER2, TIMER_FLAG_UP)
  → timer_interrupt_flag_clear(TIMER2, TIMER_FLAG_UP)
```

### 5. 寄存器（TIMER2 基址 0x40000400）

| 寄存器 | 偏移 | 说明 |
|---|---|---|
| `TIMER_CTL0` | 0x00 | 控制：CEN(bit0)=使能、UPS(bit2)=更新源、ARSE=预装载 |
| `TIMER_CTL1` | 0x04 | 对齐/方向/时钟分频 |
| `TIMER_DMAINTEN` | 0x0C | 中断/DMA 使能，UPIE(bit0)=更新中断 |
| `TIMER_INTF` | 0x10 | 标志，UPIF(bit0)=更新标志 |
| `TIMER_PSC` | 0x28 | 预分频 |
| `TIMER_CAR` | 0x2C | 周期（ARR） |
| `TIMER_CNT` | 0x24 | 当前计数值 |

---

## 二、学习目标

- [ ] 能口算"要 N ms 一次中断，PSC/ARR 怎么填"
- [ ] 能说出 APB1 定时器 ×2 规则，并解释为什么 TIMER2 输入是 120MHz
- [ ] 能独立配好 TIMER2 更新中断
- [ ] 理解 `SysTick` 忙等延时与 TIMER 中断延时的本质区别
- [ ] 能写出 SPL 版和寄存器版两个版本的定时器配置

---

## 三、学习方法

1. **先算后敲**：每写一个配置，先在纸上算 PSC/ARR，再敲代码，最后用现象验证。
2. **单步看计数器**：在 ISR 里读 `timer_counter_read(TIMER2)`，看它从 0 数到 ARR 再回 0。
3. **示波器测周期**：ISR 里翻转 PA8，用示波器（或逻辑分析仪）测实际周期，与计算值对账。
4. **破坏性实验**：① 忘 `timer_interrupt_flag_clear`；② 忘 `timer_enable`；③ PSC=0、ARR=0；④ 时钟不开。

---

## 四、标准示例

### 1. TIMER2 1ms 更新中断（SPL 版）

```c
#include "gd32f30x.h"
#include "systick.h"
#include "lcd.h"

volatile uint32_t g_tick_ms = 0U;      /* 每 ms +1，主循环可当系统时基 */

void timer2_init(void)
{
    timer_parameter_struct timer_initpara;

    rcu_periph_clock_enable(RCU_TIMER2);            /* APB1 */

    timer_struct_para_init(&timer_initpara);
    timer_initpara.prescaler        = 119U;         /* 120M/120 = 1MHz */
    timer_initpara.alignedmode      = TIMER_COUNTER_EDGE;
    timer_initpara.counterdirection = TIMER_COUNTER_UP;
    timer_initpara.clockdivision    = TIMER_CKDIV_DIV1;
    timer_initpara.period           = 999U;         /* 1000/1MHz = 1ms */
    timer_init(TIMER2, &timer_initpara);

    timer_interrupt_enable(TIMER2, TIMER_INT_UP);   /* 更新中断 */
    nvic_priority_group_set(NVIC_PRIGROUP_PRE2_SUB2);
    nvic_irq_enable(TIMER2_IRQn, 1U, 1U);

    timer_enable(TIMER2);                           /* 最后使能 */
}

void TIMER2_IRQHandler(void)
{
    if (timer_interrupt_flag_get(TIMER2, TIMER_FLAG_UP) != RESET) {
        timer_interrupt_flag_clear(TIMER2, TIMER_FLAG_UP);
        g_tick_ms++;
    }
}

int main(void)
{
    uint32_t last = 0U;

    systick_config();
    led_init();
    timer2_init();

    while (1) {
        if (g_tick_ms - last >= 500U) {        /* 每 500ms 翻一次 LED */
            last = g_tick_ms;
            gpio_bit_write(GPIOA, GPIO_PIN_8,
                           (last / 500U) & 1U ? SET : RESET);
        }
        /* 主循环解放了，可以干别的 */
    }
}
```

### 2. 寄存器版（等价）

```c
#define TIMER2 ((unsigned long)0x40000400UL)
#define TIMER_CTL2(r)     (*(volatile uint32_t *)((r) + 0x00))
#define TIMER_DMAINTEN2(r) (*(volatile uint32_t *)((r) + 0x0C))
#define TIMER_INTF2(r)    (*(volatile uint32_t *)((r) + 0x10))
#define TIMER_PSC2(r)     (*(volatile uint32_t *)((r) + 0x28))
#define TIMER_CAR2(r)     (*(volatile uint32_t *)((r) + 0x2C))

RCU_APB1EN |= RCU_APB1EN_TIMER2EN;         /* APB1 bit1 */
TIMER_PSC2(TIMER2) = 119U;
TIMER_CAR2(TIMER2) = 999U;
TIMER_DMAINTEN2(TIMER2) |= 0x01U;          /* UPIE */
*(volatile uint32_t *)0xE000E100U |= (1U << 29);  /* NVIC ISER0 bit29 = TIMER2 */
TIMER_CTL2(TIMER2) |= 0x01U;               /* CEN */

void TIMER2_IRQHandler(void)
{
    if (TIMER_INTF2(TIMER2) & 0x01U) {
        TIMER_INTF2(TIMER2) &= ~0x01U;     /* 清 UPIF */
        g_tick_ms++;
    }
}
```

### 3.  SysTick 手写延时（对照母本，理解"中断时基"套路）

```c
/* 母本 systick.c 就是标准写法：ISR 递减 + 主循环轮询 */
void SysTick_Handler(void)
{
    delay_decrement();      /* if(delay_count) delay_count--; */
}
```

---

## 五、自我检测

1. TIMER2 挂在 APB1(60MHz)，为什么计数时钟是 120MHz？
2. 要 10ms 一次更新中断，PSC/ARR 有几种填法？写出两种并验算。
3. `TIMER_INT_UP`、`TIMER_FLAG_UP`、`UPIE`、`UPIF` 四者什么关系？
4. 为什么 `timer_enable()` 要放在配置的最后？
5. 更新标志没清会怎样？和 EXTI 标志没清的现象一样吗？
6. `SysTick` 和 `TIMER2` 都能做 1ms 时基，本质区别是什么？
7. 用 `timer_counter_read(TIMER2)` 在 ISR 里读到的值范围是什么？说明什么？
8. 中央对齐模式（`TIMER_COUNTER_CENTER_x`）和边沿对齐的区别是什么？PWM 常用哪种？

---

## 六、常见坑

| 现象 | 原因 |
|---|---|
| 定时器不计数 | ① 忘 `rcu_periph_clock_enable(RCU_TIMER2)`；② 忘 `timer_enable()` |
| 中断一次就停 / 反复进 | 标志没清：`timer_interrupt_flag_clear(TIMER2, TIMER_FLAG_UP)` |
| 周期差一倍 | PSC/ARR 算错（最常见：忘了 ×2 规则，按 60M 算） |
| 中断进不去 | 忘 `nvic_irq_enable(TIMER2_IRQn, ...)` 或优先级组没设 |
| 改了 PSC 没生效 | 用 `timer_prescaler_config()` 时注意 `pscreload` 参数；直接 `timer_init` 最稳 |
| 主循环被 delay 卡住 | `delay_1ms` 是忙等；要并发就用 TIMER 时基 + 标志 |
| ISR 里做长操作 | 时基抖动、丢中断；ISR 只置标志 |

---

## 七、拓展练习

1. 写一个 `timer_get_tick()` / `timer_elapsed(start)` 非阻塞延时 API（替代 `delay_1ms`）。
2. TIMER2 配 100ms 中断，驱动 LED2(PE6) 按 1Hz 闪；同时主循环用 `delay_1ms` 让 LED3(PF6) 按 3Hz 闪——体会两套时基并存。
3. 破坏性实验：把 ARR 改成 0，观察现象并解释。
4. 在 ISR 里读 `timer_counter_read(TIMER2)`，统计 100 次进中断的计数值范围，验证"从 0 数到 ARR"。
5. 用示波器测 PA8 翻转周期，与计算值比较，算出偏差来源（时钟源精度）。
6. 把 `timer_init` 改寄存器版，对比 `.map` 里代码体积差异。

---

## 八、本章速查卡模板（学完抄一页纸）

```
【第04章 定时器速查】
函数  ：timer_init(TIMER2,&s) / timer_interrupt_enable(TIMER2,TIMER_INT_UP) / timer_enable
        timer_interrupt_flag_get/clear(TIMER2, TIMER_FLAG_UP) / timer_counter_read
公式  ：f_cnt = 120MHz/(PSC+1)；T = (ARR+1)/f_cnt；APB1 定时器 ×2
寄存器：CTL0(0x00) DMAINTEN(0x0C) INTF(0x10) PSC(0x28) CAR(0x2C) CNT(0x24)
地址  ：TIMER2 = 0x40000400；RCU_APB1EN bit1
入口  ：TIMER2_IRQHandler（IRQn=29）
坑    ：忘开时钟/忘使能/忘清标志/×2 规则忘掉周期差一倍
```
