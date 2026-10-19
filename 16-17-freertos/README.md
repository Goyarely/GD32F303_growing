# 16-17 · FreeRTOS

> 对应课程：16-17-FreeRTOS
> 前置要求：第 11 章（ADC/DMA）、第 13/14 章（存储）
> 建议耗时：2-3 周

---

## 本章实板资源

| 资源 | 用途 |
|---|---|
| 全部前面章节的驱动 | FreeRTOS 化的对象：LED/按键/串口/ADC/EEPROM/Flash/WiFi |
| SysTick | ⚠️ 与 FreeRTOS **冲突点**（母本 `systick.c` vs FreeRTOS 的 tick） |
| TIMER2 | 备用 tick 源（避开 SysTick 冲突的方案） |

---

## 一、学习内容

### 1. 为什么上 RTOS

裸机状态机 → 任务数一多，"一个任务卡全部卡"。
RTOS 给你：**任务调度、队列、信号量、事件组、软件定时器、内存管理**。

### 2. FreeRTOS 基础

| 概念 | 要点 |
|---|---|
| 任务（Task） | `xTaskCreate(vTask, "name", stack, param, prio, &handle)` |
| 调度 | 同优先级**时间片轮转** + 高优先级**抢占**；配置 `configUSE_PREEMPTION` |
| Tick | `configCPU_CLOCK_HZ=120000000`，`configTICK_RATE_HZ=1000`（1ms） |
| 队列 | 任务间传数据（ISR 用 `xQueueSendFromISR`） |
| 信号量 | 同步/互斥（二值/计数/互斥） |
| 事件组 | 多事件等待（`xEventGroupWaitBits`） |
| 通知 | 轻量替代信号量（`xTaskNotify`） |
| 堆 | `heap_4.c`（可碎片回收）；`configTOTAL_HEAP_SIZE` 别超 SRAM |

### 3. 移植到 GD32F303（GCC，Cortex-M4F）

- 源码：FreeRTOS 内核（`Source/`：`tasks.c queue.c list.c timers.c` + `portable/GCC/ARM_CM4F/`）
- `FreeRTOSConfig.h` 关键项：

```c
#define configCPU_CLOCK_HZ            120000000U
#define configTICK_RATE_HZ            1000U
#define configMAX_PRIORITIES           5U
#define configMINIMAL_STACK_SIZE      128U        /* word = 4 字节 */
#define configTOTAL_HEAP_SIZE          16384U      /* 16KB，SRAM 64K 够用 */
#define configMAX_SYSCALL_INTERRUPT_PRIORITY 0x20U /* 5 → 优先级数值 ≥5 才能在中断里调 API */
#define configUSE_MUTEXES              1U
#define configUSE_COUNTING_SEMAPHORES  1U
#define configSUPPORT_DYNAMIC_ALLOCATION 1U
#define configUSE_IDLE_HOOK            1U
```

> **`configMAX_SYSCALL_INTERRUPT_PRIORITY` 陷阱**：M4 优先级数值越小越高。
> 能在中断里调 FreeRTOS API 的中断，其 NVIC 优先级数值必须 **≥ 5**（即比 tick 低）。

### 4. ⚠️ SysTick 冲突（本工作区特有）

母本 `Driver/systick.c` 占了 SysTick（`delay_1ms`）。
FreeRTOS 也要 SysTick 当 tick（`xPortSysTickHandler`）。

| 方案 | 做法 |
|---|---|
| A（推荐） | **去掉母本 systick.c**，`delay_ms` 改用 `vTaskDelay(pdMS_TO_TICKS(n))` |
| B | FreeRTOS 用 `vPortSetupTimerInterrupt` 改挂 TIMER2，SysTick 留给裸机延时 |

---

## 二、学习目标

- [ ] 能把 FreeRTOS 加进母本工程并跑起来（两个任务闪两个 LED）
- [ ] 能解决 SysTick 冲突（说清 A/B 两种方案）
- [ ] 能用队列把"ISR 数据"传给任务
- [ ] 能用互斥量保护 I2C/SPI 总线（多任务共享外设）
- [ ] 能用 FreeRTOS 重构第 11~14 章的采集项目

---

## 三、学习方法

1. **先跑后改**：先把 FreeRTOS demo（2 任务）跑通，再迁移自己的代码。
2. **对比裸机**：同一个"按键+闪灯+打印"功能，裸机版和 RTOS 版各写一遍，列差异。
3. **看调度**：`uxTaskGetSystemState()` 抓各任务运行时间，理解"谁在跑"。
4. **故意死锁**：两个任务互等两个互斥量，观察挂死，再理解优先级继承。
5. **栈用量实测**：`uxTaskGetStackHighWaterMark()`，别拍脑袋定栈大小。

