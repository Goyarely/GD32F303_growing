# 11 · ADC + 板载传感器 + DMA

> 对应课程：11-ADC+光敏电阻+DMA
> 前置要求：第 04 章（定时器）、第 07 章（串口）
> 建议耗时：5-7 天

---

## 本章实板资源

| 传感器 | 引脚 | ADC 通道（ADC0/ADC1） | 特性 |
|---|---|---|---|
| 电位器（可调电阻） | PC2 | `ADC_CHANNEL_12` | 0~3V3 可调，**调试神器** |
| 热敏电阻 NTC | PC3 | `ADC_CHANNEL_13` | 温度→阻值→分压电压 |
| 湿敏电阻 | PC4 | `ADC_CHANNEL_14` | 湿度→阻值→分压电压 |

> PC0→IN10、PC1→IN11、PC2→IN12、PC3→IN13、PC4→IN14、PC5→IN15（P 组从 IN10 起）。
> 本板不需要外接光敏——**电位器就是最好的"可调模拟量"**。

---

## 一、学习内容

### 1. GD32F303 ADC 概貌

- 3 个 ADC：**ADC0 / ADC1**（12 位，18 通道含内部）、ADC2（12 位）
- 通道 0~9：PA0~PA7、PB0、PB1；通道 10~15：PC0~PC5；通道 16=内部温度、17=Vrefint
- 规则组（regular，最多 16 通道序列）+ 注入组（inserted）
- 转换触发：软件触发 / 外部触发（定时器事件最常用）
- **ADC 时钟**：`rcu_adc_clock_config(RCU_CKADC_CKAPB2_DIV6)` → APB2(120M)/6 = 20MHz
  （上限查数据手册，超了精度崩）

### 2. 配置链（多通道连续扫描 + DMA）

```
rcu_periph_clock_enable(RCU_GPIOC) → 引脚配 GPIO_MODE_AIN（模拟输入！）
  → rcu_periph_clock_enable(RCU_ADC0) + rcu_adc_clock_config(DIV6)
  → adc_resolution_config(ADC0, ADC_RESOLUTION_12B)
  → adc_special_function_config(ADC0, ADC_CONTINUOUS_MODE, ENABLE)   /* 连续转换 */
  → adc_special_function_config(ADC0, ADC_SCAN_MODE, ENABLE)         /* 多通道扫描 */
  → adc_channel_length_config(ADC0, ADC_REGULAR_CHANNEL, 3)          /* 3 个通道 */
  → adc_regular_channel_config(ADC0, 0..2, CHANNEL_12/13/14, SAMPLE_TIME)
  → adc_external_trigger_source_config(ADC0, ADC_REGULAR_CHANNEL, ...NONE)
  → adc_calibration_enable(ADC0)            /* ★校准必做★ */
  → adc_dma_mode_enable(ADC0)               /* ADC 请求 DMA */
  → dma_init(DMA0, DMA_CH0, &dma) → dma_circulation_enable → dma_channel_enable
  → adc_enable(ADC0) → adc_software_trigger_enable(ADC0, ADC_REGULAR_CHANNEL)
```

### 3. DMA 搬运（CPU 零干预）

```
ADC0 → (EOC) → DMA0_CH0 → SRAM 数组
环形(循环)模式 + 内存地址自增 → 主循环随时读最新值
```

```c
typedef struct {
    uint32_t periph_addr;      /* = (uint32_t)&ADC0_RDATA */
    uint32_t periph_width;     /* DMA_PERIPHERAL_WIDTH_16BIT（ADC 12 位结果按 16 位放） */
    uint32_t memory_addr;      /* = (uint32_t)adc_buf */
    uint32_t memory_width;     /* DMA_MEMORY_WIDTH_16BIT */
    uint32_t number;           /* 通道数 */
    uint32_t priority;         /* DMA_PRIORITY_... */
} dma_parameter_struct;
```

### 4. 数值 → 工程量

- 原始值：`0~4095`（12 位）
- 电压：`V = raw × 3.3 / 4095`
- NTC 温度：查查表或 β 公式（拓展）
- **别背别人的分度表，自己用查表法 + 线性插值**

---

## 二、学习目标

- [ ] 能写出单通道 ADC 轮询版（电位器 PC2）
- [ ] 能配出"3 通道连续扫描 + DMA 环形"的多通道采集
- [ ] 能解释为什么 ADC 引脚必须 `GPIO_MODE_AIN`
- [ ] 能解释 `ADC_SCAN_MODE` 和 `ADC_CONTINUOUS_MODE` 各解决什么问题
- [ ] 能把 raw 值换成电压并打印，和万用表实测对账

---

## 三、学习方法

1. **万用表对账**：测 PC2 实际电压，与 ADC 换算值对比——这是"数字世界与模拟世界"的第一次握手。
2. **单步看 RDATA**：转换完成后在 `ADC_RDATA` 上打断点/监视，看它随电位器变化。
3. **先轮询后 DMA**：单通道轮询跑通，再升级 DMA，理解 DMA 帮你省了什么。
4. **采样时间实验**：高阻信号源（湿敏）用长采样时间对比短采样时间的稳定性。
5. **触发源实验**：软件触发 vs TIMER 触发，对比采样抖动。

