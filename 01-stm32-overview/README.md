# 01 · GD32F303 概述 + 开发环境安装 + 工程搭建

> 对应课程：01-STM32概述+开发环境安装+STM32工程搭建（内容已迁移到 GD32F303ZET6）
> 前置要求：无
> 建议耗时：3-5 天

---

## 本章实板引脚

本章只用到：**LED1=PA8**、调试串口 **USART0(PA9/PA10)→CH340C→USB(J10)**、SWD(PA13/PA14)。
先确认这三样能跑，后面每章都建立在它们上面。

---

## 一、学习内容

### 1. GD32F303ZET6 芯片资源

- 内核：ARM **Cortex-M4F**（带单精度 FPU），最高 **120MHz**
- 存储：**512KB Flash / 64KB SRAM**
- 封装：LQFP144，约 110 个可用 GPIO
- 外设：5×USART/UART、3×SPI(+I2S)、2×I2C、3×ADC(12bit)、2×DAC、
  TIMER0~TIMER9（TIMER0/TIMER7 高级）、CAN×2、USB FS、EXMC、SDIO、RTC、FWDGT/WWDGT
- 供电：2.6~3.6V，本板 3V3

> 与 F103 的最大差别：**主频翻倍（120MHz）、Flash 翻 8 倍（512KB）、带 FPU、外设多得多**。

### 2. Cortex-M4 核心概念

- 哈佛结构、Thumb-2 指令集、**DSP 指令 + FPU**
- 存储器映射：Code / SRAM / Peripheral / 私有外设总线
- **位带区（Bit-Band）**：别名区 `0x42000000`（第 09 章细讲）
- 寄存器组：R0-R15、xPSR、PRIMASK/FAULTMASK/BASEPRI
- 异常与中断：NVIC、优先级分组、向量表

### 3. 时钟树初识

- 时钟源：HSI(8MHz) / HSE(8MHz 晶振) / IRC40K(40kHz) / LXTAL(32.768kHz)
- PLL：HSE ×15 = **120MHz**（本工程 `Arm/system_gd32f30x.c` 第 44~55 行选 `__SYSTEM_CLOCK_120M_PLL_HXTAL`）
- 总线分频：AHB=120M、**APB1=60M**、APB2=120M
- 外设时钟默认全部关闭，用哪个开哪个（`rcu_periph_clock_enable`）
- **APB1 上定时器输入时钟 ×2 = 120MHz**（与 F103 规则相同）

### 4. 开发环境搭建

- VSCode + `Embedded IDE (EIDE)` 扩展
- 工具链：**arm-none-eabi-gcc**（`sudo apt install gcc-arm-none-eabi`）
- 器件 Pack：`GD32F30x_DFP`（打开工程时 EIDE 提示安装，装一次即可）
- 下载/调试：OpenOCD + ST-Link/V2（`sudo apt install openocd gdb-arm-none-eabi`）
- 调试扩展：`cortex-debug`

### 5. 工程结构解析（本目录即工程，与母本 `GD32F303ZE/` 同构）

```
App/          业务代码（main.c）+ syscalls.c（_write → printf 重定向）
Driver/       板级驱动（usart/lcd(就是 LED)/systick/gd32f30x_it 中断框架）
Arm/          CMSIS 核心 + gd32f30x.h(寄存器宏) + startup_gd32f30x_hd.s + gd32f303ze.ld + system_gd32f30x.c
GD32F30x_SPL/ GD32F30x 标准外设库（Inc/ 24 个头 + Src/ 24 个源，srcDirs 全自动编译）
openocd/      OpenOCD target 脚本（gd32f30x.cfg，0.12 无内置自建）
target/       EIDE 烧录器拼 target/<名>.cfg 的转发 shim
.eide/        EIDE 工程配置（eide.yml 是唯一配置来源，name: 01-stm32-overview）
build/        编译产物（git 忽略，本工程已删，构建后生成）
```

编译能跑的三个最小条件：