---

## 四、标准示例

### 1. 最小双任务（LED1 / LED2 各闪各的）

```c
#include "gd32f30x.h"
#include "FreeRTOS.h"
#include "task.h"

static void vTaskLed1(void *pvParameters)
{
    (void)pvParameters;
    for (;;) {
        gpio_bit_set(GPIOA, GPIO_PIN_8);
        vTaskDelay(pdMS_TO_TICKS(200U));
        gpio_bit_reset(GPIOA, GPIO_PIN_8);
        vTaskDelay(pdMS_TO_TICKS(800U));
    }
}

/* GD32F30x SPL 没有 gpio_bit_toggle，用输出锁存读-改-写（任务级安全） */
#define LED2_TOGGLE()  do { \
    uint16_t p = gpio_output_port_get(GPIOE); \
    gpio_bit_write(GPIOE, GPIO_PIN_6, (p & GPIO_PIN_6) ? RESET : SET); \
} while (0)

static void vTaskLed2(void *pvParameters)
{
    (void)pvParameters;
    for (;;) {
        LED2_TOGGLE();
        vTaskDelay(pdMS_TO_TICKS(500U));
    }
}

int main(void)
{
    /* 系统时钟/FPU 由 SystemInit 完成；不再调母本 systick_config() */
    rcu_periph_clock_enable(RCU_GPIOA);
    rcu_periph_clock_enable(RCU_GPIOE);
    gpio_init(GPIOA, GPIO_MODE_OUT_PP, GPIO_OSPEED_50MHZ, GPIO_PIN_8);
    gpio_init(GPIOE, GPIO_MODE_OUT_PP, GPIO_OSPEED_50MHZ, GPIO_PIN_6);

    xTaskCreate(vTaskLed1, "led1", 128U, NULL, 2U, NULL);
    xTaskCreate(vTaskLed2, "led2", 128U, NULL, 2U, NULL);
    vTaskStartScheduler();                     /* 不返回 */

    for (;;) { }                               /* 堆不够建任务才会到这 */
}

/* LED1 = PA8，同样没有 gpio_bit_toggle */
#define LED1_TOGGLE()  do { \
    uint16_t p = gpio_output_port_get(GPIOA); \
    gpio_bit_write(GPIOA, GPIO_PIN_8, (p & GPIO_PIN_8) ? RESET : SET); \
} while (0)
```

### 2. 队列：ISR（按键）→ 任务

```c
static QueueHandle_t s_key_queue;

void EXTI0_IRQHandler(void)
{
    if (exti_interrupt_flag_get(EXTI_0) != RESET) {
        exti_interrupt_flag_clear(EXTI_0);
        uint8_t key = 1U;
        BaseType_t woken = pdFALSE;
        xQueueSendFromISR(s_key_queue, &key, &woken);
        portYIELD_FROM_ISR(woken);
    }
}

static void vTaskKey(void *pvParameters)
{
    uint8_t key;
    for (;;) {
        if (xQueueReceive(s_key_queue, &key, portMAX_DELAY) == pdTRUE) {
            printf("key %u pressed\r\n", key);
            LED1_TOGGLE();
        }
    }
}
/* main 里：s_key_queue = xQueueCreate(8, sizeof(uint8_t)); */
```

### 3. 互斥量保护共享 I2C（EEPROM + OLED 同总线）

```c
static SemaphoreHandle_t s_i2c_mutex;

void i2c0_lock(void)   { xSemaphoreTake(s_i2c_mutex, portMAX_DELAY); }
void i2c0_unlock(void) { xSemaphoreGive(s_i2c_mutex); }

void eeprom_write_byte_safe(uint8_t addr, uint8_t data)
{
    i2c0_lock();
    eeprom_write_byte(addr, data);      /* 原第 12 章裸函数 */
    i2c0_unlock();
}

/* main 里：s_i2c_mutex = xSemaphoreCreateMutex(); */
```

### 4. 软件定时器 + 事件组（周期采集 + 事件汇总）

```c
static TimerHandle_t     s_sample_timer;
static EventGroupHandle_t s_events;

#define EVT_SAMPLE_DONE  (1UL << 0)
#define EVT_WIFI_READY   (1UL << 1)

static void vSampleTimerCallback(TimerHandle_t xTimer)
{
    adc_software_trigger_enable(ADC0, ADC_REGULAR_CHANNEL);
    xEventGroupSetBitsFromISR(s_events, EVT_SAMPLE_DONE, NULL);
}

static void vTaskCollect(void *pvParameters)
{
    for (;;) {
        EventBits_t bits = xEventGroupWaitBits(s_events,
                                               EVT_SAMPLE_DONE | EVT_WIFI_READY,
                                               pdTRUE, pdTRUE, portMAX_DELAY);
        if (bits & EVT_SAMPLE_DONE) {
            printf("adc: %u %u %u\r\n", g_adc_buf[0], g_adc_buf[1], g_adc_buf[2]);
        }
        if (bits & EVT_WIFI_READY) {
            wifi_upload("hello");
        }
    }
}
```

