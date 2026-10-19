# GD32F303ZE「麒麟 ARM」开发板 — 原理图结构化解析

> 本文件由 Altium 工程源文件（`Project/*.SchDoc`）自动解析生成，用于让 AI 助手（VSCode / Cursor 等）直接理解整块板子的电路结构，无需阅读 PDF 原理图。
> 解析来源：`GD32F303ZE-麒麟ARM.pdf`（6 页图纸）+ `Project/` 下 6 个 Altium 原理图源文件。

---

## 1. 板子基本信息

| 项目 | 内容 |
| --- | --- |
| 板卡名称 | GD32F303ZE-麒麟ARM |
| 主控 MCU | **GD32F303ZET6**（LQFP144，ARM Cortex-M4 @120MHz，512KB Flash / 64KB SRAM） |
| 板卡尺寸 | 160 × 115 mm，板厚 1.6 mm，盖黑油（其余常规工艺） |
| 工程文件 | `GD32F303ZE.PrjPCB` / PCB：`GD32F303ZE_V1.2.PcbDoc` |
| 设计日期 | 2023-07-04 |
| 供电 | USB Type-C 5V 输入 → APW7104 DC-DC 降压至 3V3；另有 WiFi 独立 3V3 域 |

## 2. 原理图页与功能划分

| PDF 页 | 源文件 | 功能 |
| --- | --- | --- |
| 第5页 | `Power-WIFI.SchDoc` | 电源与 WiFi（USB 供电 / DC-DC / ESP32-C2 模组 / 电源引出） |
| 第4页 | `MCU.SchDoc` | MCU 主控（GD32F303ZET6 全部 144 引脚 + 时钟 / 复位 / BOOT / JTAG / 电源去耦） |
| 第6页 | `Sensors-LED-KEY-USB_.SchDoc` | 传感器 / 按键 / LED / USB 转串口（红外、蜂鸣器、湿敏、热敏、电位器、4 按键、3 LED、CH340C） |
| 第3页 | `LCD-EEPROM-IRLED-FLASH-EXTENSION.SchDoc` | 显示与存储扩展（3.5 寸 TFT + SRAM + EEPROM + NOR Flash + 光感/接近传感器 + 引出 IO 排针） |
| 第1页 | `485-232-CAN-TF.SchDoc` | 工业通信与存储卡（RS485 + RS232 + CAN + TF 卡座） |
| 第2页 | `Audio.SchDoc` | 音频（VS1053 解码 + MIC 输入 + FM8002A 功放 + LDO） |

## 3. 电源架构

```
USB Type-C (J1) ──[F1 保险丝]──[D10 SMBJ6.5CA TVS]── +5V
     │                                   │
     └ CC1/CC2 ─ R3/R4 5.1k 下拉          ├── C1 1000uF/10V + C2 100uF
                                           │
                              U3 APW7104 (DC-DC 降压)
                                           │  L1 2.2uH/3A
                                           ▼
                                          3V3 ──┬── C3 100uF/10V, C5 100uF/10V, C7 100nF
                                                ├── R11 1k + D10 LED（电源指示）
                                                └── MCU / 各外设

WiFi 独立电源域：3V3 ──[R68 10k / WiFi_EN 控制]── WiFi_3V3 ── U14 ESP8684 模组
模拟电源：3V3 ──[FB1 600R@100MHz]── VDDA (+ C17 100nF)，VREF 单独去耦 C16 100nF
电池备份：BT1 ──[D1 BAT54C]── VBAT (+ C12 100nF)
```

> J33（2×5 排针）把 `GND / +5V / 3V3` 引出，方便外部取电。

## 4. MCU（U1, GD32F303ZET6）引脚分配表

> 引脚号 = LQFP144 物理引脚；网络名为原理图上的标注（功能网络）。
> 标注 `3V3/GND/VDDA/VBAT/VREF` 的为电源引脚。
> 注：原理图中 MCU 符号绘制了两份（一份用于功能标注，一份用于实际连线），此处已按引脚号合并去重。

