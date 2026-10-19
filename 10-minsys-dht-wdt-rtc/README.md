# 10 · 最小系统 + 温湿度 + 看门狗 + RTC

> 对应课程：10-最小系统+温湿度+看门狗+RTC
> 前置要求：第 04 章（定时器）、第 07 章（串口打印）
> 建议耗时：5-7 天

---

## 本章实板资源

| 资源 | 引脚/参数 | 说明 |
|---|---|---|
| 热敏电阻 | PC3 = ADC13_IN13 | 板载 NTC，模拟量（第 11 章细讲 ADC） |
| 湿敏电阻 | PC4 = ADC14_IN14 | 板载，模拟量 |
| 电位器 | PC2 = ADC12_IN12 | 可调 0~3V3，**调参/模拟传感器神器** |
| FWDGT | IRC40K（40kHz 片内，常开） | 独立看门狗 |
| WWDGT | APB1 时钟 | 窗口看门狗 |
| RTC | LSE = 32.768kHz（Y1，PC14/PC15） | 后备域，断电走时（有 VBAT 时） |

> F103 时代用 DHT22（数字温湿度）；本板没有 DHT22，
> 但**板载热敏+湿敏+电位器全是 ADC 传感器**，反而更贴近真实工程。

---

## 一、学习内容

### 1. 最小系统再认识

GD32F303 最小系统 = 电源(3V3) + 8MHz 晶振 + 32.768kHz 晶振 + BOOT0/BOOT1 + 复位 + 去耦电容。
本板还多出：VBAT（RTC 后备电池）、VDDA/VREF（ADC 参考）。

### 2. FWDGT（独立看门狗）

- 时钟：**IRC40K = 40kHz**，独立于主时钟，主时钟死了它照样跑
- 组成：`PSC(4~256 分频)` + `RLR(12 位重装值)`
- 超时时间 = `(PSC分频 × RLR) / 40000` 秒

| PSC | 分频 | 计数频率 | RLR=2500 时超时 |
|---|---|---|---|
| `FWDGT_PSC_DIV256` | 256 | 156.25Hz | **16s** |

- `fwdgt_enable()` 后**不能停**（只能复位关）——防止程序把自己关掉
- 喂狗：`fwdgt_counter_reload()`

### 3. WWDGT（窗口看门狗）

- 时钟：PCLK1/4096，再 `wwdgt_config` 的 prescaler（0~3 → /1,/2,/4,/8）
- **窗口机制**：计数值 > WIN 时喂狗 → **直接复位**（治"喂得太早"的假循环）
- 计数器 7 位（0x40~0x7F）；`wwdgt_config(counter, window, prescaler)`
- 早唤醒中断：`wwdgt_interrupt_enable()` + `WWDGT_IRQHandler`，快复位前抢救现场

### 4. RTC（实时时钟）

- 时钟源：**LSE 32.768kHz**（板载 Y1）最准；IRC40K 应急；HXTAL/128 应急
- 组成：`PSC(32767)` → 1Hz 秒脉冲；32 位计数器 → 可算 136 年
- 后备域：RTC + 20×16bit BKP 寄存器，**断电/VBAT 保持**
- **后备域必须先解锁**：`RCU_PMU` 时钟 + `pmu_backup_write_enable()`
- 读前 `rtc_lwoff_wait()`（上次写没写完会读到旧值）

---

## 二、学习目标

- [ ] 能算出任意 PSC/RLR 组合的 FWDGT 超时时间
- [ ] 能配好 FWDGT 并在主循环喂狗；能演示"不喂狗 → 复位"现象
- [ ] 能解释窗口看门狗治的是什么 bug
- [ ] 能配好 RTC（LSE + 1Hz），并用串口每秒打印计数
- [ ] 能用 BKP 寄存器实现"复位次数计数"

---

## 三、学习方法

1. **先算后敲**：超时时间全部先算再验证（主循环不喂狗 + 秒表测复位间隔）。
2. **备份域实验**：RTC 计数后按复位，看计数是否保持（VBAT 有电池时断电也保持）。
3. **窗口实验**：WWDGT 配好后，故意"太早喂狗"，观察是否照样复位。
4. **抢救现场**：开 WWDGT 早唤醒中断，在 ISR 里把关键状态写 BKP，复位后打印出来。

