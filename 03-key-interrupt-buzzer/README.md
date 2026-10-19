# 03 · 按键开发 + 蜂鸣器 + 中断

> 对应课程：03-按键开发+蜂鸣器+中断
> 前置要求：第 02 章 GPIO
> 建议耗时：5-7 天

---

## 本章实板引脚

| 部件 | 引脚 | 特性 |
|---|---|---|
| KEY1 | PA0 | 低电平有效，板载 1k 上拉 + 100nF 消抖 → **EXTI0** |
| KEY2 | PG13 | 同上 → EXTI13（与 KEY3/4 共用 `EXTI15_10_IRQHandler`） |
| KEY3 | PG14 | 同上 → EXTI14 |
| KEY4 | PG15 | 同上 → EXTI15 |
| 蜂鸣器 SPK | PB8 | PNP 驱动，**低电平响** |
| LED1 | PA8 | 中断控制的目标 |

> F103 学习时"蜂鸣器本板无"是遗憾；**本板 PB8 有真蜂鸣器**，本章补齐。

---

## 一、学习内容

### 1. 中断基本概念

- 中断向量表、NVIC、优先级（抢占 + 子优先级）
- 中断响应流程：外设置标志 → NVIC 仲裁 → 压栈 → 进 ISR → 清标志 → 出栈
- **清标志必须在 ISR 里做**，否则会反复进中断

### 2. F303 的 EXTI（与 F103 的最大差异：没有 AFIO）

| F103 做法 | F303 做法 |
|---|---|
| 开 AFIO 时钟 + 配 `AFIO->EXTICR[0]` 选引脚 | **不需要**：EXTI 线号 = 引脚号，直接 `exti_init` |
| `HAL_GPIO_EXTI_IRQHandler` | SPL：自己写 `EXTI0_IRQHandler`（弱符号在启动文件里） |

### 3. SPL 中断三件套

```c
void exti_init(exti_line_enum linex, exti_mode_enum mode, exti_trig_type_enum trig_type);
void exti_interrupt_flag_clear(exti_line_enum linex);
void nvic_irq_enable(uint8_t nvic_irq, uint8_t pre_priority, uint8_t sub_priority);
void nvic_priority_group_set(uint32_t nvic_prigroup);
```

关键枚举：

```c
EXTI_0 ... EXTI_18                                  /* 线号 = 引脚号 */
EXTI_INTERRUPT / EXTI_EVENT                        /* 中断模式 / 事件模式 */
EXTI_TRIG_RISING / EXTI_TRIG_FALLING / EXTI_TRIG_BOTH
EXTI0_IRQn / EXTI1_IRQn / EXTI2_IRQn / EXTI3_IRQn / EXTI4_IRQn
EXTI5_9_IRQn / EXTI10_15_IRQn                      /* 注意 5-9、10-15 是共享向量！ */
NVIC_PRIGROUP_PRE2_SUB2                            /* 2 位抢占 + 2 位子优先级 */
```

### 4. 中断入口函数名（`Driver/gd32f30x_it.c` 里重写）

`EXTI0_IRQHandler` / `EXTI1_IRQHandler` / ... / `EXTI15_10_IRQHandler`

### 5. 非阻塞按键事件模型

**中断里只做最少的事**：置标志/计数，主循环处理——ISR 越短越安全。

```c
volatile uint8_t g_key_event = 0U;    /* volatile！中断与主循环共享 */

void EXTI0_IRQHandler(void)
{
    if (exti_interrupt_flag_get(EXTI0) != RESET) {
        exti_interrupt_flag_clear(EXTI0);     /* 不清就反复进来 */
        g_key_event = 1U;
    }
}
```

---

## 二、学习目标

- [ ] 能说出 F103 与 F303 在外部中断配置上的差异（AFIO 没了）
- [ ] 能独立配好 KEY1(PA0) 下降沿中断并进 ISR
- [ ] 理解抢占/子优先级，能排出两个中断的优先级
- [ ] 能写出非阻塞按键模型（中断置标志 + 主循环处理）
- [ ] 能用中断实现"按键切换 LED、蜂鸣器响 100ms"

---

## 三、学习方法

1. **单步看 NVIC**：在 `nvic_irq_enable` 处打断点，看 `NVIC->ISER`/`IP` 寄存器变化。
2. **对比轮询**：把第 02 章的轮询按键改写成中断版，体会"主循环解放"。
3. **共享中断实验**：把 KEY2(PG13) 也配上中断，在 `EXTI15_10_IRQHandler` 里用 `exti_interrupt_flag_get` 区分两根线。
4. **破坏性实验**：① 注释 `exti_interrupt_flag_clear`，看是否死循环；② 不调 `nvic_irq_enable`，看外设标志是否置起但中断不进。

