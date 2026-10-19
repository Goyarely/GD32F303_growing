# GD32F303ZE 麒麟ARM 工程模板

GD32F303ZET6（LQFP144 / Cortex-M4 @120MHz / 512KB Flash / 64KB SRAM）开发板工程，
VSCode + EIDE + arm-none-eabi-gcc + OpenOCD + cortex-debug。
目录组织仿照 `01-stm32-overview` 模板。

## 目录结构

```
GD32F303ZE/
├── App/                      # 应用层（main.c 业务 / syscalls.c libc 适配）
├── Driver/                   # 板级驱动
│   ├── usart.c/.h            #   调试串口（初始化 + 阻塞发送，串口配置在 usart.h）
│   ├── lcd.c/.h              #   LED 驱动（LED1=PA8；文件名为 lcd，内容为 LED）
│   ├── systick.c/.h          #   1ms 时基 + delay_1ms
│   └── gd32f30x_it.c         #   中断框架（SysTick_Handler 等）
├── Arm/                      # CMSIS 核心 + GD32F30x 器件文件 + 启动 + 链接脚本
│   ├── startup_gd32f30x_hd.s #   GCC 启动文件（由官方 ARM 版移植）
│   ├── gd32f303ze.ld         #   链接脚本 512K Flash / 64K SRAM
│   └── system_gd32f30x.c     #   系统时钟配置（SystemInit）
├── GD32F30x_SPL/             # GD32F30x 外设库
│   ├── Inc/                  #   外设库头文件（24 个）
│   └── Src/                  #   外设库源文件（24 个，srcDirs 自动编译）
├── openocd/gd32f30x.cfg      # OpenOCD target 脚本（0.12 无内置，自建）
├── target/gd32f30x.cfg       # 转发 shim：EIDE 烧录器拼 target/<名>.cfg 时用
├── GD32F303ZE-麒麟ARM-原理图解析.md  # 板级资料（速查卡/网表在上级目录）
├── .eide/                    # EIDE 工程配置
└── build/                    # 构建输出（git 忽略）
```

## 固件库放置表（下载 GD 官方包后按此解压）

官方包：`GD32F30x_Firmware_Library_V2.1.x`（gd32mcu.com 下载中心）。

| 官方包内路径 | 放到本工程 |
| --- | --- |
| `Firmware/GD32F30x_standard_peripheral/Include/*.h` | `GD32F30x_SPL/Inc/` |
| `Firmware/GD32F30x_standard_peripheral/Source/*.c` | `GD32F30x_SPL/Src/` |
| `Firmware/CMSIS/core_cm4.h`、`core_cm4_simd.h`、`core_cmFunc.h`、`core_cmInstr.h` | `Arm/` |
| `Firmware/CMSIS/GD/GD32F30x/Include/gd32f30x.h`、`system_gd32f30x.h` | `Arm/` |
| `Firmware/CMSIS/GD/GD32F30x/Source/system_gd32f30x.c` | `Arm/` |
| `Template/gd32f30x_libopt.h` | `Arm/` |

`App`、`Driver`、`Arm`、`GD32F30x_SPL/Src` 已在 EIDE 的 srcDirs 中，**文件放入即自动编译，无需改配置**。
`GD32F30x_SPL/Inc`、`Arm`、`Driver` 已在包含路径中。

## 构建 / 烧录 / 调试

- 构建：VSCode 任务 `build`（Ctrl+Shift+B → build），或 EIDE 构建按钮
- 烧录：任务 `flash`（直接调 `openocd -f interface/stlink.cfg -f openocd/gd32f30x.cfg`）；
  也可用 `build and flash` 组合任务。EIDE 上传按钮同样可用（烧录器 interface=`stlink`、
  target=`gd32f30x`，EIDE 自动拼 `interface/`、`target/` 前缀和 `.cfg` 后缀，
  target 经 `target/gd32f30x.cfg` 转发到本配置）
- 调试：F5（cortex-debug，SVD 外设寄存器视图；需 `sudo apt install gdb-arm-none-eabi`）
- 串口：115200 8N1，板载 CH340C 口（J10 那个 Type-C）

## EIDE 配置清单（若 eide.yml 被 EIDE 重置，按此在 GUI 里核对）

EIDE 开着工程时可能用旧状态覆盖 `.eide/eide.yml`。若构建异常，打开
`.eide/eide.yml` 核对以下几项，或在 EIDE 工程设置里改：

| 项 | 值 |
| --- | --- |
| 宏定义 | `GD32F30X_HD`、`USE_STDPERIPH_DRIVER` |
| 包含路径 | `.`、`App`、`Driver`、`Arm`、`GD32F30x_SPL/Inc` |
| 链接脚本 | `Arm/gd32f303ze.ld` |
| FPU | single（`-mfpu=fpv4-sp-d16`），float-abi: hard |
| 使用系统调用 | **关闭**（`not-use-syscalls: false`，否则 printf 无输出） |
| 烧录器 | OpenOCD：interface 填 `stlink`、target 填 `gd32f30x`（裸名！EIDE 自动拼 `interface/`、`target/` 前缀和 `.cfg` 后缀，填全路径会变成 `interface/interface/stlink.cfg.cfg`） |

