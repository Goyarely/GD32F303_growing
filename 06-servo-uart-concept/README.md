# 06 · 舵机控制 + 串口概念

> 对应课程：06-舵机控制+串口概念
> 前置要求：第 05 章（PWM）
> 建议耗时：3-5 天

---

## 本章实板引脚

| 资源 | 引脚 | 说明 |
|---|---|---|
| TIMER2_CH3 | PB1 | 舵机信号线（外接舵机：信号→PB1，电源取板 5V/GND） |
| USART0 | PA9/PA10 → CH340C | 第 07 章主角，本章先建立概念 |
| USART1 | PA2/PA3 | 排针引出，可接外部串口设备 |

> 本板无板载舵机；外接 SG90 类舵机：信号线→PB1，红线→5V，棕线→GND
> （舵机电流大时用独立电源，信号共地）。

---

## 一、学习内容

### 1. 舵机控制原理

- 舵机用 **50Hz PWM（周期 20ms）** 控制，**看脉宽不看占空比**
- 典型脉宽：0.5ms → 0°；1.5ms → 90°；2.5ms → 180°
- 公式：`角度 = (脉宽 - 0.5ms) / 2.0ms × 180°`
- 换算到 CCR：脉宽(ms) × 1000 × (f_cnt/MHz)…直接算：

```
f_cnt = 120MHz/(PSC+1) = 1MHz（PSC=119）→ 1 计数 = 1us
ARR = 20000 - 1 = 19999 → 20ms（50Hz）
CCR = 脉宽us：500(0°) / 1500(90°) / 2500(180°)
```

### 2. 串口（USART）概念（先概念，第 07 章写代码）

| 概念 | 要点 |
|---|---|
| 异步串口 | 无时钟线，靠**波特率**约定速率；TX/RX **交叉连接**（A TX → B RX） |
| 帧格式 | 起始位(1) + 数据位(8) + 校验位(0) + 停止位(1) = **8N1** |
| 波特率 | 每秒符号数；115200 常用；双方必须一致 |
| 电平 | 本板 3.3V TTL；接 PC 用 CH340C 转 USB |
| 全双工 | TX/RX 各一根线，可同时收发 |

### 3. 本板串口资源

| 串口 | 引脚 | 用途 |
|---|---|---|
| USART0 | PA9(TX)/PA10(RX) | CH340C → USB，调试主力 |
| USART1 | PA2(TX)/PA3(RX) | 排针；第 09 章接 RS485 |
| USART2 | PB10(TX)/PB11(RX) | 板载 ESP8684 WiFi（第 15 章） |

---

## 二、学习目标

- [ ] 能算出 50Hz 下 0°/90°/180° 对应的 CCR 值
- [ ] 能独立写出舵机驱动（角度 → CCR）
- [ ] 能画出 TX/RX 交叉连接图，说出 8N1 每位的含义
- [ ] 理解波特率误差怎么来的（分频取整）

---

## 三、学习方法

1. **先画时序**：把 20ms 周期、0.5/1.5/2.5ms 脉宽画在纸上，再写代码。
2. **示波器/舵机观察**：直接看舵机转到 0/90/180 三个角度，验证脉宽公式。
3. **串口对敲**：用 USB-TTL 把 PA2/PA3 与另一台设备对接（第 07 章细化），先建立"交叉连接"的肌肉记忆。
4. **误差实验**：故意把波特率配成 9600 对 115200，观察乱码，理解"双方必须一致"。

---

## 四、标准示例

### 1. 舵机驱动（TIMER2_CH3，50Hz）

```c
#include "gd32f30x.h"

#define SERVO_GPIO  GPIOB
#define SERVO_PIN   GPIO_PIN_1

/* 120MHz/(119+1) = 1MHz → 1 计数 = 1us；ARR=19999 → 20ms */
#define SERVO_PSC    119U
#define SERVO_ARR    19999U

static uint16_t angle_to_ccr(uint16_t angle)    /* 0~180 度 */
{
    if (angle > 180U) angle = 180U;
    return (uint16_t)(500U + angle * 2000U / 180U);   /* 500us ~ 2500us */
}

void servo_init(void)
{
    timer_oc_parameter_struct timer_ocinitpara;
    timer_parameter_struct timer_initpara;

    rcu_periph_clock_enable(RCU_GPIOB);
    rcu_periph_clock_enable(RCU_TIMER2);

    gpio_init(SERVO_GPIO, GPIO_MODE_AF_PP, GPIO_OSPEED_50MHZ, SERVO_PIN);

    timer_struct_para_init(&timer_initpara);
    timer_initpara.prescaler        = SERVO_PSC;
    timer_initpara.alignedmode      = TIMER_COUNTER_EDGE;
    timer_initpara.counterdirection = TIMER_COUNTER_UP;
    timer_initpara.period           = SERVO_ARR;
    timer_init(TIMER2, &timer_initpara);

    timer_channel_output_struct_para_init(&timer_ocinitpara);
    timer_ocinitpara.outputstate = TIMER_CCX_ENABLE;
    timer_ocinitpara.ocpolarity  = TIMER_OC_POLARITY_HIGH;
    timer_channel_output_config(TIMER2, TIMER_CH_3, &timer_ocinitpara);

    timer_channel_output_pulse_value_config(TIMER2, TIMER_CH_3, 1500U);  /* 90° */
    timer_enable(TIMER2);
}

void servo_set_angle(uint16_t angle)
{
    timer_channel_output_pulse_value_config(TIMER2, TIMER_CH_3, angle_to_ccr(angle));
}

int main(void)
{
    systick_config();
    servo_init();

    while (1) {
        servo_set_angle(0U);    delay_1ms(1000);
        servo_set_angle(90U);   delay_1ms(1000);
        servo_set_angle(180U);  delay_1ms(1000);
    }
}
```

