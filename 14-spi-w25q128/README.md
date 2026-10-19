# 14 · SPI + 板载 NOR Flash

> 对应课程：14-硬件IIC+SPI+W25Q128
> 前置要求：第 12 章（I2C 已会，便于对比）、第 07 章（串口）
> 建议耗时：5-7 天

---

## 本章实板资源

| 资源 | 引脚 | 说明 |
|---|---|---|
| SPI0 | PB13=SCK、PB14=MISO、PB15=MOSI | **硬件 SPI0**，主模式 |
| GD25Q32 NOR Flash | CS = **PE2**（软件控制） | 板载，**4MB（32Mbit）**，W25Q 系列兼容 |
| RC522 RFID | 无板载，外接 | 注意 SPI0 已被 Flash 占用，RFID 用空闲 SPI 排针 |

> F103 学习时 W25Q128 是外接模块；本板 **GD25Q32 直接板载**——
> 命令完全兼容 W25Qxx 系列（JEDEC ID 读出来是 `C8 40 16`：厂商 C8=兆易，40 16=32Mbit）。

---

## 一、学习内容

### 1. SPI 总线（与 I2C 对比）

| 维度 | I2C | SPI |
|---|---|---|
| 线数 | 2（SCL/SDA，半双工） | 4（SCK/MOSI/MISO/CS，全双工） |
| 寻址 | 器件地址 | 片选（CS） |
| 时钟 | 主机产生 | 主机产生 |
| 速率 | 100k/400k | 几十 MHz |
| 从机数 | 靠地址 | 靠 CS 线，每从机一根 |

### 2. SPI0 配置链

```c
rcu_periph_clock_enable(RCU_GPIOB);     /* SCK/MOSI/MISO */
rcu_periph_clock_enable(RCU_GPIOE);     /* CS=PE2 当普通 GPIO 软件控制 */
rcu_periph_clock_enable(RCU_SPI0);

gpio_init(GPIOB, GPIO_MODE_AF_PP, GPIO_OSPEED_50MHZ,
          GPIO_PIN_13 | GPIO_PIN_15);   /* SCK + MOSI 复用推挽 */
gpio_init(GPIOB, GPIO_MODE_IN_FLOATING, GPIO_OSPEED_2MHZ,
          GPIO_PIN_14);                 /* MISO 浮空输入 */
gpio_init(GPIOE, GPIO_MODE_OUT_PP, GPIO_OSPEED_50MHZ,
          GPIO_PIN_2);                  /* CS 软件控制 */

spi_parameter_struct spi_init_struct;
spi_struct_para_init(&spi_init_struct);
spi_init_struct.device_mode          = SPI_MASTER;
spi_init_struct.trans_mode           = SPI_TRANSMODE_FULLDUPLEX;   /* 全双工 */
spi_init_struct.frame_size           = SPI_FRAMESIZE_8BIT;
spi_init_struct.nss                  = SPI_NSS_SOFT;     /* CS 软件控制 */
spi_init_struct.endian               = SPI_ENDIAN_MSB;   /* MSB 先发 */
spi_init_struct.clock_polarity_phase = SPI_CK_PL_LOW_PH_1EDGE;  /* mode 0 */
spi_init_struct.prescale             = SPI_PSC_?;        /* SCK = 120M/分频 */
spi_init(SPI0, &spi_init_struct);
spi_enable(SPI0);
```

> `trans_mode` 用 `SPI_TRANSMODE_FULLDUPLEX`（全双工）。
> GD25Qxx 用**全双工**（发命令同时收数据）。

### 3. W25Q 系列命令（GD25Q32 同）

| 命令 | 字节 | 说明 |
|---|---|---|
| `WREN` | 0x06 | 写使能（**每次写/擦前必发**） |
| `RDSR` | 0x05 | 读状态寄存器，bit0=**WIP**（忙） |
| `RDJDID`/`JEDEC ID` | 0x9F | 读厂商+器件 ID（`C8 40 16`） |
| `READ` | 0x03 + 3 字节地址 | 读（无限制） |
| `PP` | 0x02 + 3 字节地址 | 页写，**256 字节/页，不跨页** |
| `SE` | 0x20 + 3 字节地址 | 扇区擦（**4KB**） |
| `CE` | 0xC7 / 0x60 | 全片擦 |
| `RSTEN`+`RST` | 0x66 + 0x99 | 软复位 |