| 配置 | 值 | 缺了会报什么错 |
|---|---|---|
| 宏定义 | `GD32F30X_HD`、`USE_STDPERIPH_DRIVER` | `Please select first the target GD32F30x device` |
| 包含路径 | `.`、`App`、`Driver`、`Arm`、`GD32F30x_SPL/Inc` | `cannot open source input file "gd32f30x.h"` |
| 启动文件 | `Arm/startup_gd32f30x_hd.s`（必须 HD=512K） | 无中断向量表，程序跑不起来 |

### 6. 启动文件概览

- 中断向量表 `__Vectors`：第一个是栈顶地址，第二个是 `Reset_Handler`
- `Reset_Handler` → `SystemInit()`（时钟+FPU 使能）→ `__main`（C 库初始化）→ `main()`
- `.data` 段从 Flash 搬到 SRAM，`.bss` 段清零
- 弱定义（`WEAK`）：中断服务函数可在 C 里重写覆盖（`Driver/gd32f30x_it.c`）

---

## 二、学习目标

- [ ] 能画出 GD32F303ZET6 的资源框图（内核 + 总线 + 外设）
- [ ] 能说清复位后到进入 `main()` 之间发生了什么
- [ ] 能从零搭建一个可编译、可烧录、串口有输出的工程
- [ ] 能解释 `SystemCoreClock`、`SystemInit()`、`rcu_clock_freq_get()` 的作用
- [ ] 能把 HAL 写法**翻译成 SPL 写法**（对照 `../00-overview.md` 第二节迁移表）

---

## 三、学习方法

1. **手绘资源图**：自己画一遍总线拓扑（AHB → APB1/APB2 → 各外设挂在哪条）。
2. **追启动流程**：在 `Reset_Handler` 打断点，用汇编窗口单步，看它如何跳到 `main`。
3. **手动删一次文件**：把启动文件从工程移除，编译烧录，观察现象——理解它为什么必需。
4. **时钟验证**：用 `rcu_clock_freq_get()` 打印四条总线频率，与 120M/60M/120M 对账。
5. **对照 F103**：把母本 `main.c` 和当年 F103 的 HAL 版 `main.c` 逐行对照，列出差异清单。

---

## 四、标准示例

### 1. 最小可运行工程（main.c，SPL 版）

```c
#include "gd32f30x.h"
#include "systick.h"
#include "lcd.h"          /* 本工程 LED 驱动：led_init / led_on / led_off */

int main(void)
{
    /* startup 已由 SystemInit() 完成 120MHz 时钟 + FPU 使能；
       systick_config() 提供 delay_1ms() 时基（SysTick_Config(SystemCoreClock/1000)） */
    systick_config();
    led_init();

    while (1) {
        led_on();
        delay_1ms(500);
        led_off();
        delay_1ms(500);
    }
}
```

### 2. 读一次各总线频率（对账用）

```c
#include <stdio.h>
#include "gd32f30x.h"

int main(void)
{
    systick_config();
    usart_init_115200();     /* 第 07 章再展开；Driver/usart.c 已有（名字以 usart.h 为准） */

    printf("CK_SYS = %u Hz\r\n", (unsigned)rcu_clock_freq_get(CK_SYS));
    printf("CK_AHB = %u Hz\r\n", (unsigned)rcu_clock_freq_get(CK_AHB));
    printf("CK_APB1 = %u Hz\r\n", (unsigned)rcu_clock_freq_get(CK_APB1));
    printf("CK_APB2 = %u Hz\r\n", (unsigned)rcu_clock_freq_get(CK_APB2));

    while (1) {
    }
}
/* 期望输出：120000000 / 120000000 / 60000000 / 120000000 */
```

### 3. 用寄存器确认时钟源（硬件自己的记录）

```c
/* RCU 基址 0x40021000；CFG0 偏移 0x04，SWS[3:2]：0=IRC8M 1=HXTAL 2=PLL */
uint32_t sws = (*(uint32_t *)0x40021004U >> 2) & 0x3U;
```

---

## 五、自我检测

