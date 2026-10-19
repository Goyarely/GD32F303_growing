# GD32F303ZE 学习工作区

GD32F303ZET6（麒麟ARM 开发板）的嵌入式学习仓库：每个练习对应一个外设，独立可编译、可烧录。
**从 F103（STM32F103C8T6 + HAL）整体迁移到 F303（GD32F303ZET6 + SPL）**，目录组织沿用
`stm32_growing`（F103 学习仓库）的编号与方法论，示例代码全部改写为 GD32F30x 标准外设库（SPL）。

模板母本在 `GD32F303ZE/`，**只用来复制，不要直接在上面做实验**。

---

## 一、目录结构

```
GD32F303_1012/
├─ gd32_learn.code-workspace   ★唯一入口：打开这一个窗口
├─ README.md                    本文件
├─ 00-overview.md               ★学习总览（路线图 / 方法论 / 进度表）
├─ 01-stm32-overview/           第 01 章笔记 + 实验工程（同目录）
├─ 02-gpio/                     第 02 章笔记 + 实验工程
├─ ...
├─ 16-17-freertos/              第 16-17 章笔记 + 实验工程
├─ 硬件说明.md                   ★本板引脚分配唯一事实来源
├─ 排错手册.md                   踩坑记录（按症状索引）
├─ GD32F303ZE/                  模板母本（干净、未动过，不要改）
│   └─ GD32F303ZE.code-workspace 单独打开母本时用（平时不用）
├─ material/                    官方资料（GD32F30x 固件库、手册）
└─ GD32F303ZE-麒麟ARM-*.md/json 板级资料（速查卡 / 网表 / 原理图解析）
```

> 每章目录 = 一份 `README.md` 笔记 + 一份可直接编译的工程（从 `GD32F303ZE/` 复制），
> 笔记与代码同目录，回看时最省事。

## 二、打开方式（唯一入口）

**永远只打开这一个：**

```
GD32F303_1012/gd32_learn.code-workspace
```

- 同一个窗口一直用下去，聊天记录 / 上下文才连续
- ❌ 不要双击子工程里的 `xxx.code-workspace`
- ❌ 不要用「文件 → 打开文件夹」打开子工程目录
- ❌ 不要往 workspace 里再 Add Folder（整个仓库已挂载，加子目录会让同一工程被识别两次）

## 三、新建一个实验工程（3 步）