| 引脚 | 引脚名 | 功能网络 | 归属外设 |
| --- | --- | --- | --- |
| 1 | PE2 | SPIFlash_CS | SPI (NOR Flash) |
| 2 | PE3 | VS_XCS | 音频 |
| 3 | PE4 | VS_XDCS | 音频 |
| 4 | PE5 | VS_DREQ | 音频 |
| 5 | PE6 | LED2 | LED / 按键 |
| 6 | VBAT | VBAT | 电源 |
| 7 | PC13-TAMPER-RTC | VS_RST | 音频 |
| 8 | PC14-OSC32IN | OSC32_IN | 时钟 |
| 9 | PC15-OSC32OUT | OSC32_OUT | 时钟 |
| 10 | PF0 | EXMC_A0 | 外部总线 (LCD/SRAM) |
| 11 | PF1 | EXMC_A1 | 外部总线 (LCD/SRAM) |
| 12 | PF2 | EXMC_A2 | 外部总线 (LCD/SRAM) |
| 13 | PF3 | EXMC_A3 | 外部总线 (LCD/SRAM) |
| 14 | PF4 | EXMC_A4 | 外部总线 (LCD/SRAM) |
| 15 | PF5 | EXMC_A5 | 外部总线 (LCD/SRAM) |
| 16 | VSS_5 | GND | 电源 |
| 17 | VDD_5 | 3V3 | 电源 |
| 18 | PF6 | LED3 | LED / 按键 |
| 19 | PF7 | — |  |
| 20 | PF8 | — |  |
| 21 | PF9 | TP_SDA | 触摸屏 / 红外 |
| 22 | PF10 | TP_SCL | 触摸屏 / 红外 |
| 23 | OSCIN | OSC_IN | 时钟 |
| 24 | OSCOUT | OSC_OUT | 时钟 |
| 25 | NRST | NRST | 调试 / 复位 |
| 26 | PC0 | — |  |
| 27 | PC1 | — |  |
| 28 | PC2 | ADJ_RES | ADC |
| 29 | PC3 | ADC_TEMP | ADC |
| 30 | VSSA | AGND | 电源 |
| 31 | VREF- | VREF- | 电源 |
| 32 | VREF+ | VREF+ | 电源 |
| 33 | VDDA | VDDA | 电源 |
| 34 | PA0_WKUP | KEY1 | LED / 按键 |
| 35 | PA1 | LCD_BL | LED / 按键 |
| 36 | PA2 | USART1_TX | 串口 |
| 37 | PA3 | USART1_RX | 串口 |
| 38 | VSS_4 | GND | 电源 |
| 39 | VDD_4 | 3V3 | 电源 |
| 40 | PA4 | I2S2_WS | 音频 |
| 41 | PA5 | VS_SCK | 音频 |
| 42 | PA6 | VS_MISO | 音频 |
| 43 | PA7 | VS_MOSI | 音频 |
| 44 | PC4 | ADC_RH | ADC |
| 45 | PC5 | RS485_RE/DE |  |
| 46 | PB0 | TIMER2_CH2 | 定时器 |
| 47 | PB1 | TIMER2_CH3 | 定时器 |
| 48 | PB2 | BOOT1 | 启动配置 |
| 49 | PF11 | IRLED_INT | 触摸屏 / 红外 |
| 50 | PF12 | EXMC_A6 | 外部总线 (LCD/SRAM) |
| 51 | VSS_6 | GND | 电源 |
| 52 | VDD_6 | 3V3 | 电源 |
| 53 | PF13 | EXMC_A7 | 外部总线 (LCD/SRAM) |
| 54 | PF14 | EXMC_A8 | 外部总线 (LCD/SRAM) |
| 55 | PF15 | EXMC_A9 | 外部总线 (LCD/SRAM) |
| 56 | PG0 | EXMC_A10 | 外部总线 (LCD/SRAM) |
| 57 | PG1 | EXMC_A11 | 外部总线 (LCD/SRAM) |
| 58 | PE7 | EXMC_D4 | 外部总线 (LCD/SRAM) |
| 59 | PE8 | EXMC_D5 | 外部总线 (LCD/SRAM) |
| 60 | PE9 | EXMC_D6 | 外部总线 (LCD/SRAM) |
| 61 | VSS_7 | GND | 电源 |
| 62 | VDD_7 | 3V3 | 电源 |
| 63 | PE10 | EXMC_D7 | 外部总线 (LCD/SRAM) |
| 64 | PE11 | EXMC_D8 | 外部总线 (LCD/SRAM) |
| 65 | PE12 | EXMC_D9 | 外部总线 (LCD/SRAM) |
| 66 | PE13 | EXMC_D10 | 外部总线 (LCD/SRAM) |
| 67 | PE14 | EXMC_D11 | 外部总线 (LCD/SRAM) |
| 68 | PE15 | EXMC_D12 | 外部总线 (LCD/SRAM) |
| 69 | PB10 | USART2_TXD | 串口 |
| 70 | PB11 | USART2_RXD | 串口 |
| 71 | VSS_1 | GND | 电源 |
| 72 | VDD_1 | 3V3 | 电源 |
| 73 | PB12 | TP_INT | 触摸屏 / 红外 |
| 74 | PB13 | SPI0_CLK | SPI (NOR Flash) |
| 75 | PB14 | SPI0_MISO | SPI (NOR Flash) |
| 76 | PB15 | SPI0_MOSI | SPI (NOR Flash) |
| 77 | PD8 | EXMC_D13 | 外部总线 (LCD/SRAM) |
| 78 | PD9 | EXMC_D14 | 外部总线 (LCD/SRAM) |
| 79 | PD10 | EXMC_D15 | 外部总线 (LCD/SRAM) |
| 80 | PD11 | EXMC_A16 | 外部总线 (LCD/SRAM) |
| 81 | PD12 | EXMC_A17 | 外部总线 (LCD/SRAM) |
| 82 | PD13 | EXMC_A18 | 外部总线 (LCD/SRAM) |
| 83 | VSS_8 | GND | 电源 |
| 84 | VDD_8 | 3V3 | 电源 |
| 85 | PD14 | EXMC_D0 | 外部总线 (LCD/SRAM) |
| 86 | PD15 | EXMC_D1 | 外部总线 (LCD/SRAM) |
| 87 | PG2 | EXMC_A12 | 外部总线 (LCD/SRAM) |
| 88 | PG3 | EXMC_A13 | 外部总线 (LCD/SRAM) |
| 89 | PG4 | EXMC_A14 | 外部总线 (LCD/SRAM) |
| 90 | PG5 | EXMC_A15 | 外部总线 (LCD/SRAM) |
| 91 | PG6 | EXMC_INT1 | 外部总线 (LCD/SRAM) |
| 92 | PG7 | WiFi_EN | WiFi |
| 93 | PG8 | SPK_CTRL | 音频 |
| 94 | VSS_9 | GND | 电源 |
| 95 | VDD_9 | 3V3 | 电源 |
| 96 | PC6 | IF_OUT | 音频 |
| 97 | PC7 | — |  |
| 98 | PC8 | SDIO_DAT0 | SDIO / TF 卡 |
| 99 | PC9 | SDIO_DAT1 | SDIO / TF 卡 |
| 100 | PA8 | LED1 | LED / 按键 |
| 101 | PA9 | USART0_TX | 串口 |
| 102 | PA10 | USART0_RX | 串口 |
| 103 | PA11 | USB_DM | USB |
| 104 | PA12 | USB_DP | USB |
| 105 | PA13 | TMS-SWDIO | 调试 / 复位 |
| 106 | NC | — |  |
| 107 | VSS_2 | GND | 电源 |
| 108 | VDD_2 | 3V3 | 电源 |
| 109 | PA14 | TCK-SWCLK | 调试 / 复位 |
| 110 | PA15 | TDI | 调试 / 复位 |
| 111 | PC10 | SDIO_DAT2 | SDIO / TF 卡 |
| 112 | PC11 | SDIO_DAT3 | SDIO / TF 卡 |
| 113 | PC12 | SDIO_CLK | SDIO / TF 卡 |
| 114 | PD0 | EXMC_D2 | 外部总线 (LCD/SRAM) |
| 115 | PD1 | EXMC_D3 | 外部总线 (LCD/SRAM) |
| 116 | PD2 | SDIO_CMD | SDIO / TF 卡 |
| 117 | PD3 | SDIO_CD | SDIO / TF 卡 |
| 118 | PD4 | EXMC_NOE | 外部总线 (LCD/SRAM) |
| 119 | PD5 | EXMC_NWE | 外部总线 (LCD/SRAM) |
| 120 | VSS_10 | GND | 电源 |
| 121 | VDD_10 | 3V3 | 电源 |
| 122 | PD6 | EXMC_NWAIT | 外部总线 (LCD/SRAM) |
| 123 | PD7 | EXMC_NCE1 | 外部总线 (LCD/SRAM) |
| 124 | PG9 | EXMC_NE1 | 外部总线 (LCD/SRAM) |
| 125 | PG10 | — |  |
| 126 | PG11 | — |  |
| 127 | PG12 | EXMC_NE3 | 外部总线 (LCD/SRAM) |
| 128 | PG13 | KEY2 | LED / 按键 |
| 129 | PG14 | KEY3 | LED / 按键 |
| 130 | VSS_11 | GND | 电源 |
| 131 | VDD_11 | 3V3 | 电源 |
| 132 | PG15 | KEY4 | LED / 按键 |
| 133 | PB3 | TDO | 调试 / 复位 |
| 134 | PB4 | JNTRST | 调试 / 复位 |
| 135 | PB5 | I2S_SD | 音频 |
| 136 | PB6 | I2C0_SCL | I2C |
| 137 | PB7 | I2C0_SDA | I2C |
| 138 | BOOT0 | BOOT0 | 启动配置 |
| 139 | PB8 | SPK | 音频 |
| 140 | PB9 | TP_RST | 触摸屏 / 红外 |
| 141 | PE0 | EXMC_NBL0 | 外部总线 (LCD/SRAM) |
| 142 | PE1 | EXMC_NBL1 | 外部总线 (LCD/SRAM) |
| 143 | VSS_3 | GND | 电源 |
| 144 | VDD_3 | 3V3 | 电源 |

### 4.1 按外设汇总（MCU 侧）