---

## 四、标准示例

### 1. FWDGT 16 秒看门狗

```c
#include "gd32f30x.h"

void fwdgt_init(void)
{
    /* IRC40K 常开，无需使能时钟；但配置前要解锁写保护 */
    fwdgt_write_enable();
    fwdgt_prescaler_value_config(FWDGT_PSC_DIV256);   /* 40k/256 = 156.25Hz */
    fwdgt_reload_value_config(2500U);                 /* 2500/156.25 = 16s */
    fwdgt_counter_reload();                           /* 立即喂一次 */
    fwdgt_enable();                                   /* 使能后不可停止！ */
}

int main(void)
{
    systick_config();
    usart0_init();
    printf("wdt start\r\n");
    fwdgt_init();

    while (1) {
        printf("alive, tick=%u\r\n", (unsigned)g_tick_ms);
        fwdgt_counter_reload();          /* 喂狗：< 16s 喂一次就不断 */
        delay_1ms(1000);
    }
}
/* 把 fwdgt_counter_reload() 注释掉 → 16s 后复位（串口应看到 printf 重启信息） */
```

### 2. WWDGT 窗口看门狗（演示"太早喂狗也复位"）

```c
void wwdgt_init(void)
{
    rcu_periph_clock_enable(RCU_WWDGT);
    /* PCLK1=60M → /4096 = 14.648kHz；prescaler=3 → /8 → 1.831kHz
       counter=127 → 69.4ms；window=80 → 计数<80 时喂狗有效（>80 时喂=太早，复位） */
    wwdgt_config(127U, 80U, 3U);
    wwdgt_interrupt_enable();                    /* 早唤醒中断抢救现场 */
    nvic_irq_enable(WWDGT_IRQn, 0U, 0U);
    wwdgt_enable();
}

void WWDGT_IRQHandler(void)
{
    wwdgt_flag_clear();
    printf("wwdgt early wakeup!\r\n");   /* 快复位了，抢救现场 */
}
```

### 3. RTC（LSE + 1Hz 秒计数）

```c
#include "gd32f30x.h"

void rtc_init(void)
{
    /* ① 后备域解锁（顺序：PMU 时钟 → 备份写使能） */
    rcu_periph_clock_enable(RCU_PMU);
    pmu_backup_write_enable();
    rcu_periph_clock_enable(RCU_BKPI);

    /* ② RTC 时钟源 = LSE 32.768kHz */
    rcu_rtc_clock_config(RCU_RTCSRC_LXTAL);
    rcu_periph_clock_enable(RCU_RTC);            /* BDCTL bit15 */

    /* ③ 分频到 1Hz：32768-1 */
    rtc_lwoff_wait();
    rtc_prescaler_set(32767U);
    rtc_counter_set(0U);                          /* 从 0 开始计秒 */
    rtc_lwoff_wait();
}

uint32_t rtc_get_seconds(void)
{
    rtc_register_sync_wait();
    return rtc_counter_get();
}

int main(void)
{
    systick_config();
    usart0_init();
    rtc_init();

    while (1) {
        printf("rtc = %u s\r\n", (unsigned)rtc_get_seconds());
        delay_1ms(1000);
    }
}
```

### 4. BKP 寄存器：复位次数（断电/VBAT 保持）

```c
#define BKP_BOOT_COUNT   BKP_DATA_0

void boot_count_init(void)
{
    rcu_periph_clock_enable(RCU_PMU);
    pmu_backup_write_enable();
    rcu_periph_clock_enable(RCU_BKPI);
}

int main(void)
{
    uint16_t count;

    systick_config();
    usart0_init();
    boot_count_init();
    rtc_init();

    count = bkp_read_data(BKP_BOOT_COUNT) + 1U;
    bkp_write_data(BKP_BOOT_COUNT, count);
    printf("boot #%u, rtc=%u s\r\n", count, (unsigned)rtc_get_seconds());

    while (1) {
        fwdgt_counter_reload();
        delay_1ms(1000);
    }
}
```

