# 02 · GPIO 外设 + LED 库函数 + 寄存器开发

> 对应课程：02-GPIO外设+LED库函数+寄存器开发
> 前置要求：第 01 章（工程能编译烧录）
> 建议耗时：5-7 天

---

## 本章实板引脚

| 部件 | 引脚 | 特性 |
|---|---|---|
| LED1 | PA8 | 高电平点亮（母本 `Driver/lcd.c`：`led_on()`=`gpio_bit_set`） |
| LED2 | PE6 | 同上 |
| LED3 | PF6 | 同上 |
| KEY1 | PA0 | 低电平有效，板载 1k 上拉 + 100nF（本章先轮询，第 03 章上中断） |

LED 极性以母本 `Driver/lcd.c` 为准；若实测相反（低电平点亮），只改 `lcd.c` 一处。

---

## 一、学习内容

### 1. GPIO 8 种工作模式（SPL 枚举）

| SPL 模式宏 | 值(CTL) | 含义 | 典型用途 |
|---|---|---|---|
| `GPIO_MODE_AIN` | 0x0 | 模拟输入 | **ADC 引脚必须用这个** |
| `GPIO_MODE_IN_FLOATING` | 0x4 | 浮空输入 | 外部已带上拉的信号 |
| `GPIO_MODE_IPD` | 0x8 | 下拉输入 | 默认低电平 |
| `GPIO_MODE_IPU` | 0xC | 上拉输入 | **按键（本板低电平有效）** |
| `GPIO_MODE_OUT_OD` | 0x4(输出) | 推挽输出开路漏 | I2C 需外加上拉 |
| `GPIO_MODE_OUT_PP` | 0x0(输出) | 推挽输出 | LED、GPIO 控制 |
| `GPIO_MODE_AF_OD` | 0xC(输出) | 复用开漏 | I2C 的 SCL/SDA |
| `GPIO_MODE_AF_PP` | 0x8(输出) | 复用推挽 | USART TX、SPI、PWM |

> F103 HAL 叫 `GPIO_MODE_OUTPUT_PP`，F303 SPL 叫 `GPIO_MODE_OUT_PP`——**名字不一样，移植时最容易漏**。

### 2. 输出速度

`GPIO_OSPEED_2MHZ / 10MHZ / 50MHZ / GPIO_OSPEED_MAX`（F303 是 M4，比 F103 多一档 MAX）。

### 3. 寄存器一览（F303 特色：BOP/BCTL 分离）

| 寄存器 | 偏移 | 作用 |
|---|---|---|
| `GPIO_CTL0` | 0x00 | 低 8 位引脚模式+速度（每引脚 4 位） |
| `GPIO_CTL1` | 0x04 | 高 8 位引脚模式+速度 |
| `GPIO_ISTAT` | 0x08 | 输入（读引脚电平） |
| `GPIO_OCTL` | 0x0C | 输出（读/写输出锁存） |
| **`GPIO_BOP`** | 0x10 | **写 1 置位**（只置不清） |
| **`GPIO_BCTL`** | 0x14 | **写 1 清除**（只清不置） |

> F103 用 `BSRR`（低 16 位置位、高 16 位清除，一个寄存器）；**F303 拆成 BOP/BCTL 两个**。
> 照抄 F103 的 `GPIOx->BSRR = (uint32_t)pin << 16` 在 F303 上**编译不过**。

### 4. SPL 核心函数

```c
void rcu_periph_clock_enable(rcu_periph_enum periph);      /* 时钟！忘了它全白配 */
void gpio_init(uint32_t gpio_periph, uint32_t mode, uint32_t speed, uint32_t pin);
void gpio_bit_set(uint32_t gpio_periph, uint32_t pin);
void gpio_bit_reset(uint32_t gpio_periph, uint32_t pin);
void gpio_bit_write(uint32_t gpio_periph, uint32_t pin, bit_status_t bit_value);
FlagStatus gpio_input_bit_get(uint32_t gpio_periph, uint32_t pin);   /* 读引脚 */
FlagStatus gpio_output_bit_get(uint32_t gpio_periph, uint32_t pin);  /* 读输出锁存 */
uint16_t gpio_output_port_get(uint32_t gpio_periph);
void gpio_port_write(uint32_t gpio_periph, uint16_t data);
```

### 5. 位带区（M4 特性，第 09 章细讲）

外设位带别名区基址 `0x42000000`：
`alias = 0x42000000 + (reg_addr - 0x40000000) × 32 + bit × 4`