### 4. CS 时序（软件控制）

```
CS 拉低 → 发命令/地址/数据（发 N 字节收 M 字节）→ CS 拉高
写操作前必须 WREN；写完必须查 WIP 清
```

### 5. 读写原语

```c
uint8_t spi0_rw_byte(uint8_t data)
{
    while (spi_i2s_flag_get(SPI0, SPI_FLAG_TBE) == RESET) { }
    spi_i2s_data_transmit(SPI0, (uint16_t)data);
    while (spi_i2s_flag_get(SPI0, SPI_FLAG_RBNE) == RESET) { }
    return (uint8_t)spi_i2s_data_receive(SPI0);
}
```

---

## 二、学习目标

- [ ] 能配好 SPI0 主模式并用 `spi0_rw_byte` 与 Flash 通信
- [ ] 能读出 JEDEC ID 并识别出板载是 GD25Q32（4MB）
- [ ] 能实现"擦扇区 → 页写 → 读回校验"闭环
- [ ] 能解释 WIP 和页边界，写出跨页自动拆包的写函数
- [ ] 能说出 SPI 与 I2C 的三个以上差异

---

## 三、学习方法

1. **ID 对账**：先读 JEDEC ID，和原理图/手册对账——确认"连的就是板载那颗"。
2. **时序三连**：`WREN → PP → 查 WIP`，每步用串口打印状态位。
3. **页边界实验**：故意在页边界处跨页写，观察错位；再写自动拆包版。
4. **速率对比**：SPI 传 4KB vs I2C 传 4KB，各测耗时——体会总线代差。
5. **掉电验证**：写一批数据 → 断电 → 上电读回，验证 NOR 非易失。

---

## 四、标准示例

### 1. SPI0 初始化（主模式，CS 软件控制）

```c
#include "gd32f30x.h"

#define W25Q_CS_GPIO   GPIOE
#define W25Q_CS_PIN    GPIO_PIN_2

void spi0_init(void)
{
    rcu_periph_clock_enable(RCU_GPIOB);
    rcu_periph_clock_enable(RCU_GPIOE);
    rcu_periph_clock_enable(RCU_SPI0);

    gpio_init(GPIOB, GPIO_MODE_AF_PP, GPIO_OSPEED_50MHZ,
              GPIO_PIN_13 | GPIO_PIN_15);        /* SCK, MOSI */
    gpio_init(GPIOB, GPIO_MODE_IN_FLOATING, GPIO_OSPEED_2MHZ,
              GPIO_PIN_14);                      /* MISO */
    gpio_init(W25Q_CS_GPIO, GPIO_MODE_OUT_PP, GPIO_OSPEED_50MHZ,
              W25Q_CS_PIN);
    gpio_bit_set(W25Q_CS_GPIO, W25Q_CS_PIN);     /* CS 默认拉高 */

    spi_parameter_struct spi_init_struct;
    spi_struct_para_init(&spi_init_struct);
    spi_init_struct.device_mode          = SPI_MASTER;
    spi_init_struct.trans_mode           = SPI_TRANSMODE_FULLDUPLEX;
    spi_init_struct.frame_size           = SPI_FRAMESIZE_8BIT;
    spi_init_struct.nss                  = SPI_NSS_SOFT;
    spi_init_struct.endian               = SPI_ENDIAN_MSB;
    spi_init_struct.clock_polarity_phase = SPI_CK_PL_LOW_PH_1EDGE;
    spi_init_struct.prescale             = SPI_PSC_8;   /* 120M/8 = 15MHz */
    spi_init(SPI0, &spi_init_struct);
    spi_enable(SPI0);
}

uint8_t spi0_rw_byte(uint8_t data)
{
    while (spi_i2s_flag_get(SPI0, SPI_FLAG_TBE) == RESET) { }
    spi_i2s_data_transmit(SPI0, (uint16_t)data);
    while (spi_i2s_flag_get(SPI0, SPI_FLAG_RBNE) == RESET) { }
    return (uint8_t)spi_i2s_data_receive(SPI0);
}
```