| 外设 | 引脚 | 说明 |
| --- | --- | --- |
| JTAG/SWD 调试 | PA13=TMS-SWDIO, PA14=TCK-SWCLK, PA15=TDI, PB3=TDO, PB4=JNTRST | 板上 JTAG 2×10 排针 |
| USART0 | PA9=TX, PA10=RX | 经 CH340C 转 USB（下载/调试串口） |
| USART1 | PA2=TX, PA3=RX | 引出排针 |
| USART2 | PB10=TX, PB11=RX | 接 ESP8684 WiFi 模组（AT 固件） |
| I2C0 | PB6=SCL, PB7=SDA | EEPROM(AT24C02) / 光感(AP3216C) / 触摸屏 |
| SPI0 | PB13=SCK, PB14=MISO, PB15=MOSI | NOR Flash GD25Q32 (CS=PE2) |
| SDIO | PC8-11=DAT0-3, PC12=CLK, PD2=CMD, PD3=CD | TF 卡座 |
| EXMC (FSMC) | PF0-PF5, PF12-PF15, PG0-PG5, PD0-D1, PD4-D5, PD8-D15, PE0-1, PE7-PE15 | 地址/数据/控制总线，驱动 SRAM + LCD |
| I2S2 | PA4=WS, PB5=SD | 音频数据（VS1053） |
| CAN | PA11=RX, PA12=TX | SN65HVD230 收发器 |
| USB FS | PA11=DM, PA12=DP | USB Type-C（与 CAN 复用引脚，需跳线选择） |
| 按键 | PA0=KEY1, PG13=KEY2, PG14=KEY3, PG15=KEY4 | 独立按键 |
| LED | PA8=LED1, PE6=LED2, PF6=LED3 | 用户 LED |
| ADC | PC3=ADC_TEMP(热敏), PC4=ADC_RH(湿敏), PC2=ADJ_RES(电位器) | 模拟输入 |
| 时钟 | 8MHz 晶振(Y2) → OSC_IN/OSC_OUT；32.768kHz(Y1) → PC14/PC15 | RTC + 主时钟 |

## 5. 各页电路详解

### 5.1 Power-WIFI（第5页）

*电源与 WiFi（USB 供电 / DC-DC / ESP32-C2 模组 / 电源引出）*

- **USB 供电**：J1 USB Type-C 座 + SP0503BAHT 静电保护阵列；R3/R4 5.1k 下拉（CC1/CC2 用作设备）；F1 保险丝 + D10 SMBJ6.5CA TVS + C1 1000uF/10V + C2 100uF 滤波 → +5V
- **DC-DC 降压**：U3 APW7104 把 +5V 降到 3V3；L1 2.2uH/3A 储能电感，R10 100k 反馈分压，C3 100uF/10V + C5 100uF/10V + C7 100nF 输出滤波，R11 1k 限流点亮电源指示灯 D10
- **WiFi 模组**：U14 ESP8684-MINI-1（即 ESP32-C2，出厂为 AT 固件）；串口接 MCU PB10/PB11（USART2），使能 WiFi_EN 控制独立电源域 WiFi_3V3；J24（4pin）为模组串口引出，J26（2pin）为固件升级短接点
- **电源引出**：J33（2×5 排针）引出 GND / +5V / 3V3

**元件清单（共 31 项）**

| 位号 | 类型/型号 | 参数 | 引脚数 |
| --- | --- | --- | --- |
| U3 | APW7104 | APW7104 | 5 |
| C2 | Cap | 100nF | 2 |
| C4 | Cap | 4.7uF | 2 |
| C5 | Cap | NC | 2 |
| C51 | Cap | 1uF | 2 |
| C52 | Cap | 100nF | 2 |
| C53 | Cap | 10uF | 2 |
| C7 | Cap | 100nF | 2 |
| C1 | Cap Pol SMD | 100uF/10V | 4 |
| C3 | Cap Pol SMD | 100uF/10V | 4 |
| D6 | Diode-Bi-TVS | SMBJ6.5CA | 2 |
| D10 | Diode-LED | — | 2 |
| U14 | ESP8684-MINI-1 | ESP8684-MINI-1 | 53 |
| F1 | Fuse | 1.1A/8V | 2 |
| J26 | Header 1*2-JUMP | — | 2 |
| J24 | Header 1*4_2.54 | — | 4 |
| J33 | Header 2*5-JUMP | — | 10 |
| J1 | Header-USB-TYPEC | — | 25 |
| L1 | INDUCTOR | 2.2uH/3A | 2 |
| R1 | Res | 1.5k | 2 |
| R10 | Res | 100k | 2 |
| R11 | Res | 1k | 2 |
| R2 | Res | 5.1k | 2 |
| R3 | Res | 22R | 2 |
| R5 | Res | 22R | 2 |
| R68 | Res | 10k | 2 |
| R7 | Res | 5.1k | 2 |
| R70 | Res | 10k | 2 |
| R71 | Res | 10k | 2 |
| R9 | Res | 453k | 2 |
| S1 | SW-SPST | — | 2 |

**本页出现的网络名（29 个）**

`+5V`, `3V3`, `CC1`, `CC2`, `DCDC`, `DN`, `DP`, `GND`, `IO8`, `IO9`, `PB10`, `PB11`, `PG7`, `U0RXD`, `U0TXD`, `USART2_RXD`, `USART2_TXD`, `USB_DM`, `USB_DP`, `USB_IN`, `USB供电`, `WIFI`, `WIFI_3V3`, `WiFi_EN`, `WiFi_RXD`, `WiFi_TXD`, `上电后1-2秒，拔掉J26的跳线帽。`, `引出电源、地`, `更新WiFi固件时，先断开WiFi电源，然后短接J26，然后给WiFi上电。`

### 5.2 MCU（第4页）

*MCU 主控（GD32F303ZET6 全部 144 引脚 + 时钟 / 复位 / BOOT / JTAG / 电源去耦）*

**元件清单（共 42 项）**

| 位号 | 类型/型号 | 参数 | 引脚数 |
| --- | --- | --- | --- |
| BT1 | Battery | — | 4 |
| C10 | Cap | 100nF | 2 |
| C11 | Cap | 100nF | 2 |
| C12 | Cap | 100nF | 2 |
| C13 | Cap | 100nF | 2 |
| C14 | Cap | 100nF | 2 |
| C15 | Cap | 100nF | 2 |
| C16 | Cap | 100nF | 2 |
| C17 | Cap | 100nF | 2 |
| C18 | Cap | 100nF | 2 |
| C19 | Cap | 10pF | 2 |
| C20 | Cap | 10pF | 2 |
| C21 | Cap | 20pF | 2 |
| C22 | Cap | 20pF | 2 |
| C23 | Cap | 100nF | 2 |
| C24 | Cap | 100nF | 2 |
| C25 | Cap | 100nF | 2 |
| C26 | Cap | 100nF | 2 |
| C27 | Cap | 100nF | 2 |
| C8 | Cap | 4.7uF | 2 |
| C9 | Cap | 100nF | 2 |
| D1 | Diode-BAT54C | BAT54C | 3 |
| U1 | GD32F303ZET6 | GD32F303ZET6 | 288 |
| JTAG | Header 2*10_JTAG | — | 20 |
| FB1 | INDUCTOR | 600R±25% 100MHz | 2 |
| FB2 | INDUCTOR | 600R±25% 100MHz | 2 |
| NRST | KEY | — | 4 |
| R12 | Res | 10k | 2 |
| R13 | Res | 10k | 2 |
| R14 | Res | 10k | 2 |
| R15 | Res | 1M | 2 |
| R16 | Res | 10k | 2 |
| R17 | Res | 10k | 2 |
| R18 | Res | 10k | 2 |
| R19 | Res | 10k | 2 |
| R20 | Res | 10k | 2 |
| R21 | Res | 10k | 2 |
| R59 | Res | 10k | 2 |
| R61 | Res | 10k | 2 |
| SW2 | SW SOP-2 | — | 4 |
| Y1 | XTAL-2 | 32.768KHz | 2 |
| Y2 | XTAL-4 | 8MHz | 4 |