---

## 二、学习目标

- [ ] 能不看资料写出 PA8 推挽输出的完整初始化（含时钟）
- [ ] 能说出 8 种模式各自的适用场景，特别是 `AIN` 和 `IPU`
- [ ] 能把 `gpio_bit_set` 翻译成 `GPIO_BOP` 寄存器操作
- [ ] 理解 `ISTAT` 与 `OCTL` 的区别（读引脚 vs 读锁存）
- [ ] 能独立完成"按键查询控制 LED"（轮询版）

---

## 三、学习方法

1. **单步看寄存器**：在 `gpio_init()` 里打断点，单步后打开 `Peripherals → GPIOA`，看 `CTL0` 位域怎么变。
2. **CTL 手工计算**：把 PA8 配成 50MHz 推挽，算出 `GPIO_CTL0` 应该等于几，再用调试器验证。
3. **双版本对照**：先用 SPL 写，再用 `GPIO_BOP/GPIO_BCTL/GPIO_OCTL` 重写，现象必须一致。
4. **破坏性实验**：① 注释掉 `rcu_periph_clock_enable` 看现象；② 把 `AIN` 当输出看现象；③ 用 `gpio_output_bit_get` 读按键看为什么不靠谱。

---

## 四、标准示例

### 1. LED1 初始化 + 闪烁（SPL 版，母本 `lcd.c` 思路）

```c
#include "gd32f30x.h"
#include "systick.h"

#define LED1_GPIO   GPIOA
#define LED1_PIN    GPIO_PIN_8
#define LED1_RCU    RCU_GPIOA

void led1_init(void)
{
    rcu_periph_clock_enable(LED1_RCU);                      /* ① 时钟 */
    gpio_init(LED1_GPIO, GPIO_MODE_OUT_PP,
              GPIO_OSPEED_50MHZ, LED1_PIN);                 /* ② 模式 */
    gpio_bit_reset(LED1_GPIO, LED1_PIN);                    /* ③ 默认熄灭 */
}

int main(void)
{
    systick_config();
    led1_init();

    while (1) {
        gpio_bit_set(LED1_GPIO, LED1_PIN);
        delay_1ms(500);
        gpio_bit_reset(LED1_GPIO, LED1_PIN);
        delay_1ms(500);
    }
}
```

### 2. 寄存器版（等价）

```c
/* 时钟：APB2EN bit2（GPIOA）*/
RCU_APB2EN |= RCU_APB2EN_PAEN;                  /* 等价 rcu_periph_clock_enable(RCU_GPIOA) */

/* PA8 → CTL0 的 [3:0]=0010：输出 2MHz；MODE[1:0]=10 输入/00 输出，本板 LED 用 50MHz(0011) */
GPIO_CTL0(GPIOA) = (GPIO_CTL0(GPIOA) & ~0x0000000FU) | 0x00000003U;

/* 亮 / 灭 */
GPIO_BOP(GPIOA)  = GPIO_PIN_8;                  /* 置 1 */
GPIO_BCTL(GPIOA) = GPIO_PIN_8;                  /* 清 0 */
```

### 3. 按键查询（轮询，KEY1=PA0 低电平有效）

```c
#define KEY1_GPIO   GPIOA
#define KEY1_PIN    GPIO_PIN_0
#define KEY1_RCU    RCU_GPIOA

void key1_init(void)
{
    rcu_periph_clock_enable(KEY1_RCU);
    /* 本板已有 1k 外部上拉，用片内上拉双保险；100nF 消抖电容板载 */
    gpio_init(KEY1_GPIO, GPIO_MODE_IPU, GPIO_OSPEED_2MHZ, KEY1_PIN);
}

uint8_t key1_pressed(void)
{
    return (gpio_input_bit_get(KEY1_GPIO, KEY1_PIN) == RESET) ? 1U : 0U;
}

int main(void)
{
    systick_config();
    led1_init();
    key1_init();

    while (1) {
        if (key1_pressed()) {
            gpio_bit_set(LED1_GPIO, LED1_PIN);
        } else {
            gpio_bit_reset(LED1_GPIO, LED1_PIN);
        }
    }
}
```

### 4. 按键切换（按下翻转，配合软件消抖）