### 2. 基础操作（ID / WREN / 查忙）

```c
void w25q_cs_low(void)  { gpio_bit_reset(W25Q_CS_GPIO, W25Q_CS_PIN); }
void w25q_cs_high(void) { gpio_bit_set(W25Q_CS_GPIO, W25Q_CS_PIN); }

void w25q_read_jedec_id(uint8_t *manu, uint8_t *type, uint8_t *cap)
{
    w25q_cs_low();
    spi0_rw_byte(0x9FU);
    *manu = spi0_rw_byte(0xFFU);     /* 发 dummy 同时收 */
    *type = spi0_rw_byte(0xFFU);
    *cap  = spi0_rw_byte(0xFFU);
    w25q_cs_high();
}
/* GD25Q32(板载)：manu=0xC8 type=0x40 cap=0x16 → 32Mbit = 4MB */

void w25q_write_enable(void)
{
    w25q_cs_low();
    spi0_rw_byte(0x06U);             /* WREN */
    w25q_cs_high();
}

uint8_t w25q_busy(void)
{
    uint8_t sr;
    w25q_cs_low();
    spi0_rw_byte(0x05U);             /* RDSR */
    sr = spi0_rw_byte(0xFFU);
    w25q_cs_high();
    return (sr & 0x01U);             /* WIP */
}
```

### 3. 擦扇区 + 页写 + 读（闭环）

```c
void w25q_read(uint32_t addr, uint8_t *buf, uint32_t len)
{
    w25q_cs_low();
    spi0_rw_byte(0x03U);                                  /* READ */
    spi0_rw_byte((uint8_t)(addr >> 16));
    spi0_rw_byte((uint8_t)(addr >> 8));
    spi0_rw_byte((uint8_t)(addr));
    for (uint32_t i = 0; i < len; i++) {
        buf[i] = spi0_rw_byte(0xFFU);
    }
    w25q_cs_high();
}

void w25q_sector_erase(uint32_t addr)                     /* 4KB */
{
    w25q_write_enable();
    w25q_cs_low();
    spi0_rw_byte(0x20U);                                  /* SE */
    spi0_rw_byte((uint8_t)(addr >> 16));
    spi0_rw_byte((uint8_t)(addr >> 8));
    spi0_rw_byte((uint8_t)(addr));
    w25q_cs_high();
    while (w25q_busy()) { }                               /* 等擦完 */
}

void w25q_page_program(uint32_t addr, const uint8_t *buf, uint16_t len)
{
    if (len > 256U) return;
    if ((addr & 0xFFU) + len > 256U) return;              /* 不跨页！ */

    w25q_write_enable();
    w25q_cs_low();
    spi0_rw_byte(0x02U);                                  /* PP */
    spi0_rw_byte((uint8_t)(addr >> 16));
    spi0_rw_byte((uint8_t)(addr >> 8));
    spi0_rw_byte((uint8_t)(addr));
    for (uint16_t i = 0; i < len; i++) {
        spi0_rw_byte(buf[i]);
    }
    w25q_cs_high();
    while (w25q_busy()) { }                               /* 等写完 */
}

int main(void)
{
    uint8_t  wr[256], rd[256], ok = 1U;
    uint8_t  manu, type, cap;

    systick_config();
    usart0_init();
    spi0_init();

    w25q_read_jedec_id(&manu, &type, &cap);
    printf("JEDEC: %02X %02X %02X\r\n", manu, type, cap);

    for (uint16_t i = 0; i < 256; i++) wr[i] = (uint8_t)i;
    w25q_sector_erase(0x001000U);
    w25q_page_program(0x001000U, wr, 256U);
    w25q_read(0x001000U, rd, 256U);
    for (uint16_t i = 0; i < 256; i++) {
        if (rd[i] != wr[i]) ok = 0U;
    }
    printf("flash verify %s\r\n", ok ? "OK" : "FAIL");
    while (1) { }
}
```