---

## 四、标准示例

### 1. KEY1 外部中断完整配置（SPL）

```c
#include "gd32f30x.h"

#define KEY1_GPIO  GPIOA
#define KEY1_PIN   GPIO_PIN_0

void key1_exti_init(void)
{
    /* ① 时钟：GPIOA（APB2） */
    rcu_periph_clock_enable(RCU_GPIOA);
    /* ② 引脚：上拉输入（低电平有效按键） */
    gpio_init(KEY1_GPIO, GPIO_MODE_IPU, GPIO_OSPEED_2MHZ, KEY1_PIN);
    /* ③ EXTI：0 号线，中断模式，下降沿 */
    exti_init(EXTI_0, EXTI_INTERRUPT, EXTI_TRIG_FALLING);
    /* ④ NVIC：抢占 2、子 2（先设优先级组再设具体优先级） */
    nvic_priority_group_set(NVIC_PRIGROUP_PRE2_SUB2);
    nvic_irq_enable(EXTI0_IRQn, 2U, 2U);
}

/* ⑤ ISR：只置标志 */
volatile uint8_t g_key1_event = 0U;

void EXTI0_IRQHandler(void)
{
    if (exti_interrupt_flag_get(EXTI0) != RESET) {
        exti_interrupt_flag_clear(EXTI0);
        g_key1_event = 1U;
    }
}
```

> 对比 F103 HAL 版，少了"AFIO 时钟 + `AFIO->EXTICR[0] |= 0`"两步——
> **F303 的 EXTI 线号就是引脚号**，这是本章最值得记住的差异。

### 2. 主循环：非阻塞处理 + 蜂鸣器

```c
#include "systick.h"
#include "lcd.h"

#define BUZZ_GPIO   GPIOB
#define BUZZ_PIN    GPIO_PIN_8

void buzzer_init(void)
{
    rcu_periph_clock_enable(RCU_GPIOB);
    gpio_init(BUZZ_GPIO, GPIO_MODE_OUT_PP, GPIO_OSPEED_2MHZ, BUZZ_PIN);
    gpio_bit_set(BUZZ_GPIO, BUZZ_PIN);       /* 高电平 = 停（PNP 低电平响） */
}

int main(void)
{
    uint8_t led_on = 0U;

    systick_config();
    led_init();          /* 母本 lcd.c：LED1 = PA8 */
    buzzer_init();
    key1_exti_init();

    while (1) {
        if (g_key1_event) {
            g_key1_event = 0U;
            delay_1ms(20);                       /* 软件消抖（板载已有 100nF） */
            if (gpio_input_bit_get(GPIOA, GPIO_PIN_0) == RESET) {
                led_on = !led_on;
                gpio_bit_write(GPIOA, GPIO_PIN_8, led_on ? SET : RESET);
                gpio_bit_reset(BUZZ_GPIO, BUZZ_PIN);   /* 响 */
                delay_1ms(100);
                gpio_bit_set(BUZZ_GPIO, BUZZ_PIN);     /* 停 */
            }
        }
    }
}
```

### 3. 寄存器版（EXTI + NVIC）

```c
/* EXTI 基址 0x40010400 */
#define EXTI_INTEN    (*(volatile uint32_t *)0x40010400U)   /* 中断屏蔽 */
#define EXTI_EVEN     (*(volatile uint32_t *)0x40010404U)
#define EXTI_RTEN     (*(volatile uint32_t *)0x40010408U)   /* 上升沿使能 */
#define EXTI_FTEN     (*(volatile uint32_t *)0x4001040CU)   /* 下降沿使能 */
#define EXTI_SWIER    (*(volatile uint32_t *)0x40010410U)
#define EXTI_PD       (*(volatile uint32_t *)0x40010414U)   /* 挂起(清标志) */

/* NVIC 基址 0xE000E100：ISER0 bit6 = EXTI0 */
*(volatile uint32_t *)0xE000E100U |= (1U << 6);             /* 使能 EXTI0 中断 */

EXTI_FTEN |= (1U << 0);        /* 0 号线下降沿 */
EXTI_INTEN |= (1U << 0);       /* 0 号线中断使能 */

void EXTI0_IRQHandler(void)
{
    if (EXTI_PD & (1U << 0)) {
        EXTI_PD |= (1U << 0);  /* 写 1 清标志 */
        g_key1_event = 1U;
    }
}
```