**本页出现的网络名（240 个）**

`1`, `3V3`, `ADC_RH`, `ADC_TEMP`, `ADJ_RES`, `AGND`, `BOOT`, `BOOT0`, `BOOT1`, `CAN_RX`, `CAN_TX`, `EXMC_A0`, `EXMC_A1`, `EXMC_A10`, `EXMC_A11`, `EXMC_A12`, `EXMC_A13`, `EXMC_A14`, `EXMC_A15`, `EXMC_A16`, `EXMC_A17`, `EXMC_A18`, `EXMC_A2`, `EXMC_A3`, `EXMC_A4`, `EXMC_A5`, `EXMC_A6`, `EXMC_A7`, `EXMC_A8`, `EXMC_A9`, `EXMC_D0`, `EXMC_D1`, `EXMC_D10`, `EXMC_D11`, `EXMC_D12`, `EXMC_D13`, `EXMC_D14`, `EXMC_D15`, `EXMC_D2`, `EXMC_D3`, `EXMC_D4`, `EXMC_D5`, `EXMC_D6`, `EXMC_D7`, `EXMC_D8`, `EXMC_D9`, `EXMC_INT1`, `EXMC_NBL0`, `EXMC_NBL1`, `EXMC_NCE1`, `EXMC_NE1`, `EXMC_NE3`, `EXMC_NOE`, `EXMC_NWAIT`, `EXMC_NWE`, `EXMC_RS`, `GND`, `I2C0_SCL`, `I2C0_SDA`, `I2S2_WS`, `I2S_SD`, `IF_OUT`, `IRLED_INT`, `JNTRST`, `JTAG`, `KEY1`, `KEY2`, `KEY3`, `KEY4`, `LCD_BL`, `LED1`, `LED2`, `LED3`, `MCU`, `N`, `NRST`, `O`, `OSC32_IN`, `OSC32_OUT`, `OSC_IN`, `OSC_OUT`, `PA0`, `PA1`, `PA10`, `PA11`, `PA12`, `PA13`, `PA14`, `PA15`, `PA2`, `PA3`, `PA4`, `PA5`, `PA6`, `PA7`, `PA8`, `PA9`, `PB0`, `PB1`, `PB10`, `PB11`, `PB12`, `PB13`, `PB14`, `PB15`, `PB2`, `PB3`, `PB4`, `PB5`, `PB6`, `PB7`, `PB8`, `PB9`, `PC0`, `PC1`, `PC10`, `PC11`, `PC12`, `PC13`, `PC14`, `PC15`, `PC2`, `PC3`, `PC4`, `PC5`, `PC6`, `PC7`, `PC8`, `PC9`, `PD0`, `PD1`, `PD10`, `PD11`, `PD12`, `PD13`, `PD14`, `PD15`, `PD2`, `PD3`, `PD4`, `PD5`, `PD6`, `PD7`, `PD8`, `PD9`, `PE0`, `PE1`, `PE10`, `PE11`, `PE12`, `PE13`, `PE14`, `PE15`, `PE2`, `PE3`, `PE4`, `PE5`, `PE6`, `PE7`, `PE8`, `PE9`, `PF0`, `PF1`, `PF10`, `PF11`, `PF12`, `PF13`, `PF14`, `PF15`, `PF2`, `PF3`, `PF4`, `PF5`, `PF6`, `PF7`, `PF8`, `PF9`, `PG0`, `PG1`, `PG10`, `PG11`, `PG12`, `PG13`, `PG14`, `PG15`, `PG2`, `PG3`, `PG4`, `PG5`, `PG6`, `PG7`, `PG8`, `PG9`, `RS485_RE/DE`, `RTCK`, `SDIO_CD`, `SDIO_CLK`, `SDIO_CMD`, `SDIO_DAT0`, `SDIO_DAT1`, `SDIO_DAT2`, `SDIO_DAT3`, `SPI0_CLK`, `SPI0_MISO`, `SPI0_MOSI`, `SPIFlash_CS`, `SPK`, `SPK_CTRL`, `TCK-SWCLK`, `TDI`, `TDO`, `TIMER2_CH2`, `TIMER2_CH3`, `TMS-SWDIO`, `TP_INT`, `TP_RST`, `TP_SCL`, `TP_SDA`, `USART0_RX`, `USART0_TX`, `USART1_RX`, `USART1_TX`, `USART2_RXD`, `USART2_TXD`, `USB_DM`, `USB_DP`, `VBAT`, `VDD`, `VDDA`, `VREF`, `VS_DREQ`, `VS_MISO`, `VS_MOSI`, `VS_RST`, `VS_SCK`, `VS_XCS`, `VS_XDCS`, `WiFi_EN`, `复位`, `晶振`

### 5.3 Sensors-LED-KEY-USB_（第6页）

*传感器 / 按键 / LED / USB 转串口（红外、蜂鸣器、湿敏、热敏、电位器、4 按键、3 LED、CH340C）*

- **红外接收 IR**：U12 IRM-1838 红外接收头，R44 47-220R + R45 10k + C41 100nF；输出 IF_OUT → PC6
- **LED 指示**：D2/D3/D4 三只 LED，限流 R43/R46/R47 1k；LED1→PA8，LED2→PE6，LED3→PF6
- **USB 转串口**：J10 USB Type-C → U13 CH340C → USART0（MCU PA9/PA10）；D9 1N4148 + Q3/Q4 S8050 构成 DTR/RTS 自动复位下载电路（控制 BOOT0 / NRST），支持一键下载
- **蜂鸣器**：Q2 S8550 PNP 驱动，D7 1N5819 续流，R55 1R + R57 10k；SPK → PB8
- **湿敏电阻**：R62 湿敏 + R63 510R + R65 10k 分压 → ADC_RH(PC4)；另引出 TIMER2_CH2(PD0) / TIMER2_CH3(PB1)
- **热敏电阻**：R64 10k + R71 NTC 10k + C49 100nF → ADC_TEMP(PC3)
- **可调电阻**：RA1 电位器 + R74 1k + C49 → ADJ_RES(PC2)
- **按键**：KEY1(PA0) / KEY2(PG13) / KEY3(PG14) / KEY4(PG15)，各配 1k 上拉 + 1k 串阻 + 100nF 消抖电容（R51-R54/R58-R61, C44/C45/C47/C48）

**元件清单（共 59 项）**

