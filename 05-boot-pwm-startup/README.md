# 05 · 启动模式 + PWM + 启动文件 + 串口下载

> 对应课程：05-启动模式+PWM+启动文件+串口下载
> 前置要求：第 04 章（定时器时基）
> 建议耗时：5-7 天

---

## 本章实板引脚

| 资源 | 引脚 | 说明 |
|---|---|---|
| TIMER2_CH2 / CH3 | PB0 / PB1 | PWM 输出（空闲引脚，示波器可测） |
| LED1 | PA8 | PWM 呼吸灯候选（但 PA8 非 TIMER 通道，呼吸灯建议用 PB0 + 外接 LED，或把 LED1 当 GPIO 闪烁对照） |
| BOOT0 / BOOT1 | BOOT0 跳线 / PB2 | 启动模式 |
| USART0 | PA9/PA10 → CH340C | 串口 ISP 下载 |

---

## 一、学习内容

### 1. 三种启动模式（BOOT 引脚）

| BOOT0 | BOOT1 | 启动区 | 场景 |
|---|---|---|---|
| 0 | × | **主 Flash**（0x08000000） | 正常烧录后运行 |
| 1 | 0 | **系统存储器**（0x1FFFF000，出厂 ISP） | 串口下载（配 CH340C） |
| 1 | 1 | 内置 SRAM（0x20000000） | 调试/特殊场景 |

- 本板 BOOT0 有跳线/开关；PB2 接 BOOT1
- **SWD（OpenOCD + ST-Link）下载不看 BOOT0**，直接写 Flash
- 串口 ISP：BOOT0=1 上电 → 进 ISP → GD 官方 ISP 工具选 USART0（CH340C 口）→ 下载 → BOOT0=0 复位
- 本板 CH340C 带 DTR/RTS 一键下载电路（自动控 BOOT0/NRST），配合 ISP 工具可一键下载

### 2. PWM 原理

- 频率 = f_cnt/(ARR+1)；占空比 = CCR/(ARR+1)
- TIMER2 通道：CH0=PA0、CH1=PA1、**CH2=PB0**、**CH3=PB1**
- SPL 输出比较模式：`TIMER_OC_MODE_PWM0`（CNT < CCR 时有效电平）/ `PWM1`（相反）

### 3. PWM 配置链

```
rcu_periph_clock_enable(RCU_TIMER2)
  → 引脚配 GPIO_MODE_AF_PP（复用推挽！）
  → timer_init（PSC/ARR/方向）
  → timer_channel_output_config（输出比较参数结构）
  → timer_channel_output_pulse_value_config（CCR = 占空比）
  → timer_enable
```

### 4. 启动文件分析（`Arm/startup_gd32f30x_hd.s`）

- `__Vectors`：栈顶 + Reset_Handler + 内核异常 + 外设中断向量（HD = 144 脚全向量）
- `Reset_Handler`：`LDR R0, =SystemInit` → `BLX R0` → `LDR R0, =__main` → `BX R0`
- `SystemInit()`（`Arm/system_gd32f30x.c`）：配置时钟（当前 8M×15=120M）+ **FPU 使能（CPACR）**
- WEAK：`Default_Handler` 兜底；C 里重写同名函数即覆盖
- `.data` 搬运、`.bss` 清零由 `__main`（C 库）完成

---

## 二、学习目标

- [ ] 能说出三种启动模式的区别和各自用法
- [ ] 能独立配出 TIMER2_CH2(PB0) 的 PWM，并算出指定频率/占空比的 PSC/ARR/CCR
- [ ] 能画出启动流程：复位 → Reset_Handler → SystemInit → __main → main
- [ ] 能解释 FPU 是什么时候使能的
- [ ] 能用串口 ISP 下载一次程序（BOOT0 操作一遍）

---

## 三、学习方法