## 时钟配置

`Arm/system_gd32f30x.c` 第 44~55 行选择系统时钟（当前：`__SYSTEM_CLOCK_120M_PLL_HXTAL`）：
外部 8MHz 晶振 → PLL ×15 → CK_SYS=120MHz，CK_AHB=120M / CK_APB1=60M / CK_APB2=120M。
换晶振或主频改这一行即可；`SystemInit()` 会自动完成 FPU 使能（CPACR）。

## 引脚速查

写 BSP 时查板级资料：`GD32F303ZE-麒麟ARM-原理图解析.md`（本目录）、
`../GD32F303ZE-麒麟ARM-速查卡.md` 与 `../GD32F303ZE-麒麟ARM-网表.json`（上级目录）。本工程用到：
LED1=PA8（另有 LED2=PE6、LED3=PF6），调试串口 USART0(TX=PA9/RX=PA10)→板上 CH340C→USB(J10)，
主晶振 8MHz(Y2)→OSC_IN/OSC_OUT，调试口 JTAG 2×10（SWD：PA13/PA14）。

## 注意

- **串口初始化必须调 `usart_transmit_config(..., USART_TRANSMIT_ENABLE)`**：
  `usart_deinit()` 会把 `CTL0.TEN/REN` 清零，只调 `usart_enable()`（仅置 UEN 位）时
  `usart_data_transmit()` 只是写数据寄存器，TX 引脚不会输出任何数据（表现为"串口完全无输出"）
- `printf` → `App/syscalls.c` 的 `_write()` → `Driver/usart.c` 的 `usart_send()` → 调试串口
  （默认 **USART0：PA9/PA10**，板载 CH340C；改用外置 USB-TTL 时把 `Driver/usart.h` 里的 6 行配置
  换成注释中的 USART1/PA2/PA3 版本）
- 串口 RX 配成上拉输入（`GPIO_MODE_IPU`），避免悬空误触发起始位
- 器件宏 `GD32F30X_HD` + 启动文件 `startup_gd32f30x_hd.s` 必须与 512KB 容量匹配
- 板的 CH340C 带 DTR/RTS 一键下载电路（控制 BOOT0/NRST）：普通串口工具打开端口会让 MCU
  复位一次（表现为灯短暂停一下），属正常现象；EIDE/OpenOCD 烧录走 SWD，不受影响
- `malloc` 用 `_sbrk`（链接脚本已预留 `_heap_start/_heap_end`）
- PA11/PA12 为 USB 与 CAN 复用（板上跳线选择），勿同时占用
- 启动文件与链接脚本的符号（`_estack/_sidata/_sdata/_edata/_sbss/_ebss`）互相配套，改一个要同步改另一个

## 作为工程模板复用

本工程可直接当模板：编译、烧录（OpenOCD + ST-Link/V2）、串口输出（USART0/CH340C）、
编辑器索引（clangd + compile_commands）均已实测可用。

**新建工程：**

```bash
cp -r GD32F303ZE MyProject && cd MyProject && rm -rf build
```

1. **保持 EIDE 工程名 `GD32F303ZE` 不变**，只改文件夹名——`.vscode/tasks.json`（hex 路径）
   和 `.vscode/launch.json`（elf 路径、SVD）里的文件名带工程名，改工程名要同步改这两处。
2. `.pack/` 若没一起复制，打开工程时 EIDE 会提示安装 `GD32F30x_DFP`，装一次即可（也能自动补）。
3. 日常只改 `App/`（应用）、`Driver/`（板级驱动/中断/时基）；`Arm/`、`GD32F30x_SPL/` 不用动。
4. 建议 `git init` 做版本管理，`.gitignore` 已配好（忽略 `build/`、`.pack/`）。

**换芯片容量时改 3 处：**

| 容量 | 器件宏 | 启动文件 | `Arm/gd32f303ze.ld` 的 `LENGTH` |
| --- | --- | --- | --- |
| ≥512KB（本工程 ZET6） | `GD32F30X_HD` | `startup_gd32f30x_hd.s` | `512K` |
| 128~256KB | `GD32F30X_CL` | `startup_gd32f30x_cl.s` | 按实际改 |
| ≤64KB | `GD32F30X_XD` | `startup_gd32f30x_xd.s` | 按实际改 |

同时改 `eide.yml` 的 `deviceName`、`.vscode/launch.json` 的 `device` 与 `svdFile`。

**模板里不用改的部分：** `openocd/gd32f30x.cfg` 与 `target/gd32f30x.cfg` 已适配 GD32F30x 的
SW-DP IDCODE（0x2ba01477）和 512KB Flash，换板子一般无需改动。