---

## 五、自我检测

1. FWDGT 用 `FWDGT_PSC_DIV64` + RLR=625，超时几秒？写出计算。
2. 为什么 `fwdgt_enable()` 之后不能停？这样做防的是什么？
3. WWDGT 的"窗口"防的是什么场景？太早喂狗会怎样？
4. RTC 配 1Hz 为什么是 `rtc_prescaler_set(32767)`？
5. 写 RTC 前必须做哪两步解锁操作？漏了会怎样？
6. `rtc_lwoff_wait()` 和 `rtc_register_sync_wait()` 各在等什么？
7. BKP 寄存器和 SRAM 的本质区别是什么？掉电行为有何不同？
8. 本板温湿度传感器为什么"不是数字的"？这带来什么工程问题？

---

## 六、常见坑

| 现象 | 原因 |
|---|---|
| RTC 写了读回旧值 | ① 没 `pmu_backup_write_enable()`；② 写完没 `rtc_lwoff_wait()` 就读 |
| RTC 不走 / 计数飞快 | 时钟源选错（用了 IRC40K 或没等 LSE 稳定）；分频值没配对 1Hz |
| 复位后 RTC 归零 | 没配 RTC 时钟（BDCTL RTCEN）；或后备域被 `bkp_deinit` 清掉 |
| 喂了狗还复位 | ① 喂狗间隔 > 超时；② FWDGT 配错分频；③ 卡在某个死循环里出不来 |
| WWDGT 总复位 | 喂狗时机落在窗口外（太早）；或 counter 设成 < 0x40（保留值异常） |
| 看门狗复位后串口只有乱码 | 复位期间 TX 引脚被拉低；或打印发生在时钟没配好时 |
| 断电后 RTC 不停但读数跳 | VBAT 电池没装/没电；LSE 起振慢，上电先等 1~2s 再读 |
| ADC 传感器读数飘 | VDDA/VREF 没处理好；参考第 11 章 |

---

## 七、拓展练习

1. 做一个"运行健康监控"：主循环每 500ms 翻转一次 LED2；FWDGT 设 5s；把 LED2 翻转任务注释掉一次，验证 5s 复位。
2. RTC 秒中断（`RTC_INT_SECOND` + `RTC_IRQHandler`）：中断里置标志，主循环打印，体会"中断时基"。
3. 用 BKP_DATA_1~4 存一个结构体（版本号+校准值），复位后读回并打印。
4. RTC 闹钟：`rtc_alarm_config(now+10)`，到点串口打印并闪 LED3。
5. 对比 LSE 与 IRC40K 精度：各跑 10 分钟，数秒数差多少（用主程序 SysTick 对账）。
6. WWDGT 抢救现场：早唤醒中断里把 `g_tick_ms` 写 BKP_DATA_5，复位后读出，估算复位时刻。

---

## 八、本章速查卡模板（学完抄一页纸）

```
【第10章 看门狗/RTC速查】
FWDGT ：fwdgt_write_enable→prescaler_value_config(DIV256)→reload_value_config→counter_reload→enable
        超时 = (分频×RLR)/40000；IRC40K 常开；使能后不可停；喂狗=counter_reload
WWDGT ：rcu(RCU_WWDGT)→wwdgt_config(counter 0x40-0x7F, window, psc 0-3)→interrupt_enable→enable
        太早喂狗也复位（窗口）；抢救靠 WWDGT_IRQHandler + flag_clear
RTC   ：RCU_PMU→pmu_backup_write_enable→RCU_BKPI→rcu_rtc_clock_config(LXTAL)→RCU_RTC
        prescaler_set(32767)→counter_set/get；读前 lwoff_wait/register_sync_wait
BKP   ：bkp_write_data(BKP_DATA_x, v)/bkp_read_data；掉电保持
板子  ：热敏 PC3(ADC13) 湿敏 PC4(ADC14) 电位器 PC2(ADC12)；LSE=PC14/PC15
坑    ：后备域不解锁写不进；WWDGT 窗口；FWDGT 使能不可逆
```
