# 08 · 无线调试通道 + Debug 单步调试

> 对应课程：08-蓝牙模块+Debug调试
> 前置要求：第 07 章（串口）
> 建议耗时：3-5 天

---

## 本章实板资源

| 资源 | 说明 |
|---|---|
| USART0 | PA9/PA10 → CH340C → USB（有线调试通道，已通） |
| USART1 | PA2/PA3 排针（接外置 USB-TTL，可模拟"无线通道"的有线侧） |
| HC-05 蓝牙模块 | **无板载，需外接**：HC-05 TX→PA3(RX)、HC-05 RX→PA2(TX)、共地、VCC=5V/3V3 按模块 |
| ESP8684 WiFi | 板载 USART2（第 15 章细讲，也可当"无线调试通道"的高配替代） |
| 调试器 | ST-Link + OpenOCD + cortex-debug（F5） |

> F103 时代配蓝牙模块做无线打印；本板没有板载蓝牙，
> 方案：① 外接 HC-05 到 USART1；② 直接用板载 ESP8684 WiFi（推荐，第 15 章）；③ 只用 CH340C 有线。
> 本章重点是 **Debug 单步调试**——这是比"无线"更有价值的技能。

---

## 一、学习内容

### 1. 蓝牙串口模块概念（HC-05）

- 透明传输：从机模式，配对后当"无线串口线"用
- AT 命令配置波特率/名称/配对码（`AT`、`AT+NAME=`、`AT+UART=115200,1,0`）
- 接法：模块 TX → MCU RX、模块 RX → MCU TX、**共地**、VCC（HC-05 多数 5V 或 3V3V）
- 手机蓝牙串口 APP 即可当上位机

### 2. Debug 调试（本章重点）

| 技能 | 操作 |
|---|---|
| 断点 | 行号左侧点红点；条件断点（右键） |
| 单步 | F10（step over）/ F11（step into）/ Shift+F11（step out） |
| 寄存器视图 | `View → Registers`（R0-R15/xPSR） |
| **外设寄存器视图** | `Peripherals → GPIOA / RCU / TIMER2...`（SVD 驱动，本板已配） |
| 监视 | `gpio_input_bit_get(GPIOA, GPIO_PIN_0)` 等表达式；**宏不行**（GDB 不认宏，用 `*(unsigned int *)0x40010808` 代替） |
| 内存 | `View → Memory` 看 `0x20000000` 起的 SRAM |
| 调用栈 | 卡死时看 Call Stack 找死循环位置 |
| 实时表达式 | `Watch` 里加变量，运行时刷新 |

### 3. 调试排错三件套

1. **断点定位**：在可疑函数第一行打断点，看进不进得去
2. **单步+寄存器**：看寄存器的位怎么变（第 01 章练过）
3. **二分区**：注释掉一半代码，看现象还在不在

### 4. 变量/表达式不被优化

- 调试构建（`-O0`，母本默认 `level-debug`）变量都可见
- `-O2` 下变量可能被优化掉：看 `.map` 或把它声明 `volatile`
- GDB 不认**宏**：`RCU->CTL`、`GPIOA` 都不行 → 用裸地址 `*(unsigned int *)0x40021000`

---

## 二、学习目标

- [ ] 能熟练用断点/单步/监视/外设视图四种手段定位一个 bug
- [ ] 能说出"GDB 不认宏"及绕开方法
- [ ] 能接好 HC-05 并跑通无线打印（或说明为何用 WiFi 替代）
- [ ] 能用条件断点抓"变量 == 某值"的瞬间
- [ ] 能用调用栈分析一次 HardFault

---

## 三、学习方法

1. **故意造 bug 再抓**：数组越界写坏一个变量，用 Watch + 断点抓现场。
2. **条件断点实验**：`g_tick_ms == 5000` 条件断点，体会不用死等。
3. **HardFault 演练**：写一个空指针解引用，进 HardFault_Handler，看调用栈和 LR。
4. **外设视图对账**：改 GPIO 后看 `Peripherals → GPIOA` 的 CTL0/OCTL 变化。
5. **无线通道**：HC-05 配对后，把第 07 章的 printf 例程原样跑，手机 APP 收。

---

## 四、标准示例

### 1. 触发一次 HardFault 并抓现场

```c
void (*bad_func)(void) = (void (*)(void))0x00000001U;   /* 非法地址 */

int main(void)
{
    systick_config();
    usart0_init();
    printf("before fault\r\n");
    bad_func();                    /* 执行后 PC 跑飞 → HardFault */
    printf("never here\r\n");
    while (1) { }
}
```

HardFault 时看：

- `Call Stack`：确认是从 `main` 调下来的
- `LR (EXC_RETURN)`：`0xFFFFFFF9` = 返回线程模式用 MSP
- 状态寄存器：`CFSR`（0xE000ED28）定位具体错误（`IBUSERR`/`UNDEFINSTR`/...）

### 2. 抓现场的状态寄存器