---

## 四、标准示例

### 1. 单通道轮询（电位器 PC2）

```c
#include "gd32f30x.h"

void adc0_init(void)
{
    /* ① 引脚：AIN！ */
    rcu_periph_clock_enable(RCU_GPIOC);
    gpio_init(GPIOC, GPIO_MODE_AIN, GPIO_OSPEED_2MHZ, GPIO_PIN_2);

    /* ② ADC 时钟：APB2/6 = 20MHz */
    rcu_periph_clock_enable(RCU_ADC0);
    rcu_adc_clock_config(RCU_CKADC_CKAPB2_DIV6);

    /* ③ 参数 */
    adc_deinit(ADC0);
    adc_resolution_config(ADC0, ADC_RESOLUTION_12B);
    adc_special_function_config(ADC0, ADC_CONTINUOUS_MODE, ENABLE);
    adc_channel_length_config(ADC0, ADC_REGULAR_CHANNEL, 1U);
    adc_regular_channel_config(ADC0, 0U, ADC_CHANNEL_12, ADC_SAMPLETIME_55POINT5);
    adc_external_trigger_source_config(ADC0, ADC_REGULAR_CHANNEL,
                                       ADC0_1_2_EXTTRIG_REGULAR_NONE);

    /* ④ 校准 + 使能 */
    adc_calibration_enable(ADC0);          /* 等校准完成（内部自动等待） */
    adc_enable(ADC0);
    adc_software_trigger_enable(ADC0, ADC_REGULAR_CHANNEL);
}

uint16_t adc0_read(void)
{
    while (adc_flag_get(ADC0, ADC_FLAG_EOC) == RESET) { }
    adc_flag_clear(ADC0, ADC_FLAG_EOC);
    return (uint16_t)adc_regular_data_read(ADC0);
}

int main(void)
{
    systick_config();
    usart0_init();
    adc0_init();

    while (1) {
        uint16_t raw = adc0_read();
        uint32_t mv  = (uint32_t)raw * 3300U / 4095U;
        printf("raw=%4u  %u.%03uV\r\n", raw, mv / 1000U, mv % 1000U);
        delay_1ms(500);
    }
}
```

### 2. 三通道 + DMA 环形（PC2/PC3/PC4 连续采集）

```c
#include "gd32f30x.h"

#define ADC_CH_NUM   3U
uint16_t g_adc_buf[ADC_CH_NUM];    /* [0]=电位器 [1]=热敏 [2]=湿敏 */

void adc_dma_init(void)
{
    dma_parameter_struct dma_init_struct;

    /* ① 三个引脚 AIN */
    rcu_periph_clock_enable(RCU_GPIOC);
    gpio_init(GPIOC, GPIO_MODE_AIN, GPIO_OSPEED_2MHZ,
              GPIO_PIN_2 | GPIO_PIN_3 | GPIO_PIN_4);

    /* ② ADC0 */
    rcu_periph_clock_enable(RCU_ADC0);
    rcu_adc_clock_config(RCU_CKADC_CKAPB2_DIV6);
    adc_deinit(ADC0);
    adc_resolution_config(ADC0, ADC_RESOLUTION_12B);
    adc_special_function_config(ADC0, ADC_SCAN_MODE, ENABLE);
    adc_special_function_config(ADC0, ADC_CONTINUOUS_MODE, ENABLE);
    adc_channel_length_config(ADC0, ADC_REGULAR_CHANNEL, ADC_CH_NUM);
    adc_regular_channel_config(ADC0, 0U, ADC_CHANNEL_12, ADC_SAMPLETIME_55POINT5);
    adc_regular_channel_config(ADC0, 1U, ADC_CHANNEL_13, ADC_SAMPLETIME_55POINT5);
    adc_regular_channel_config(ADC0, 2U, ADC_CHANNEL_14, ADC_SAMPLETIME_55POINT5);
    adc_external_trigger_source_config(ADC0, ADC_REGULAR_CHANNEL,
                                       ADC0_1_2_EXTTRIG_REGULAR_NONE);

    /* ③ DMA0_CH0：ADC0 → SRAM，16 位宽，循环模式 */
    rcu_periph_clock_enable(RCU_DMA0);
    dma_deinit(DMA0, DMA_CH0);
    dma_struct_para_init(&dma_init_struct);
    dma_init_struct.periph_addr  = (uint32_t)&ADC0_RDATA;   /* ADC0 数据寄存器 */
    dma_init_struct.periph_width = DMA_PERIPHERAL_WIDTH_16BIT;
    dma_init_struct.memory_addr  = (uint32_t)g_adc_buf;
    dma_init_struct.memory_width = DMA_MEMORY_WIDTH_16BIT;
    dma_init_struct.number       = ADC_CH_NUM;
    dma_init_struct.direction    = DMA_PERIPHERAL_TO_MEMORY;
    dma_init_struct.priority     = DMA_PRIORITY_HIGH;
    dma_init(DMA0, DMA_CH0, &dma_init_struct);
    dma_circulation_enable(DMA0, DMA_CH0);
    dma_channel_enable(DMA0, DMA_CH0);

    /* ④ ADC DMA 模式 + 校准 + 启动 */
    adc_dma_mode_enable(ADC0);
    adc_calibration_enable(ADC0);
    adc_enable(ADC0);
    adc_software_trigger_enable(ADC0, ADC_REGULAR_CHANNEL);
}

int main(void)
{
    systick_config();
    usart0_init();
    adc_dma_init();
    printf("adc+dma start\r\n");

    while (1) {
        /* DMA 环持续刷新，主循环零成本读 */
        printf("pot=%4u tmp=%4u rh=%4u\r\n",
               g_adc_buf[0], g_adc_buf[1], g_adc_buf[2]);
        delay_1ms(500);
    }
}
```