```c
int main(void)
{
    uint8_t led_state = 0U;

    systick_config();
    led1_init();
    key1_init();

    while (1) {
        if (key1_pressed()) {
            delay_1ms(20);                     /* 软件消抖 */
            if (key1_pressed()) {              /* 消抖后仍按下 */
                while (key1_pressed()) { }     /* 等松手，避免一次按多次翻 */
                led_state = !led_state;
                gpio_bit_write(LED1_GPIO, LED1_PIN,
                               led_state ? SET : RESET);
            }
        }
    }
}
```

---

## 五、自我检测

1. 说出 8 种 GPIO 模式，并各举一个本板上的实际用途。
2. 把 PA8 配成 50MHz 推挽输出，`GPIO_CTL0` 写几？（提示：每引脚占 4 位，PA8 在 CTL0 的高半字节）
3. `gpio_input_bit_get` 和 `gpio_output_bit_get` 读的分别是什么？读按键该用哪个？
4. F103 的 `BSRR` 在 F303 对应什么？写"PA8 置 1、PC5 清 0"两条语句。
5. 为什么 ADC 引脚必须配 `GPIO_MODE_AIN` 而不是浮空输入？
6. 忘了 `rcu_periph_clock_enable(RCU_GPIOA)` 会发生什么？为什么？
7. 位带别名地址怎么算？PA8 的 `OCTL` bit8 别名地址是多少？（答案见第 09 章）
8. 开漏输出（`OUT_OD`）和推挽输出的区别是什么？I2C 为什么要开漏？

---

## 六、常见坑

| 现象 | 原因 |
|---|---|
| 配了 GPIO 没反应 | 忘开 RCU 时钟（本章第一大坑） |
| LED 一直亮 / 一直灭 | 极性搞反：以 `lcd.c` 为准，`led_on()` = `gpio_bit_set`（高电平亮） |
| 照抄 F103 代码编译不过 | `GPIO_MODE_OUTPUT_PP` → SPL 叫 `GPIO_MODE_OUT_PP`；`GPIO_SPEED_FREQ_LOW` → `GPIO_OSPEED_2MHZ` |
| 寄存器版 `BSRR` 不存在 | F303 是 `GPIO_BOP`/`GPIO_BCTL`，且要用宏形式 `GPIO_BOP(GPIOA)` |
| 按键不按也乱翻 | 没消抖（板载有 100nF，软件再加 20ms + 等松手） |
| 读按键读到"一直按下" | 该用 `gpio_input_bit_get`；用 `gpio_output_bit_get` 读的是自己的输出锁存 |
| 改 LED 到 PE6 不亮 | 忘开 `RCU_GPIOE`（每个端口时钟独立） |

---

## 七、拓展练习

1. 三灯流水灯：LED1(PA8)/LED2(PE6)/LED3(PF6)，间隔 200ms，写驱动放 `Driver/`。
2. 按键按住时 LED 快闪（100ms），松开慢闪（500ms）——练"读取输入决定输出节奏"。
3. 用 `GPIO_OCTL` 一次写 3 个 LED 的状态（`gpio_port_write` 或直接写寄存器），体会端口操作。
4. 破坏性实验：把 LED 引脚从 `OUT_PP` 改成 `GPIO_MODE_IPU`，看还能不能点亮，解释现象。
5. 用位带方式点亮 LED（`*(volatile uint32_t *)0x42210C20 = 1;`），与 `gpio_bit_set` 对比生成的代码大小（看 `.map`）。
6. 写一个 `gpio_quick_set(GPIOx, pin)`：内部自动查该引脚属于哪个端口并开时钟（提示：`RCU_GPIOA..G` 按端口基址递增）。

---

## 八、本章速查卡模板（学完抄一页纸）

```
【第02章 GPIO 速查】
函数  ：rcu_periph_clock_enable / gpio_init / gpio_bit_set / gpio_bit_reset / gpio_bit_write / gpio_input_bit_get
枚举  ：GPIO_MODE_OUT_PP / GPIO_MODE_IPU / GPIO_MODE_AIN / GPIO_MODE_AF_PP / GPIO_OSPEED_50MHZ
寄存器：CTL0(0x00) CTL1(0x04) ISTAT(0x08) OCTL(0x0C) BOP(0x10) BCTL(0x14)
地址  ：GPIOA=0x40010800 GPIOB=0x40010C00 GPIOC=0x40011000 GPIOE=0x40011800 GPIOF=0x40011C00 GPIOG=0x40012000
RCU   ：RCU_GPIOA~G（APB2EN bit2-7）；APB2EN=0x40021018
坑    ：忘开时钟；AIN 才是模拟输入；F303 无 BSRR；读引脚用 input_bit_get
```