| 位号 | 类型/型号 | 参数 | 引脚数 |
| --- | --- | --- | --- |
| BZ | BUZZER | — | 2 |
| U13 | CH340C | CH340C | 16 |
| C43 | Cap | 2.2uF | 2 |
| C44 | Cap | 100nF | 2 |
| C45 | Cap | 100nF | 2 |
| C46 | Cap | 100nF | 2 |
| C47 | Cap | 100nF | 2 |
| C48 | Cap | 100nF | 2 |
| C49 | Cap | 100nF | 2 |
| C50 | Cap | 100nF | 2 |
| D7 | Diode | 1N5819 | 2 |
| D9 | Diode | 1N4148 | 2 |
| D2 | Diode-LED | — | 2 |
| D3 | Diode-LED | — | 2 |
| D4 | Diode-LED | — | 2 |
| J21 | Header 1*2_2.54 | — | 2 |
| J10 | Header-USB-TYPEC | — | 25 |
| U12 | IRM-6638T | IRM-1838 | 3 |
| KEY1 | KEY | — | 4 |
| KEY2 | KEY | — | 4 |
| KEY3 | KEY | — | 4 |
| KEY4 | KEY | — | 4 |
| Q2 | NPN | 8050 | 3 |
| Q3 | NPN | 8050 | 3 |
| Q4 | PNP | S8550 | 3 |
| RA1 | RES ADJ | — | 3 |
| R100 | Res | 5.1k | 2 |
| R101 | Res | 22R | 2 |
| R4 | Res | 22R | 2 |
| R43 | Res | 1k | 2 |
| R44 | Res | 100R | 2 |
| R45 | Res | 10k | 2 |
| R46 | Res | 1k | 2 |
| R47 | Res | 1k | 2 |
| R51 | Res | 4.7k | 2 |
| R52 | Res | 4.7k | 2 |
| R53 | Res | 1k | 2 |
| R54 | Res | 1k | 2 |
| R55 | Res | 51R | 2 |
| R56 | Res | 1k | 2 |
| R57 | Res | 10k | 2 |
| R58 | Res | 4.7k | 2 |
| R60 | Res | 1k | 2 |
| R62 | Res | 1M | 2 |
| R63 | Res | 470R | 2 |
| R64 | Res | 10k | 2 |
| R65 | Res | 39k | 2 |
| R66 | Res | 1k | 2 |
| R69 | Res | 10k | 2 |
| R77 | Res | 1k | 2 |
| R79 | Res | 4.7k | 2 |
| R91 | Res | 1k | 2 |
| R94 | Res | 10k | 2 |
| R95 | Res | 1k | 2 |
| R96 | Res | 1k | 2 |
| R97 | Res | 1k | 2 |
| R99 | Res | 5.1k | 2 |
| RT1 | Res NTC | 10k | 2 |
| RH1 | Res RH | 31K | 2 |

**本页出现的网络名（53 个）**

`+5V`, `3V3`, `47-220R`, `ADC_RH`, `ADC_TEMP`, `ADJ_RES`, `BOOT0`, `DRT#`, `D_N`, `D_P`, `GND`, `IF_OUT`, `IR`, `KEY1`, `KEY2`, `KEY3`, `KEY4`, `LED`, `LED1`, `LED2`, `LED3`, `NRST`, `PA0`, `PA8`, `PB0`, `PB1`, `PB8`, `PC2`, `PC3`, `PC4`, `PC6`, `PE6`, `PF6`, `PG13`, `PG14`, `PG15`, `RTS#`, `SPK`, `TIMER2_CH2`, `TIMER2_CH3`, `USART0_RX`, `USART0_TX`, `USB_RX`, `USB_TX`, `USB转串口`, `VDD_USB`, `≥10k`, `≥2.2uF`, `可调电阻`, `按键`, `湿敏电阻`, `热敏电阻`, `蜂鸣器`

### 5.4 LCD-EEPROM-IRLED-FLASH-EXTENSION（第3页）

*显示与存储扩展（3.5 寸 TFT + SRAM + EEPROM + NOR Flash + 光感/接近传感器 + 引出 IO 排针）*

- **3.5 寸 TFT LCD**：U11 34pin 屏接口；控制线 EXMC_RS/CS/NE1/WR/RD/RST，数据线 EXMC_D0-D15；背光 LCD_BL←PB1（R39 1k 限流）；I2C 触摸 TP_INT/TP_RST/TP_SDA/TP_SCL（R41/R42 10k 上拉）
- **SRAM**：U6 IS62WV51216BLL（512K×16bit = 1MB）挂 EXMC 总线：A0-A18、D0-D15、NE3、NBL0/NBL1、NOE、NWE；去耦 C91/C94 100nF + C95 4.7uF
- **EEPROM**：U9 AT24C02（2Kbit I2C EEPROM），R31/R32 4.7k 上拉，走 I2C0_SCL/SDA
- **光感 + 接近传感器**：U8 AP3216C（ALS + PS + IR LED），I2C0_SCL/SDA，中断 LIGHT_INT，红外 LED 驱动 IRLED_INT
- **NOR Flash**：U10 GD25Q32ESIG（4MB SPI NOR），CS←PE2（SPIFlash_CS），CLK←PB13，MISO←PB14，MOSI←PB15
- **引出 IO**：JP1A/JP1B/JP2A/JP2B 四个 2×29 排针，把 MCU 全部 IO 引出（含 3V3/GND）

**元件清单（共 26 项）**

| 位号 | 类型/型号 | 参数 | 引脚数 |
| --- | --- | --- | --- |
| U11 | 3.5吋屏幕 | — | 34 |
| U8 | AP3216C | AP3216C | 8 |
| U9 | AT24C02 | AT24C02 | 8 |
| C36 | Cap | 100nF | 2 |
| C37 | Cap | 1uF | 2 |
| C38 | Cap | 100nF | 2 |
| C39 | Cap | 2.2uF | 2 |
| C41 | Cap | 100nF | 2 |
| C42 | Cap | 22uF | 2 |
| C91 | Cap | 100nF | 2 |
| C94 | Cap | 100nF | 2 |
| C95 | Cap | 4.7uF | 2 |
| U10 | GD25Q128ES2 | GD25Q128ES2 | 8 |
| JP1 | Header 2*29_2.54 | Header 2*29_2.54 | 116 |
| JP2 | Header 2*29_2.54 | Header 2*29_2.54 | 116 |
| U6 | IS62WV51216BLL-55TLI | IS62WV51216BLL | 44 |
| R30 | Res | 100R | 2 |
| R31 | Res | 4.7k | 2 |
| R32 | Res | 4.7k | 2 |
| R33 | Res | 100R | 2 |
| R34 | Res | 1k | 2 |
| R39 | Res | 10k | 2 |
| R40 | Res | 10k | 2 |
| R41 | Res | 4.7k | 2 |
| R42 | Res | 10k | 2 |
| R98 | Res | 10k | 2 |

**本页出现的网络名（177 个）**