1. 说出 GD32F303ZET6 的 Flash、SRAM、主频、GPIO 数量、内核型号。
2. APB1 和 APB2 的频率分别是多少？APB1 上定时器的实际输入时钟是多少？为什么？
3. 程序从复位到 `main()` 依次经过哪些函数？
4. 为什么外设初始化前必须先使能 RCU 时钟？
5. 把启动文件从工程中删除，会出现什么现象？为什么？
6. `GD32F30X_HD` 宏、`startup_gd32f30x_hd.s`、`gd32f303ze.ld` 三者是什么关系？换 128KB 芯片要改哪几处？
7. `rcu_periph_clock_enable(RCU_GPIOA)` 与 F103 的 `__HAL_RCC_GPIOA_CLK_ENABLE()` 各自最终写到哪个寄存器？
8. F303 的 GPIO 置位用 `GPIO_BOP`，清位用 `GPIO_BCTL`；F103 的 `BSRR` 高 16 位是复位。这个差异在移植代码时会导致什么 bug？

---

## 六、常见坑

| 现象 | 原因 |
|---|---|
| `Please select first the target GD32F30x device` | 宏定义缺 `GD32F30X_HD` |
| `cannot open source input file "gd32f30x.h"` | 包含路径缺 `Arm`（它在 `Arm/` 不在 SPL 目录） |
| `undefined symbol gpio_init` 之类 | 该外设 `.c` 没编译；本工程 `srcDirs` 应含 `GD32F30x_SPL/Src` |
| 下载后不运行、灯不亮 | 启动文件没加入工程；或宏/启动文件/链接脚本容量不配套（HD/XD/CL） |
| 改了 `eide.yml` 没生效 | EIDE 开着工程会用内存状态覆盖文件：先「关闭项目」再改，改完「打开项目」+ 重新构建 |
| `printf` 无输出 | `not-use-syscalls` 不是 `false`；或串口没调 `usart_transmit_config(..., USART_TRANSMIT_ENABLE)` |
| 串口工具一打开板子就复位 | CH340C 一键下载电路行为，**正常现象**，SWD 不受影响 |

---

## 七、拓展练习

1. 把 `main.c` 的 LED 换成 **PE6（LED2）**，验证你是否真的掌握了"改引脚"（3 处：宏、驱动文件、初始化）。
2. 用 `rcu_clock_freq_get()` 打印四条总线频率，再用秒表实测 `delay_1ms(500)` 的偏差。
3. 在 `Reset_Handler` 单步跟踪，记录 `.data` 段搬运的起止地址（对照 `.map`：`_sidata/_sdata/_edata`）。
4. 把启动文件从工程移除再编译烧录，记录现象；然后加回来，理解向量表的作用。
5. 对照 F103 时代的 HAL 代码，写一份"**HAL → SPL 函数对照速查卡**"（一页纸，后续每章扩充）。
6. 读一遍 `Driver/systick.c` 和 `Driver/gd32f30x_it.c`，说出 `SysTick_Handler` 里为什么调 `delay_decrement()`。

---

## 八、母本环境验证记录（已完成）

> 母本 `GD32F303ZE/` 在转入本工作区前已完成整链路实测；本工程是它的改名副本，同构同配置。

| 项目 | 状态 |
|---|---|
| 工具链（arm-none-eabi-gcc + EIDE + Cortex-M4/hard-float） | 可用 |
| 编译（build，产物 `build/Debug/01-stm32-overview.hex`） | 可用 |
| 烧录（OpenOCD + ST-Link，走 SWD，target 裸名 `gd32f30x`） | 可用 |
| 串口输出（USART0 PA9/PA10 → CH340C，115200，printf 重定向） | 可用 |
| 调试（cortex-debug + SVD 外设视图） | 可用 |
| 编辑器索引（clangd + compile_commands.json） | 可用 |

**结论：环境不是瓶颈，可以直接进入正式学习。**

### 本工程用法

```bash
# 日常只改 App/main.c 和 Driver/ 下的驱动；Arm/、GD32F30x_SPL/ 不用动
# Ctrl+Shift+B → build and flash
```

### 下一步

1. 完成本页「自我检测」8 道题，重点第 3 题和第 8 题。
2. 按 `../README.md` 第三节，把母本复制成 `../02-gpio` 工程（4 处改名）。
3. 进入第 02 章 GPIO（`../02-gpio/README.md`）。