**① 复制母本**（VSCode 终端里执行，Ctrl+` 打开）

```bash
cp -r GD32F303ZE 02-gpio && rm -rf 02-gpio/build
```

**② 改名字**（4 处必须完全一致，否则 EIDE 里会重名 / 烧录脚本找不到 hex）

以 `02-gpio` 为例：

| 文件 | 改什么 |
|---|---|
| `.eide/eide.yml` 第 2 行 | `name: GD32F303ZE` → `name: 02-gpio` |
| `.eide/eide.yml` 的 `uid:` | 换成任意唯一 32 位十六进制（不能和别的工程重复） |
| `.vscode/tasks.json` | `build/Debug/GD32F303ZE.hex` → `build/Debug/02-gpio.hex` |
| `.vscode/launch.json` | `name` 和 `executable`（`build/Debug/GD32F303ZE` → `build/Debug/02-gpio`） |

> 母本的 EIDE target 名是 `Debug`（与工程名解耦），**不用改**；改的只有 `name` 和 `uid`。
> 改 `eide.yml` 前先在 EIDE 里「关闭项目」，改完再「打开项目」（EIDE 开着工程时会用内存状态覆盖文件）。

**③ 在 EIDE 里启用**

EIDE 侧边栏 → 项目上右键 →「刷新」→「设为活动」

## 四、构建 / 烧录 / 调试

| 操作 | 方法 |
|---|---|
| 构建 | Ctrl+Shift+B → `build`，或 EIDE 构建按钮 |
| 烧录 | Ctrl+Shift+B → `flash`（OpenOCD + ST-Link，走 SWD，与 BOOT0 无关） |
| 构建+烧录 | Ctrl+Shift+B → `build and flash` |
| 重新构建 | 改了 `eide.yml`（宏 / 包含路径）之后必须用 |
| 调试 | F5（cortex-debug + OpenOCD + SVD 外设寄存器视图） |

- ⚠️ 不要点「构建所有项目」——会把所有工程都编一遍
- 多工程时先确认**活动项目**是这次要烧的（工程列表认名字，不认顺序）
- 产物位置：`<工程目录>/build/Debug/<工程名>.hex`
- 调试需要 `sudo apt install gdb-arm-none-eabi`

## 五、EIDE 侧操作速查

| 想做什么 | 操作 |
|---|---|
| 加 SPL 源文件（学新外设时） | 母本 `srcDirs` 已含 `GD32F30x_SPL/Src`，**24 个外设 .c 全自动编译，不用手动加** |
| 改宏 / 包含路径 | 项目右键 →「修改编译配置」 |
| 看实际构建参数（排错） | 项目右键 →「显示构建参数」 |
| 改芯片 | 项目右键 →「设置芯片」 |
| 生成调试配置 | 项目右键 →「生成调试配置」→ OpenOCD |

**改了 `eide.yml` 后必须：刷新 → 重新构建。**

## 六、命名规范

- 目录名前缀两位数字，与课程章节一一对应：`02-gpio`、`03-key-interrupt-buzzer`、`04-timer-systick`
- **一个工程只学一个外设**，跑通就提交（`git init` + commit，母本 `.gitignore` 已配好）
- 四处名字必须一致：目录名 = `eide.yml` 的 `name` = tasks.json 的 hex 名 = launch.json 的 elf 名

## 七、学习进度

| 序号 | 目录（= 工程） | 内容 | 状态 |
|---|---|---|---|
| 01 | `01-stm32-overview` | GD32F303 概述 + 环境 + 工程搭建 | 进行中 |
| 02 | `02-gpio` | GPIO 8 种模式、SPL↔寄存器对照 | 待开始 |
| 03 | `03-key-interrupt-buzzer` | EXTI/NVIC、中断式按键、蜂鸣器 | 待开始 |
| 04 | `04-timer-systick` | 定时器时基、定时中断、PSC/ARR 计算 | 待开始 |
| 05 | `05-boot-pwm-startup` | 启动模式、PWM、启动文件、串口下载 | 待开始 |
| 06 | `06-servo-uart-concept` | 舵机控制、串口概念 | 待开始 |
| 07 | `07-uart-printf` | 串口收发、printf 重定向 | 待开始 |
| 08 | `08-bluetooth-debug` | 无线调试通道、Debug 单步调试 | 待开始 |
| 09 | `09-rs485-ultrasonic-bitband` | RS485、超声波、位段操作 | 待开始 |
| 10 | `10-minsys-dht-wdt-rtc` | 温湿度、看门狗、RTC | 待开始 |
| 11 | `11-adc-dma` | ADC、DMA | 待开始 |
| 12 | `12-memory-flash-iic` | 存储器分类、内部 FLASH、IIC 协议 | 待开始 |
| 13 | `13-iic-at24c02-oled` | IIC 实现、AT24C02、显示屏 | 待开始 |
| 14 | `14-spi-w25q128` | SPI、板载 NOR Flash | 待开始 |
| 15 | `15-rfid-esp8266-hal` | ESP8684 WiFi、RFID、工程化 | 待开始 |
| 16 | `16-17-freertos` | FreeRTOS | 待开始 |

> 完整路线、阶段划分、方法论见 [`00-overview.md`](00-overview.md)。

### 实板硬件（唯一事实来源：[`硬件说明.md`](硬件说明.md)）

**学习板 = 麒麟ARM GD32F303ZET6（唯一一块，F103 两块板已不用）**

- LED：LED1=PA8、LED2=PE6、LED3=PF6；蜂鸣器 SPK=PB8（PNP 驱动，低电平响）
- 按键：KEY1=PA0、KEY2=PG13、KEY3=PG14、KEY4=PG15（均低电平有效，板载上拉+消抖电容）
- 调试串口：USART0 PA9/PA10 → 板载 CH340C → USB(J10)，115200 8N1
- 板载外设：AT24C02(I2C0 PB6/PB7)、GD25Q32 NOR Flash(SPI0 PB13/14/15 + PE2)、
  ESP8684 WiFi(USART2 PB10/PB11 + PG7)、RS485(USART1 PA2/PA3 + PC5 方向)、
  ADC 传感器(PC2 电位器 / PC3 热敏 / PC4 湿敏)、3.5 寸 TFT(EXMC)、VS1053 音频、CAN(PA11/PA12)

## 八、踩坑记录

遇到报错先查 **[`排错手册.md`](排错手册.md)**（按症状索引）。

高频三条：

| 现象 | 原因 |
|---|---|
| `printf` 无输出 | EIDE 的 `not-use-syscalls` 必须是 `false`；且串口必须调 `usart_transmit_config(..., USART_TRANSMIT_ENABLE)` |
| 改了 `eide.yml`` 不生效 | EIDE 开着工程时会用内存状态覆盖文件：先「关闭项目」再改，改完「打开项目」+ 重新构建 |
| 外设配置无效 / 灯不亮 | 忘开 `rcu_periph_clock_enable(RCU_xxx)` |

## 九、F103 → F303 迁移对照（速查）

| F103（HAL） | F303（SPL） |
|---|---|
| `STM32F103xB` + `USE_HAL_DRIVER` | `GD32F30X_HD` + `USE_STDPERIPH_DRIVER` |
| `__HAL_RCC_GPIOA_CLK_ENABLE()` | `rcu_periph_clock_enable(RCU_GPIOA)` |
| `HAL_GPIO_Init(&h)` | `gpio_init(port, mode, speed, pin)` |
| `GPIO_MODE_OUTPUT_PP` / `GPIO_SPEED_FREQ_LOW` | `GPIO_MODE_OUT_PP` / `GPIO_OSPEED_2MHZ` |
| `HAL_GPIO_WritePin` / `ReadPin` | `gpio_bit_write` / `gpio_input_bit_get` |
| `GPIOx->BSRR = pin` | `GPIO_BOP(GPIOx) = pin`（清：`GPIO_BCTL`） |
| AFIO 时钟 + `AFIO->EXTICRx` | **无 AFIO**，EXTI 线直连引脚 |
| `HAL_NVIC_EnableIRQ(IRQn)` | `nvic_irq_enable(IRQn, pre, sub)` |
| 72MHz / APB1 ≤ 36MHz | 120MHz / APB1 = 60MHz（定时器 ×2 → 120MHz） |
| `startup_stm32f103xb.s` | `startup_gd32f30x_hd.s` |
| armcc + JLink | arm-none-eabi-gcc + OpenOCD(ST-Link) |