---

## 五、自我检测

1. FreeRTOS 的 tick 时钟怎么配？`configCPU_CLOCK_HZ` 填多少？
2. 母本 `systick.c` 和 FreeRTOS 冲突的根源是什么？两种解法各是什么代价？
3. 中断里能直接 `printf` 吗？为什么？正确做法是什么？
4. `configMAX_SYSCALL_INTERRUPT_PRIORITY = 5` 意味着哪些中断能调 FreeRTOS API？
5. `vTaskDelay` 和裸机 `delay_1ms` 的本质区别是什么？
6. 队列和互斥量分别解决什么问题？各给一个本项目的例子。
7. `xQueueSendFromISR` 最后为什么要 `portYIELD_FROM_ISR`？
8. 任务栈大小怎么定？`configMINIMAL_STACK_SIZE` 的单位是什么？

---

## 六、常见坑

| 现象 | 原因 |
|---|---|
| 调度器起不来 / 进 HardFault | ① 堆太小建不出任务；② `vTaskStartScheduler` 前时钟没配好；③ 中断里调了 API 但优先级冲突 |
| SysTick 与母本冲突，延时全乱 | 没去掉 `systick.c`；或两处都配了 SysTick |
| 中断里 `printf` 卡死 | `printf` 不是可重入的；ISR 里只发队列，打印放任务里 |
| 高优先级任务饿死低优先级 | 同优先级靠时间片；高优先级不阻塞就永远跑——设计要"该阻塞就阻塞" |
| 偶发数据错乱 | 共享变量没保护：`volatile` 只是保可见性，**临界区要互斥量或关中断** |
| 栈溢出（configCHECK_FOR_STACK_OVERFLOW） | 局部大数组/深递归；用 `uxTaskGetStackHighWaterMark` 实测 |
| 任务延迟不准 | tick 粒度 1ms 是下限；`vTaskDelay` 至少 1 tick；要更细用定时器 |
| FPU 上下文被踩 | Cortex-M4F 的 port 已处理 lazy stacking；确认用了 `ARM_CM4F` port 而非 `ARM_CM3` |
| 多个任务同时用 USART0 | 加互斥量包 `usart_send_string`；或设计单一"打印任务"收队列 |

---

## 七、拓展练习

1. 迁移：把第 11 章 ADC+DMA 采集、第 12 章 EEPROM 存储、第 07 章串口打印拆成三个任务 + 一个互斥量保护的 I2C。
2. 看门狗 + RTOS：FWDGT 喂狗放独立低优先级任务，任一任务卡死 → 任务不喂 → 复位。
3. 软件定时器集群：5 个不同周期任务（10ms/50ms/100ms/1s/5s），统计各任务执行时间占比。
4. 事件组重构：WiFi 连接（`EVT_WIFI_READY`）+ 采样完成（`EVT_SAMPLE_DONE`）都就绪才上传。
5. 内存管理：`heap_4` 下反复创建删除任务，用 `xPortGetFreeHeapSize` 看碎片。
6. 优先级继承实验：低优先级持锁、高优先级等锁、中优先级乱跑，观察优先级继承如何救场。

---

## 八、本章速查卡模板（学完抄一页纸）

```
【第16-17章 FreeRTOS速查】
配置  ：configCPU_CLOCK_HZ=120000000；TICK_RATE_HZ=1000；port=ARM_CM4F；heap_4
        MAX_SYSCALL_INTERRUPT_PRIORITY=5（优先级数值≥5 的中断才能调 API）
冲突  ：母本 systick.c 占 SysTick → 删掉用 vTaskDelay，或 tick 改挂 TIMER2
任务  ：xTaskCreate(fn,"n",stack,NULL,prio,&h)；vTaskDelay(pdMS_TO_TICKS(ms))
同步  ：队列(ISR 用 FromISR+portYIELD_FROM_ISR)；互斥量护总线；事件组等多条件
调试  ：uxTaskGetStackHighWaterMark / uxTaskGetSystemState / xPortGetFreeHeapSize
坑    ：ISR 里 printf；共享变量只加 volatile；堆/栈不够；优先级饿死
毕业  ：ADC(DMA)任务 + EEPROM/Flash 任务 + 显示任务 + WiFi 上传任务 + 喂狗任务
```