### 4. 跨页自动拆包（工程版）

```c
void w25q_write(uint32_t addr, const uint8_t *buf, uint32_t len)
{
    while (len > 0) {
        uint32_t page_left = 256U - (addr & 0xFFU);       /* 本页剩余 */
        uint32_t n = (len < page_left) ? len : page_left;
        w25q_page_program(addr, buf, (uint16_t)n);
        addr += n;
        buf  += n;
        len  -= n;
    }
}
```

---

## 五、自我检测

1. 画出 SPI0 四根线 + CS 的连接图（PB13/14/15 + PE2）。
2. JEDEC ID `C8 40 16` 说明这颗 Flash 是什么？（容量算出来）
3. 为什么写之前必须 `WREN`？不发的现象是什么？
4. 页写 256 字节，为什么不能跨页？跨了会怎样？
5. `SE` 擦的最小单位多大？擦 1 字节和擦 4KB 的时间为什么差不多？
6. `spi0_rw_byte` 为什么能同时收发？全双工的硬件基础是什么？
7. SPI 的 mode 0/3 由哪两个参数决定？GD25Q 默认是哪个？
8. SPI 和 I2C 各适合什么场景？本板哪些设备用了哪种？

---

## 六、常见坑

| 现象 | 原因 |
|---|---|
| ID 读出 00 00 00 或 FF FF FF | ① CS 没拉低/没拉高；② SPI 没使能；③ 时钟极性相位不对（mode 选错） |
| 写进去读出来还是 FF | ① 忘 `WREN`；② 没擦（NOR 只能 1→0）；③ CS 时序错 |
| 页写后首字节对后面全错 | 跨页写了（第 257 字节绕回页首） |
| 写完立刻读是旧值 | 没等 WIP 清 |
| 偶发丢一个字节 | CS 提前拉高（最后一字节 MISO 没吐完）；等 RBNE 再拉高 |
| SPI 时钟太快不稳定 | prescale 太小 + 线长；降到 SPI_PSC_16/32 试 |
| MISO 读回全 0 | MISO 引脚配错（要浮空输入，不是 AF_PP） |
| 把 GD25Q32 当 16MB 用 | 板载是 **4MB**，地址范围 0x000000~0x3FFFFF；越界读写会静默失败 |

---

## 七、拓展练习

1. 写 `w25q_chip_erase()` + 全片校验（读全片比对，统计 4MB 耗时）。
2. 简易文件系统：扇区头 16 字节存"魔数+版本+长度"，后面存数据；上电自动识别。
3. 日志系统：系统事件（时间戳+类型）顺序写 Flash，串口命令 dump 全部。
4. SPI 速率优化：对比 PSC_2/8/32 下写 4KB 的耗时，画曲线。
5. （I2C 对比）把第 13 章 OLED 的 I2C 接口换成 SPI 接口 SSD1306 模块，测刷新率差异。
6. 掉电测试：写 256 字节 → 彻底断电 30s → 上电读回，验证 NOR 非易失。

---

## 八、本章速查卡模板（学完抄一页纸）

```
【第14章 SPI速查】
引脚  ：SCK=PB13 MOSI=PB15 MISO=PB14(浮空输入) CS=PE2(软件 GPIO)
函数  ：spi_init(SPI0,&s) MASTER+FULLDUPLEX+8BIT+NSS_SOFT+MSB+PL_LOW_PH_1EDGE
        spi_i2s_data_transmit/receive；TBE/RBNE 轮询
命令  ：0x06 WREN / 0x05 RDSR(WIP bit0) / 0x9F JEDEC / 0x03 READ / 0x02 PP(256B不跨页) / 0x20 SE(4KB)
板载  ：GD25Q32 = C8 40 16，4MB（0x000000-0x3FFFFF）
流程  ：WREN→(SE|PP)→查 WIP 清→下一步
坑    ：忘 WREN；忘擦；跨页；CS 早拉高；MISO 配错；容量按 16MB 算
```