`3V3`, `ALS+PS+IRLED`, `BOOT0`, `EEPROM`, `EXMC_A0`, `EXMC_A1`, `EXMC_A10`, `EXMC_A11`, `EXMC_A12`, `EXMC_A13`, `EXMC_A14`, `EXMC_A15`, `EXMC_A16`, `EXMC_A17`, `EXMC_A18`, `EXMC_A2`, `EXMC_A3`, `EXMC_A4`, `EXMC_A5`, `EXMC_A6`, `EXMC_A7`, `EXMC_A8`, `EXMC_A9`, `EXMC_D0`, `EXMC_D1`, `EXMC_D10`, `EXMC_D11`, `EXMC_D12`, `EXMC_D13`, `EXMC_D14`, `EXMC_D15`, `EXMC_D2`, `EXMC_D3`, `EXMC_D4`, `EXMC_D5`, `EXMC_D6`, `EXMC_D7`, `EXMC_D8`, `EXMC_D9`, `EXMC_NBL0`, `EXMC_NBL1`, `EXMC_NE1`, `EXMC_NE3`, `EXMC_NOE`, `EXMC_NWE`, `EXMC_RS`, `GND`, `I2C0_SCL`, `I2C0_SDA`, `I2C1_SCL`, `I2C1_SDA`, `IRLED_INT`, `LCD`, `LCD_BL`, `NOR FLASH`, `NRST`, `PA0`, `PA1`, `PA10`, `PA11`, `PA12`, `PA13`, `PA14`, `PA15`, `PA2`, `PA3`, `PA4`, `PA5`, `PA6`, `PA7`, `PA8`, `PA9`, `PB0`, `PB1`, `PB10`, `PB11`, `PB12`, `PB13`, `PB14`, `PB15`, `PB2`, `PB3`, `PB4`, `PB5`, `PB6`, `PB7`, `PB8`, `PB9`, `PC0`, `PC1`, `PC10`, `PC11`, `PC12`, `PC13`, `PC2`, `PC3`, `PC4`, `PC5`, `PC6`, `PC7`, `PC8`, `PC9`, `PD0`, `PD1`, `PD10`, `PD11`, `PD12`, `PD13`, `PD14`, `PD15`, `PD2`, `PD3`, `PD4`, `PD5`, `PD6`, `PD7`, `PD8`, `PD9`, `PE0`, `PE1`, `PE10`, `PE11`, `PE12`, `PE13`, `PE14`, `PE15`, `PE2`, `PE3`, `PE4`, `PE5`, `PE6`, `PE7`, `PE8`, `PE9`, `PF0`, `PF1`, `PF10`, `PF11`, `PF12`, `PF13`, `PF14`, `PF15`, `PF2`, `PF3`, `PF4`, `PF5`, `PF6`, `PF7`, `PF8`, `PF9`, `PG0`, `PG1`, `PG10`, `PG11`, `PG12`, `PG13`, `PG14`, `PG15`, `PG2`, `PG3`, `PG4`, `PG5`, `PG6`, `PG7`, `PG8`, `PG9`, `SPI0_CLK`, `SPI0_MISO`, `SPI0_MOSI`, `SPIFlash_CS`, `SRAM`, `TP_INT`, `TP_RST`, `TP_SCL`, `TP_SDA`, `VBAT`, `引出IO`

### 5.5 485-232-CAN-TF（第1页）

*工业通信与存储卡（RS485 + RS232 + CAN + TF 卡座）*

- **RS485**：U5 SSP485 收发器，半双工，方向控制 RS485_RE/DE；总线端 R23 120R 终端电阻、R25/R27 20k 偏置、D11-D13 SMBJ6.5CA TVS + F2/F3 保险丝保护；信号 485_RX/485_TX，电源 485_3V3
- **RS232**：U7 MAX3232CSE+ 电平转换（3V3），配 C28-C35 100nF 电荷泵电容，接 J14 DB9 座
- **CAN**：U4 SN65HVD230 3.3V CAN 收发器，CAN_RX/CAN_TX 接 MCU PA11/PA12，CANH/CANL 引出 2pin 端子
- **TF 卡**：P1 TF/SD 卡座，走 SDIO：SDIO_CMD/CLK/DAT0-DAT3/CD，R24/R29/R76 100R 串阻，C40 100nF

**元件清单（共 37 项）**

| 位号 | 类型/型号 | 参数 | 引脚数 |
| --- | --- | --- | --- |
| J14 | CON_DB9 | CON_DB9 | 11 |
| C28 | Cap | 100nF | 2 |
| C29 | Cap | 100nF | 2 |
| C31 | Cap | 100nF | 2 |
| C32 | Cap | 100nF | 2 |
| C33 | Cap | 100nF | 2 |
| C34 | Cap | 100nF | 2 |
| C35 | Cap | 100nF | 2 |
| C40 | Cap | 100nF | 2 |
| D11 | Diode-Bi-TVS | SMBJ6.5CA | 2 |
| D12 | Diode-Bi-TVS | SMBJ6.5CA | 2 |
| D13 | Diode-Bi-TVS | SMBJ6.5CA | 2 |
| F2 | Fuse | SMD0805B005TF | 2 |
| F3 | Fuse | SMD0805B005TF | 2 |
| J6 | Header 1*2_5.08 | — | 2 |
| J7 | Header 1*2_5.08 | — | 2 |
| J13 | Header 1*3-JUMP | — | 3 |
| J15 | Header 1*3-JUMP | — | 3 |
| J16 | Header 1*3-JUMP | — | 3 |
| J17 | Header 1*3-JUMP | — | 3 |
| P1 | Header-SD/SDHC | Header-SD/SDHC | 13 |
| U7 | MAX3232CSE+ | MAX3232CSE+ | 16 |
| R22 | Res | 0R | 2 |
| R23 | Res | 120R | 2 |
| R24 | Res | 100R | 2 |
| R25 | Res | 20k | 2 |
| R27 | Res | 20k | 2 |
| R29 | Res | 100R | 2 |
| R35 | Res | 10k | 2 |
| R36 | Res | 10k | 2 |
| R37 | Res | 10k | 2 |
| R38 | Res | 10k | 2 |
| R48 | Res | 10k | 2 |
| R6 | Res | 10k | 2 |
| R76 | Res | 100R | 2 |
| U4 | SN65HVD230 | SN65HVD230 | 8 |
| U5 | SSP485 | SSP485 | 8 |

**本页出现的网络名（46 个）**

`232`, `232_3V3`, `232_RX`, `232_TX`, `3V3`, `485`, `485_3V3`, `485_RX`, `485_TX`, `CAN`, `CANH`, `CANL`, `CAN_3V3`, `CAN_RX`, `CAN_TX`, `GND`, `PA11`, `PA12`, `PA2`, `PA3`, `PC10`, `PC11`, `PC12`, `PC5`, `PC8`, `PC9`, `PD2`, `PD3`, `RS232_RX1`, `RS232_TX1`, `RS485A`, `RS485B`, `RS485_RE/DE`, `SDIO_CD`, `SDIO_CLK`, `SDIO_CMD`, `SDIO_DAT0`, `SDIO_DAT1`, `SDIO_DAT2`, `SDIO_DAT3`, `TF`, `USART1_RX`, `USART1_TX`, `USB_DM`, `USB_DP`, `公头`

### 5.6 Audio（第2页）

*音频（VS1053 解码 + MIC 输入 + FM8002A 功放 + LDO）*

- **音频解码**：U15 VS1053（MP3/WAV/Ogg 解码芯片），Y3 12.288MHz 音频专用晶振，SPI 控制（VS_SCK/MISO/MOSI/XCS/XDCS/RST），数据请求 VS_DREQ，I2S2_WS 接 PA4
- **麦克风输入**：MIC 驻极体 + 偏置电路 + 隔直电容，经 RC 滤波送入 VS1053 的 MIC 输入（可录音/编码）；J28/J29 为麦克风/耳机插座
- **功放**：U17 FM8002A 音频功放（3W），驱动喇叭；SPK/SPK_CTRL 由 MCU 控制
- **电源**：U16 XC6206P182MR LDO（1.8V）为 VS1053 内核供电，配 3 个 INDUCTOR 滤波