1. **单步启动流程**：在 `Reset_Handler` 打断点，记录 SP/PC/LR，对照 `.map` 找符号地址。
2. **示波器测 PWM**：PB0 输出 PWM，测频率和占空比，与计算值对账。
3. **改 CCR 看占空比**：在循环里改 CCR，观察示波器占空比变化（呼吸灯的基础）。
4. **BOOT 实验**：BOOT0=1 上电观察现象（进 ISP，程序不跑）；下回来。
5. **对比启动文件**：找出 `__Vectors` 里 `TIMER2_IRQHandler` 的位置，理解向量表与 `IRQn` 编号的关系（向量表第 n 项 = IRQn n+16）。

---

## 四、标准示例

### 1. TIMER2_CH2(PB0) PWM 1kHz 50%

```c
#include "gd32f30x.h"

#define PWM_GPIO   GPIOB
#define PWM_PIN    GPIO_PIN_0

void pwm_init(void)
{
    timer_oc_parameter_struct timer_ocinitpara;

    /* ① 时钟 */
    rcu_periph_clock_enable(RCU_GPIOB);
    rcu_periph_clock_enable(RCU_TIMER2);

    /* ② 引脚：PB0 → TIMER2_CH2 复用推挽 */
    gpio_init(PWM_GPIO, GPIO_MODE_AF_PP, GPIO_OSPEED_50MHZ, PWM_PIN);

    /* ③ 时基：120M/120 = 1MHz；ARR=999 → 1kHz */
    timer_parameter_struct timer_initpara;
    timer_struct_para_init(&timer_initpara);
    timer_initpara.prescaler        = 119U;
    timer_initpara.alignedmode      = TIMER_COUNTER_EDGE;
    timer_initpara.counterdirection = TIMER_COUNTER_UP;
    timer_initpara.period           = 999U;
    timer_init(TIMER2, &timer_initpara);

    /* ④ 输出比较：PWM0 模式，高极性有效 */
    timer_channel_output_struct_para_init(&timer_ocinitpara);
    timer_ocinitpara.outputstate  = TIMER_CCX_ENABLE;
    timer_ocinitpara.ocpolarity   = TIMER_OC_POLARITY_HIGH;
    timer_channel_output_config(TIMER2, TIMER_CH_2, &timer_ocinitpara);

    /* ⑤ CCR = 500 → 50% */
    timer_channel_output_pulse_value_config(TIMER2, TIMER_CH_2, 500U);

    /* ⑥ 使能 */
    timer_enable(TIMER2);
}

void pwm_set_duty(uint16_t duty)     /* duty: 0~1000 → 0%~100% */
{
    timer_channel_output_pulse_value_config(TIMER2, TIMER_CH_2, duty);
}

int main(void)
{
    uint16_t duty = 0U;
    int8_t  dir  = 1;

    systick_config();
    pwm_init();

    while (1) {
        pwm_set_duty(duty);
        delay_1ms(2);                     /* 呼吸速度 */
        if (dir > 0) {
            if (++duty >= 1000U) dir = -1;
        } else {
            if (--duty == 0U)    dir = 1;
        }
    }
}
```

### 2. 寄存器版（TIMER2 CH2 PWM）

```c
/* TIMER2 = 0x40000400 */
/* CTL0 bit7 = ARSE（预装载使能）；CHCTL0(0x18) CH2COMCTL[14:12]=110(PWM0) + CH2E(bit8? CH2 在 [11:8]) */
TIMER_PSC2(TIMER2)  = 119U;
TIMER_CAR2(TIMER2)  = 999U;
TIMER_CH2CV(TIMER2) = 500U;                  /* CHCTL2/CHxCV：通道2比较值寄存器偏移 0x38 */
TIMER_CHCTL0(TIMER2) |= (6U << 12) | (1U << 8);  /* PWM0 + CH2 输出使能 */
TIMER_CTL2(TIMER2)  |= 0x01U;                /* CEN */
```

> 寄存器版仅作对照：**通道寄存器布局复杂（CHCTL0/CHCTL1/CHCTL2 三张表）**，
> 学 PWM 阶段 SPL 优先，寄存器版知道"写 CHxCV 就是 CCR"即可，细节查手册。

### 3. 启动流程验证（调试观察点）

```
Reset_Handler 处：SP = _estack（0x20010000，64KB SRAM 顶）
                 PC = Reset_Handler+2，正执行 BLX R0
进 SystemInit   ：配 RCU→120MHz，置 CPACR 使能 FPU
进 __main       ：C 库：.data 搬运（_sidata→_sdata~_edata）、.bss 清零
进 main         ：从这里开始你的代码
```