### 4. 两个中断排优先级（演示抢占）

```c
/* KEY1(PA0→EXTI0) 抢占 1；TIMER2 更新中断抢占 2：KEY1 能"打断"定时器中断 */
nvic_irq_enable(EXTI0_IRQn, 1U, 1U);
nvic_irq_enable(TIMER2_IRQn, 2U, 2U);
```

---

## 五、自我检测

1. F103 配外部中断要开哪个外设时钟、配哪个寄存器？F303 呢？差异的根源是什么？
2. `EXTI_TRIG_FALLING` 与 `EXTI_TRIG_BOTH` 各适合什么按键场景？
3. 为什么 ISR 里必须 `exti_interrupt_flag_clear`？不清会发生什么？
4. PG13/PG14/PG15 三个按键的中断入口是同一个函数，如何在里面区分是谁触发的？
5. `volatile uint8_t g_key1_event` 的 `volatile` 去掉会怎样？为什么？
6. 抢占优先级和子优先级有什么区别？两个中断同时到来时谁先响应？
7. 为什么蜂鸣器是"低电平响"？从 PNP 驱动电路解释。
8. 轮询按键和中断按键各自的适用场景是什么？中断总是更好吗？

---

## 六、常见坑

| 现象 | 原因 |
|---|---|
| 标志置了但中断不进 | ① 忘 `nvic_irq_enable`；② 忘 `exti_interrupt_flag_clear`（标志没清，表现为反复进）；③ 优先级组没设 |
| 一进中断就出不来 / 主循环卡死 | ISR 里没清标志（EXTI_PD 写 1 清）；或在 ISR 里死等 |
| 按一次进多次中断 | 机械抖动；板载 100nF 只滤高频，软件仍需 20ms 消抖 |
| 四个按键只有 KEY1 好使 | PG13-15 走 `EXTI15_10_IRQHandler`，ISR 里要分别判断三根线的标志 |
| 照抄 F103 代码找不到 `AFIO` | F303 没有 AFIO，直接 `exti_init(EXTI_n, ...)` |
| 蜂鸣器不响 / 常响 | 极性反了：`gpio_bit_reset` 才响（PNP 低电平导通） |
| `g_key1_event` 优化掉不更新 | 没加 `volatile`，编译器把循环里的读优化成缓存值 |

---

## 七、拓展练习

1. 四按键全部上中断（KEY1/2/3/4），共享中断里区分，实现：KEY1 切 LED、KEY2 蜂鸣器 100ms、KEY3 快闪、KEY4 全停。
2. 长按检测：按下超过 1s 算长按（ISR 里记时间戳或计数），短按/长按动作不同。
3. 中断里只做"计数"不做延时：用 ISR 计数 + 主循环算间隔，实现"1s 内按几次"统计。
4. 破坏性实验：把 `exti_interrupt_flag_clear` 注释掉，观察现象并解释；然后加回来。
5. 把 EXTI0 配成上升沿（本板按键按下是下降沿，试试反过来配会怎样），解释现象。
6. 用位带在 ISR 里点灯（`*(volatile uint32_t *)0x42210C20 = 1;`），与 `gpio_bit_set` 对比 ISR 执行时间（示波器测 PA8 建立时间）。

---

## 八、本章速查卡模板（学完抄一页纸）

```
【第03章 中断速查】
函数  ：exti_init(EXTI_n, EXTI_INTERRUPT, EXTI_TRIG_FALLING) / exti_interrupt_flag_clear(EXTI_n)
        nvic_irq_enable(EXTI0_IRQn, 2, 2) / nvic_priority_group_set(NVIC_PRIGROUP_PRE2_SUB2)
寄存器：EXTI_INTEN(0x40010400) RTEN(08) FTEN(0C) PD(14)；NVIC ISER(0xE000E100) IP(0xE000E400)
入口  ：EXTI0_IRQHandler ... EXTI4_IRQHandler / EXTI9_5_IRQHandler / EXTI15_10_IRQHandler
板子  ：KEY1=PA0(EXTI0) KEY2=PG13 KEY3=PG14 KEY4=PG15（低电平有效）；蜂鸣器 PB8 低响
坑    ：不清标志反复进；忘 volatile；PG13-15 共享中断要分别判断；F303 无 AFIO
```