**元件清单（共 62 项）**

| 位号 | 类型/型号 | 参数 | 引脚数 |
| --- | --- | --- | --- |
| C54 | Cap | 100nF | 2 |
| C55 | Cap | 100nF | 2 |
| C56 | Cap | 100nF | 2 |
| C57 | Cap | 22pF | 2 |
| C58 | Cap | 100nF | 2 |
| C59 | Cap | 100nF | 2 |
| C60 | Cap | 100nF | 2 |
| C61 | Cap | 100nF | 2 |
| C62 | Cap | 22pF | 2 |
| C63 | Cap | 100nF | 2 |
| C64 | Cap | 100nF | 2 |
| C65 | Cap | 100nF | 2 |
| C66 | Cap | 100nF | 2 |
| C67 | Cap | 10uF | 2 |
| C68 | Cap | 10uF | 2 |
| C69 | Cap | 1uF | 2 |
| C70 | Cap | 1uF | 2 |
| C75 | Cap | 100nF | 2 |
| C76 | Cap | 1uF | 2 |
| C77 | Cap | 100pF | 2 |
| C78 | Cap | 1uF | 2 |
| C79 | Cap | 1uF | 2 |
| C80 | Cap | 100nF | 2 |
| C81 | Cap | 10uF | 2 |
| C82 | Cap | 1uF | 2 |
| C83 | Cap | 1uF | 2 |
| C84 | Cap | 10nF | 2 |
| C85 | Cap | 10nF | 2 |
| C86 | Cap | 1uF | 2 |
| C87 | Cap | 220nF | 2 |
| C88 | Cap | 220nF | 2 |
| C89 | Cap | 10nF | 2 |
| C90 | Cap | 10nF | 2 |
| U17 | FM8002A | FM8002A | 8 |
| J22 | Header 1*2-JUMP | — | 2 |
| J5 | Header 1*2_2.54 | — | 2 |
| FB3 | INDUCTOR | 600R±25% 100MHz | 2 |
| FB4 | INDUCTOR | 600R±25% 100MHz | 2 |
| FB5 | INDUCTOR | 600R±25% 100MHz | 2 |
| P2 | MIC | MIC | 2 |
| J28 | MIC_JACK | MIC_JACK | 5 |
| J29 | MIC_JACK | MIC_JACK | 5 |
| R28 | Res | 1M | 2 |
| R49 | Res | 10k | 2 |
| R50 | Res | 1k | 2 |
| R72 | Res | 100k | 2 |
| R74 | Res | 1k | 2 |
| R78 | Res | 1k | 2 |
| R80 | Res | 1k | 2 |
| R81 | Res | 1k | 2 |
| R82 | Res | 1k | 2 |
| R83 | Res | 100k | 2 |
| R84 | Res | 22k | 2 |
| R85 | Res | 68k | 2 |
| R86 | Res | 10k | 2 |
| R87 | Res | 470R | 2 |
| R88 | Res | 470R | 2 |
| R89 | Res | 20R | 2 |
| R90 | Res | 20R | 2 |
| U15 | VS1053 | VS1053 | 48 |
| U16 | XC6206P182MR | XC6206P182MR | 3 |
| Y3 | XTAL-4 | 12.288MHz | 4 |

**本页出现的网络名（33 个）**

`+5V`, `3V3`, `AUDIO`, `AVDD`, `CVDD`, `FM_5V`, `GND`, `IO_VDD`, `LINE2`, `MICN`, `MICP/LINE1`, `MP3_LEFT`, `MP3_RIGHT`, `PA5`, `PA6`, `PA7`, `PC13`, `PE3`, `PE4`, `PE5`, `PG8`, `SPK_CTRL`, `SPK_N`, `SPK_P`, `VS_DREQ`, `VS_MISO`, `VS_MOSI`, `VS_RST`, `VS_SCK`, `VS_XCS`, `VS_XDCS`, `粉色麦克`, `绿色耳机`

## 6. 跨页网络（同一网络名跨多页 → 电气相连）