### 2. 串口帧格式示意（8N1）

```
空闲(高) ┐
         ┌─┐ ┌──┬──┬──┬──┬──┬──┬──┬──┐ ┌─┐
         │0│ │ D0 D1 D2 D3 D4 D5 D6 D7│ │1│   ← 起始位 + 8 数据位(LSB 先发) + 停止位
      ───┘ └─┘ └──┴──┴──┴──┴──┴──┴──┴──┘ └─┘──
         起始位(低)                      停止位(高)
```

### 3. 波特率误差（概念）

```
USART 时钟 120MHz（USART0 挂 APB2）
波特率 = USART_CLK / (16 × DIV)   →  DIV = 120M / (16 × 115200) ≈ 65.1
取整 65 → 实际波特率 = 120M/(16×65) ≈ 115942（误差 0.6%，可接受）
```

> SPL 的 `usart_baudrate_set()` 内部会做这个取整，还会自动用 oversampling=8 补偿。
> 误差 > 2% 就可能乱码——这就是"双方波特率必须一致且都别配太偏"的原因。

---

## 五、自我检测

1. 舵机 50Hz、1.5ms 脉宽，在 PSC=119/ARR=19999 下 CCR 填几？
2. 为什么舵机看脉宽而不是占空比？20ms 周期改成 10ms 会怎样？
3. 8N1 的"8N1"分别指什么？一帧共几位？
4. TX/RX 连接为什么要交叉？同向连会看到什么？
5. 115200 波特率下一位多长时间？一个字节呢？
6. 波特率误差 0.6% 为什么没事，10% 为什么乱码？
7. 本板三个 USART 各接什么？调试串口走哪个？

---

## 六、常见坑

| 现象 | 原因 |
|---|---|
| 舵机抽搐/不动 | ① 脉宽算错；② 电源不足（舵机启动电流大，别从 MCU 3V3 取）；③ 频率不是 50Hz |
| 舵机只能到一边 | 角度-CCR 映射错；或 CCR > ARR（PWM 一直 100%） |
| 串口乱码 | 波特率不一致 / 误差过大 / 地没共 |
| 串口收不到 | TX/RX 没交叉 |
| 舵机信号干扰 Flash 烧录 | 舵机电源拔掉再烧；信号线悬空时可能拉低 SWD |

---

## 七、拓展练习

1. 写 `servo_set_angle_us(uint16_t us)`（直接给脉宽），与角度版对照。
2. 用 KEY1 中断每次加 15°，到 180 归零；KEY2 每次减 15°。
3. 用示波器测 PB1：确认周期 20ms、三个角度的脉宽。
4. 故意把 ARR 改成 10000（10ms/100Hz），观察舵机反应并解释。
5. 查 `gd32f30x_usart.h` 里 `usart_baudrate_set` 的实现，找出 oversampling 8/16 的选择逻辑。
6. （串口预热）画一张"本板串口接线图"：CH340C-TX→PA10、CH340C-RX→PA9、共地，标在纸上。

---

## 八、本章速查卡模板（学完抄一页纸）

```
【第06章 舵机/串口概念速查】
舵机  ：50Hz(20ms)；脉宽 500/1500/2500us → 0/90/180°；CCR = 500 + angle*2000/180
        PSC=119(1us/计数) ARR=19999；TIMER2_CH3=PB1；引脚 AF_PP
串口  ：异步、8N1(起始1+数据8+停止1)、波特率双方一致、TX/RX 交叉、共地
        USART0=PA9/PA10(CH340C调试口) USART1=PA2/PA3(排针) USART2=PB10/PB11(WiFi)
公式  ：DIV = USART_CLK/(16×波特率)；误差>2% 危险
坑    ：舵机电源；频率必须 50Hz；TX/RX 同向连不通
```