### 3. 定时器触发采样（去抖动）

```c
/* 每 10ms 触发一次规则组转换，采样时刻均匀 */
adc_external_trigger_source_config(ADC0, ADC_REGULAR_CHANNEL,
                                   ADC0_1_EXTTRIG_REGULAR_T2_CH0);
/* TIMER2 CH0 每 10ms 产生一次事件；不再调 adc_software_trigger_enable */
```

---

## 五、自我检测

1. ADC0 的 IN12/IN13/IN14 分别对应哪些引脚？写出推导（P 组起始通道号）。
2. 为什么 ADC 引脚必须配 `GPIO_MODE_AIN`？配成浮空输入会怎样？
3. `ADC_SCAN_MODE` 和 `ADC_CONTINUOUS_MODE` 分别是什么行为？只开一个会怎样？
4. ADC 时钟 20MHz 怎么来的？超上限会怎样？
5. DMA 的 `periph_width` 和 `memory_width` 都设 16BIT，为什么不能一个 16 一个 8？
6. 环形（循环）模式的意义是什么？不开会怎样？
7. raw=2048 对应多少电压？万用表实测对比偏差来源有哪些？
8. `adc_calibration_enable` 校准的是什么？不校准的后果？

---

## 六、常见坑

| 现象 | 原因 |
|---|---|
| ADC 值全 0 或全 4095 | ① 引脚没配 `AIN`；② 忘开 `RCU_ADC0`/`RCU_GPIOC`；③ 没触发转换 |
| 值跳变严重 | ① 采样时间太短（高阻源用 55.5/239.5）；② 时钟超限；③ VDDA 噪声 |
| DMA 只搬了一个数 | ① `number` 设成 1；② DMA 没使能；③ `adc_dma_mode_enable` 没调 |
| DMA 数据错位/重复 | 宽度不匹配（16/16 必须一致）；或环形模式下主循环读越界 |
| 3 个通道值一样 | 规则组序列没配对（rank 写重了）；或没开 scan 模式 |
| 转换完不进 DMA | `adc_dma_mode_enable(ADC0)` 漏了；或 DMA 通道对应关系错（ADC0→DMA0_CH0） |
| 打印卡住 | ISR/主循环里读 ADC 时死等 EOC（配 DMA 就是为了不死等） |
| 用 PC5 当 ADC 同时 RS485 方向失效 | 引脚复用冲突（PC5 是 RS485_RE/DE）——先查 `硬件说明.md` |

---

## 七、拓展练习

1. NTC 温度计算：用 β 公式或自己采 3 点做查表+线性插值，串口打印温度。
2. 滑动平均/中值滤波：对湿敏（最跳的）做 10 点滤波，对比原始波形稳定性。
3. DMA + 半传输中断：`dma_interrupt_enable(DMA0, DMA_CH0, DMA_INT_FTF)`，搬完一批处理一次。
4. 定时器触发版：TIMER2 CH0 每 10ms 触发，统计 1000 次采样的时间抖动。
5. ADC 注入组：用注入通道做"紧急检测"（电位器超限立即响应），规则组照常跑。
6. 双 ADC 同步：ADC0+ADC1 同规则并跑，理解 ADC0_1 主从模式（查手册 `adc_mode_config`）。

---

## 八、本章速查卡模板（学完抄一页纸）

```
【第11章 ADC/DMA速查】
引脚  ：PC2=IN12(电位器) PC3=IN13(热敏) PC4=IN14(湿敏)；必须 GPIO_MODE_AIN
时钟  ：rcu_adc_clock_config(RCU_CKADC_CKAPB2_DIV6)=20M；上限查手册
函数  ：adc_channel_length_config(ADC0, ADC_REGULAR_CHANNEL, n)
        adc_regular_channel_config(ADC0, rank, CHANNEL_x, ADC_SAMPLETIME_55POINT5)
        adc_special_function_config(ADC0, ADC_SCAN_MODE/ADC_CONTINUOUS_MODE, ENABLE)
        adc_calibration_enable → adc_dma_mode_enable → adc_enable → software_trigger_enable
DMA   ：dma_init(DMA0,DMA_CH0,&s)；periph=&ADC0_RDATA；宽度 16/16；circulation_enable
换算  ：V = raw*3.3/4095；raw=2048 → 1.65V
坑    ：忘 AIN；忘校准；DMA 宽度不匹配；number 设 1
```