| 网络名 | 类型 | 出现的页面 |
| --- | --- | --- |
| +5V | Text | Audio, Power-WIFI, Sensors-LED-KEY-USB_ |
| 3V3 | Text | 485-232-CAN-TF, Audio, LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU, Power-WIFI, Sensors-LED-KEY-USB_ |
| ADC_RH | Text | MCU, Sensors-LED-KEY-USB_ |
| ADC_TEMP | Text | MCU, Sensors-LED-KEY-USB_ |
| ADJ_RES | Text | MCU, Sensors-LED-KEY-USB_ |
| BOOT0 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU, Sensors-LED-KEY-USB_ |
| CAN_RX | Label | 485-232-CAN-TF, MCU |
| CAN_TX | Label | 485-232-CAN-TF, MCU |
| EXMC_A0 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| EXMC_A1 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| EXMC_A10 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| EXMC_A11 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| EXMC_A12 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| EXMC_A13 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| EXMC_A14 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| EXMC_A15 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| EXMC_A16 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| EXMC_A17 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| EXMC_A18 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| EXMC_A2 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| EXMC_A3 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| EXMC_A4 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| EXMC_A5 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| EXMC_A6 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| EXMC_A7 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| EXMC_A8 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| EXMC_A9 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| EXMC_D0 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| EXMC_D1 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| EXMC_D10 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| EXMC_D11 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| EXMC_D12 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| EXMC_D13 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| EXMC_D14 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| EXMC_D15 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| EXMC_D2 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| EXMC_D3 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| EXMC_D4 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| EXMC_D5 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| EXMC_D6 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| EXMC_D7 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| EXMC_D8 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| EXMC_D9 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| EXMC_NBL0 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| EXMC_NBL1 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| EXMC_NE1 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| EXMC_NE3 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| EXMC_NOE | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| EXMC_NWE | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| EXMC_RS | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| GND | Text | 485-232-CAN-TF, Audio, LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU, Power-WIFI, Sensors-LED-KEY-USB_ |
| I2C0_SCL | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| I2C0_SDA | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| IF_OUT | Text | MCU, Sensors-LED-KEY-USB_ |
| IRLED_INT | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| KEY1 | Text | MCU, Sensors-LED-KEY-USB_ |
| KEY2 | Text | MCU, Sensors-LED-KEY-USB_ |
| KEY3 | Text | MCU, Sensors-LED-KEY-USB_ |
| KEY4 | Text | MCU, Sensors-LED-KEY-USB_ |
| LCD_BL | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| LED1 | Text | MCU, Sensors-LED-KEY-USB_ |
| LED2 | Text | MCU, Sensors-LED-KEY-USB_ |
| LED3 | Text | MCU, Sensors-LED-KEY-USB_ |
| NRST | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU, Sensors-LED-KEY-USB_ |
| PA0 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU, Sensors-LED-KEY-USB_ |
| PA1 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PA10 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PA11 | Text | 485-232-CAN-TF, LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PA12 | Text | 485-232-CAN-TF, LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PA13 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PA14 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PA15 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PA2 | Text | 485-232-CAN-TF, LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PA3 | Text | 485-232-CAN-TF, LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PA4 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PA5 | Text | Audio, LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PA6 | Text | Audio, LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PA7 | Text | Audio, LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PA8 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU, Sensors-LED-KEY-USB_ |
| PA9 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PB0 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU, Sensors-LED-KEY-USB_ |
| PB1 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU, Sensors-LED-KEY-USB_ |
| PB10 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU, Power-WIFI |
| PB11 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU, Power-WIFI |
| PB12 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PB13 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PB14 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PB15 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PB2 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PB3 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PB4 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PB5 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PB6 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PB7 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PB8 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU, Sensors-LED-KEY-USB_ |
| PB9 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PC0 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PC1 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PC10 | Text | 485-232-CAN-TF, LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PC11 | Text | 485-232-CAN-TF, LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PC12 | Text | 485-232-CAN-TF, LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PC13 | Text | Audio, LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PC2 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU, Sensors-LED-KEY-USB_ |
| PC3 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU, Sensors-LED-KEY-USB_ |
| PC4 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU, Sensors-LED-KEY-USB_ |
| PC5 | Text | 485-232-CAN-TF, LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PC6 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU, Sensors-LED-KEY-USB_ |
| PC7 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PC8 | Text | 485-232-CAN-TF, LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PC9 | Text | 485-232-CAN-TF, LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PD0 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PD1 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PD10 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PD11 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PD12 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PD13 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PD14 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PD15 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PD2 | Text | 485-232-CAN-TF, LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PD3 | Text | 485-232-CAN-TF, LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PD4 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PD5 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PD6 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PD7 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PD8 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PD9 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PE0 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PE1 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PE10 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PE11 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PE12 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PE13 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PE14 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PE15 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PE2 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PE3 | Text | Audio, LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PE4 | Text | Audio, LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PE5 | Text | Audio, LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PE6 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU, Sensors-LED-KEY-USB_ |
| PE7 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PE8 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PE9 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PF0 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PF1 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PF10 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PF11 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PF12 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PF13 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PF14 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PF15 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PF2 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PF3 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PF4 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PF5 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PF6 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU, Sensors-LED-KEY-USB_ |
| PF7 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PF8 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PF9 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PG0 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PG1 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PG10 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PG11 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PG12 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PG13 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU, Sensors-LED-KEY-USB_ |
| PG14 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU, Sensors-LED-KEY-USB_ |
| PG15 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU, Sensors-LED-KEY-USB_ |
| PG2 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PG3 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PG4 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PG5 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PG6 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PG7 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU, Power-WIFI |
| PG8 | Text | Audio, LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| PG9 | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| RS485_RE/DE | Text | 485-232-CAN-TF, MCU |
| SDIO_CD | Text | 485-232-CAN-TF, MCU |
| SDIO_CLK | Text | 485-232-CAN-TF, MCU |
| SDIO_CMD | Text | 485-232-CAN-TF, MCU |
| SDIO_DAT0 | Text | 485-232-CAN-TF, MCU |
| SDIO_DAT1 | Text | 485-232-CAN-TF, MCU |
| SDIO_DAT2 | Text | 485-232-CAN-TF, MCU |
| SDIO_DAT3 | Text | 485-232-CAN-TF, MCU |
| SPI0_CLK | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| SPI0_MISO | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| SPI0_MOSI | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| SPIFlash_CS | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| SPK | Text | MCU, Sensors-LED-KEY-USB_ |
| SPK_CTRL | Text | Audio, MCU |
| TIMER2_CH2 | Text | MCU, Sensors-LED-KEY-USB_ |
| TIMER2_CH3 | Text | MCU, Sensors-LED-KEY-USB_ |
| TP_INT | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| TP_RST | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| TP_SCL | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| TP_SDA | Text | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| USART0_RX | Text | MCU, Sensors-LED-KEY-USB_ |
| USART0_TX | Text | MCU, Sensors-LED-KEY-USB_ |
| USART1_RX | Text | 485-232-CAN-TF, MCU |
| USART1_TX | Text | 485-232-CAN-TF, MCU |
| USART2_RXD | Text | MCU, Power-WIFI |
| USART2_TXD | Text | MCU, Power-WIFI |
| USB_DM | Text | 485-232-CAN-TF, MCU, Power-WIFI |
| USB_DP | Text | 485-232-CAN-TF, MCU, Power-WIFI |
| VBAT | Label | LCD-EEPROM-IRLED-FLASH-EXTENSION, MCU |
| VS_DREQ | Text | Audio, MCU |
| VS_MISO | Text | Audio, MCU |
| VS_MOSI | Text | Audio, MCU |
| VS_RST | Text | Audio, MCU |
| VS_SCK | Text | Audio, MCU |
| VS_XCS | Text | Audio, MCU |
| VS_XDCS | Text | Audio, MCU |
| WiFi_EN | Text | MCU, Power-WIFI |

## 7. 关键器件（BOM 摘要）

| 位号 | 型号 | 作用 |
| --- | --- | --- |
| U1 | GD32F303ZET6 | 主控 MCU，LQFP144 |
| U3 | APW7104 | 5V→3V3 DC-DC 降压 |
| U14 | ESP8684-MINI-1 | WiFi 模组（ESP32-C2，AT 固件） |
| U6 | IS62WV51216BLL | 512K×16 SRAM（1MB），EXMC 总线 |
| U10 | GD25Q32ESIG | 4MB SPI NOR Flash |
| U9 | AT24C02 | 2Kbit I2C EEPROM |
| U8 | AP3216C | 环境光 + 接近传感器（I2C） |
| U11 | 3.5 寸 TFT | LCD 屏接口（34pin，EXMC + I2C 触摸） |
| U13 | CH340C | USB 转串口（含一键下载电路） |
| U12 | IRM-1838 | 红外接收头 |
| U5 | SSP485 | RS485 收发器 |
| U7 | MAX3232CSE+ | RS232 电平转换 |
| U4 | SN65HVD230 | CAN 收发器（3.3V） |
| U-VS | VS1053 (U15) | 音频解码芯片 |
| U-AMP | FM8002A (U17) | 音频功放 3W |
| U-LDO | XC6206P182MR (U16) | 1.8V LDO（VS1053 内核） |
| Y1 / Y2 / Y3 | 32.768kHz / 8MHz / 12.288MHz | RTC 晶振 / 主晶振 / 音频晶振 |
| J1 / J10 | USB Type-C | 供电 + 调试串口 |
| J14 | DB9 | RS232 接口 |
| P1 | TF/SD 卡座 | SDIO 存储卡 |
| J33 / JP1A/B, JP2A/B | 排针 | 电源引出 / IO 全引出 |

## 8. 解析说明与已知局限

- 数据来源为 Altium 二进制原理图源文件（OLE 复合文档中的 `FileHeader` 记录流），元件位号、型号、参数、引脚号、引脚名、网络标注均为原始数据。
- 引脚「功能网络」是把引脚坐标与原理图上的文字标注（Text / NetLabel / PowerPort）按行对齐自动匹配得到，准确率高但**个别引脚可能因图上无标注而留空或匹配到相邻标注**。用于写代码时，建议以「引脚名（PAx/PBx）+ 外设分组」为准。
- 标注了引脚号却无网络的引脚，表示原理图上该引脚未连接或未标注。
- 跨页连接以「网络名相同即相连」判定（Altium 扁平化设计规则）。

*生成时间：2026-10-12 | 原始 PDF：`GD32F303ZE-麒麟ARM.pdf`（6 页）*