---

## 五、自我检测

1. 三种启动模式分别用什么 BOOT 组合？ISP 下载用哪个？
2. PWM 频率 1kHz、占空比 25%，TIMER2 上 PSC/ARR/CCR 各填几？写出计算过程。
3. `TIMER_OC_MODE_PWM0` 和 `PWM1` 的输出极性差在哪？
4. 为什么 PWM 引脚必须配 `GPIO_MODE_AF_PP` 而不是 `OUT_PP`？
5. 从复位到 `main()` 列出完整函数链，并说出每步做了什么。
6. FPU 是谁使能的？如果自己写启动文件漏了这步会怎样？
7. 向量表里第 20 项对应哪个中断？（提示：IRQn = 向量索引 - 16）
8. CH340C 一键下载电路用 DTR/RTS 控制哪两个引脚？为什么普通串口工具打开端口板子会复位？

---

## 六、常见坑

| 现象 | 原因 |
|---|---|
| PWM 引脚无波形 | ① 引脚没配 `GPIO_MODE_AF_PP`（配成 OUT_PP 就只是普通 GPIO）；② 忘 `TIMER_CCX_ENABLE`；③ 忘 `timer_enable` |
| 频率对、占空比不对 | CCR 写法错：`timer_channel_output_pulse_value_config(TIMER2, TIMER_CH_2, duty)`，注意**通道号参数** |
| 呼吸灯有台阶感 | 延时太粗；用定时中断改 CCR，或加大刷新率 |
| BOOT0=1 程序不跑 | **正常**：进了系统存储器 ISP，不是 Flash；用完记得跳回 0 |
| ISP 下载失败 | ① BOOT0 没置 1 就上电；② 串口选错（要选 CH340C 那个口）；③ 没先点"下载"再上电/复位 |
| SWD 下载后不运行 | 与 BOOT0 无关，查启动文件/宏/链接脚本三件套 |
| 频率差 2 倍或 4 倍 | PSC 算错；TIMER2 输入是 120MHz（APB1×2） |

---

## 七、拓展练习

1. TIMER2_CH3(PB1) 再出一路 PWM，用 KEY1 中断切换两路占空比组合。
2. 用定时中断（第 04 章）每 20ms 改一次 CCR，实现平滑呼吸灯，对比 `delay_1ms` 版的差异。
3. 测 PWM 实际频率（示波器），与 1kHz 计算值对账；然后把 PSC 改成一档别的值再测。
4. 完整走一遍串口 ISP 下载：BOOT0=1 → ISP 工具 → 下载 → BOOT0=0 复位 → 程序运行。
5. 读 `.map`：找到 `__Vectors`、`Reset_Handler`、`SystemInit`、`main` 的地址，画出内存布局草图。
6. 查 `startup_gd32f30x_hd.s` 里 `TIMER2_IRQHandler` 的向量表项，算出它对应的 IRQn 编号，与 `gd32f30x.h` 里对账。

---

## 八、本章速查卡模板（学完抄一页纸）

```
【第05章 PWM/启动速查】
函数  ：timer_channel_output_config(TIMER2, TIMER_CH_2, &oc) / timer_channel_output_pulse_value_config
        ocpara.outputstate = TIMER_CCX_ENABLE；ocpolarity = TIMER_OC_POLARITY_HIGH；模式 TIMER_OC_MODE_PWM0
公式  ：f = 120MHz/(PSC+1)/(ARR+1)；duty = CCR/(ARR+1)
引脚  ：TIMER2_CH2=PB0、CH3=PB1；PWM 引脚必须 GPIO_MODE_AF_PP
启动  ：BOOT0=0 → Flash；BOOT0=1 & BOOT1=0 → 系统存储器 ISP；BOOT0=1 & BOOT1=1 → SRAM
流程  ：Reset_Handler → SystemInit(120M+FPU) → __main(.data/.bss) → main
坑    ：AF_PP 忘配；通道号写错；BOOT0 用完不跳回
```