```c
void HardFault_Handler(void)
{
    /* 现场快照——调试器停下时这些值就是案发现场 */
    volatile uint32_t hfsr  = *(volatile uint32_t *)0xE000ED2CU;  /* HardFault Status */
    volatile uint32_t cfsr  = *(volatile uint32_t *)0xE000ED28U;  /* Configurable Fault Status */
    volatile uint32_t mmfar = *(volatile uint32_t *)0xE000ED34U;  /* MemManage 出错地址 */
    volatile uint32_t bfar  = *(volatile uint32_t *)0xE000ED38U;  /* BusFault 出错地址 */
    (void)hfsr; (void)cfsr; (void)mmfar; (void)bfar;
    while (1) { }
}
```

### 3. 条件断点（不用改代码抓瞬间）

```
Watch 表达式：g_tick_ms == 5000
条件断点：    g_rx_len == 3
```

### 4. HC-05 无线打印（外接 USART1）

```c
/* 复用第 07 章 usart0 例程，把 USART0 全换成 USART1、PA9→PA2、PA10→PA3 即可 */
usart_baudrate_set(USART1, 115200U);
gpio_init(GPIOA, GPIO_MODE_AF_PP, GPIO_OSPEED_50MHZ, GPIO_PIN_2);
gpio_init(GPIOA, GPIO_MODE_IPU,  GPIO_OSPEED_2MHZ,  GPIO_PIN_3);
/* HC-05：模块 TX→PA3，模块 RX→PA2，GND 共地，VCC 按模块要求 */
```

---

## 五、自我检测

1. F10 和 F11 的区别是什么？各用在什么场景？
2. 为什么 Watch 里写 `RCU->CTL` 会报 `unable to create variable object`？正确的两种写法是什么？
3. HardFault 的 `CFSR` 在哪个地址？`UNDEFINSTR` 位是第几位？
4. `LR = 0xFFFFFFF9` 说明什么？`0xFFFFFFFD` 呢？
5. 条件断点和 `if (x == 5) __BKPT()` 各有什么优劣？
6. HC-05 的 TX/RX 怎么接 MCU？共地为什么必须？
7. 调试构建（-O0）和发布构建（-O2）下 Watch 变量表现差异的原因是什么？
8. 板载 ESP8684 能不能当"无线调试通道"？它和蓝牙比优劣是什么？

---

## 六、常见坑

| 现象 | 原因 |
|---|---|
| 按 F5 弹「选择调试器」 | 别按 F5；用工程 `.vscode/launch.json`（已配好 cortex-debug + OpenOCD） |
| 外设寄存器窗口空白 | SVD 没加载：检查 `launch.json` 的 `svdFile` 路径（`.pack/.../GD32F30x_HD.svd`） |
| Watch 变量显示 `<optimized out>` | 构建优化等级太高；用 Debug 构建或加 `volatile` |
| Watch 宏报 `unable to create variable object` | GDB 不认宏；用 `*(unsigned int *)0x...` 裸地址 |
| 「Open Disassembly View」报 `reading 'fsPath'` | EIDE 插件 bug；绕开：`startup_gd32f30x_hd.s` 本身就是汇编，在编辑器里单步 |
| 断点打不上/程序不停 | 优化代码重排；用 Debug 构建 |
| HC-05 连上但没数据 | TX/RX 没交叉；或没共地；或波特率不一致 |
| 单步时串口丢数据 | 单步停留期间 PC 端缓冲区溢出/看门狗（若开了 FWDGT）超时复位 |
| 下载后行为与源码不一致 | 看是不是烧到了旧 hex；`Ctrl+Shift+B → rebuild` 再来 |

---

## 七、拓展练习

1. 抓一次数组越界：写 `buf[8]` 越界写，用 Watch + Memory 窗口定位被踩的变量。
2. 用条件断点抓 `g_tick_ms` 从 4999 变 5000 的瞬间，不停机连续跑。
3. 完整分析一次 HardFault：读 CFSR/HFSR，判断是 `UNDEFINSTR` 还是 `PRECISERR`。
4. 外接 HC-05，跑通无线 printf；记录配对过程和 AT 配置。
5. 对比调试：把同一个 bug 分别用"printf 打点"和"断点单步"定位，记录各自耗时，体会适用场景。
6. 用 Memory 窗口观察 `.bss` 清零：在 `main` 第一行看 `0x20000000` 区域是否全 0。

---

## 八、本章速查卡模板（学完抄一页纸）

```
【第08章 调试速查】
快捷键：F10 单步跳过 / F11 进入 / Shift+F11 跳出 / F5 继续
窗口  ：Registers / Peripherals(SVD) / Watch / Call Stack / Memory
GDB 坑：不认宏 → *(unsigned int *)0x40021000；optimized out → volatile/降优化
HardFault：HFSR=0xE000ED2C CFSR=0xE000ED28 MMFAR=0xE000ED34 BFAR=0xE000ED38
LR    ：FFFFFFF9=MSP线程 / FFFFFFFD=PSP线程
F5 别按：用 launch.json（cortex-debug+OpenOCD）
蓝牙  ：HC-05 TX→MCU RX、RX→MCU TX、共地；AT 配 115200
```
