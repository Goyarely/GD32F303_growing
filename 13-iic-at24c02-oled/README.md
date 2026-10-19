# 13 · IIC 实现 + AT24C02 + 显示屏

> 对应课程：13-IIC实现+AT24C02+OLED
> 前置要求：第 12 章（I2C 协议）
> 建议耗时：5-7 天

---

## 本章实板资源

| 资源 | 参数 | 说明 |
|---|---|---|
| AT24C02 | I2C0(PB6/PB7)，0xA0，256 字节 | **板载**，第 12 章已点亮 |
| AP3216C | I2C0，光感+接近 | 板载（地址 0x3C 附近，拓展再玩） |
| 触摸屏 | I2C：PF9=SDA、PF10=SCL，PB12=INT、PB9=RST | 板载 |
| 3.5 寸 TFT | EXMC 8080 接口 + 背光 PB1 | 板载，**高级选项** |
| SSD1306 OLED | 需外接（I2C0，地址 0x78/0x7A） | 无板载，外接模块即可 |

> F103 时代是"AT24C02 + OLED"组合。本板 **AT24C02 板载**，
> OLED 需外接 I2C 模块（与 AT24C02 共用 I2C0，地址不同不冲突）；
> 有余力可挑战板载 3.5 寸 TFT（EXMC，第 13 章后拓展）。

---

## 一、学习内容

### 1. I2C 驱动分层（本章核心工程化主题）

```
App/main.c            业务：读传感器 → 存 EEPROM → 刷新显示
Driver/eeprom.c       AT24C02 驱动：page 读写 + ACK 查询（第 12 章封装）
Driver/oled.c         SSD1306 驱动：命令/数据帧 + 显存 + 字符点阵
Driver/i2c_sw.c       （拓展）GPIO 模拟 I2C——理解协议本质
```

**原则**：`main.c` 只调 `eeprom_read/write`、`oled_show_xxx`，不见任何 `i2c_flag_get`。

### 2. AT24C02 关键参数

| 参数 | 值 |
|---|---|
| 容量 | 2Kbit = **256 字节** |
| 地址 | 0xA0（写）/ 0xA1（读） |
| 页 | 8 字节 |
| 写周期 | ≤5ms（ACK 查询） |
| 时钟 | 100kHz/400kHz（本板 100kHz） |

### 3. SSD1306 OLED（外接，I2C）

- 地址：0x78（0x3C << 1）
- 两类字节：**命令**（0x00 前缀）和**数据**（0x40 前缀）
- 显存：128×64 bit = **1KB**，对应 GD32 内部 SRAM 显存缓冲
- 初始化序列 ~20 条命令（对比度/充电泵/扫描方向/COM 配置）
- 帧率：I2C 1KB 全刷 @100kHz ≈ 100ms+ → 局部刷新或降分辨率

### 4. 板载 TFT（拓展，EXMC 8080）

- 数据 D0-D15 + 控制（CS/RS/WR/RD/RST），按 LCD 控制器命令写
- 优点：快、彩色；缺点：要按具体控制器（ILI9488/ST7789 等）写初始化

---

## 二、学习目标

- [ ] 能把第 12 章的 I2C 裸代码封装成 `eeprom.c` 驱动（main.c 不见寄存器）
- [ ] 能写出 SSD1306 的初始化 + 画点 + 显示字符串
- [ ] 能解释显存缓冲的作用和 I2C OLED 的刷新瓶颈
- [ ] 能实现"ADC 值 → EEPROM 掉电保存 → OLED 显示"小系统
- [ ] （拓展）能说出板载 TFT 与 I2C OLED 的选型逻辑

---

## 三、学习方法

1. **先分层再写**：先把 `eeprom.c` 的 API 定出来（头文件），再实现，最后才写 main。
2. **抓 I2C 时序**：把第 12 章抓时序的方法用到 OLED 初始化上，逐条命令核对。
3. **点阵对账**：写一个画点函数，先在纸上算"坐标 (x,y) → 显存第几字节第几位"，再验证。
4. **刷新优化**：对比全量刷新和局部刷新的耗时（串口打时间戳）。

---

## 四、标准示例

### 1. EEPROM 驱动封装（`Driver/eeprom.h/c`）

```c
/* eeprom.h */
#ifndef EEPROM_H
#define EEPROM_H
#include <stdint.h>

void     eeprom_init(void);                      /* I2C0 100kHz */
uint8_t  eeprom_read_byte(uint8_t addr);
void     eeprom_write_byte(uint8_t addr, uint8_t data);
void     eeprom_read(uint8_t addr, uint8_t *buf, uint16_t len);   /* 连续读 */
void     eeprom_write(uint8_t addr, const uint8_t *buf, uint16_t len); /* 自动分页 */
#endif
```

```c
/* eeprom.c：连续读（24C02 支持顺序读：读完一字节地址自增，主机直接 NACK+STOP） */
void eeprom_read(uint8_t addr, uint8_t *buf, uint16_t len)
{
    i2c_start_on_bus(I2C0);
    while (i2c_flag_get(I2C0, I2C_FLAG_SBSEND) == RESET) { }
    i2c_data_transmit(I2C0, EEPROM_ADDR);
    while (i2c_flag_get(I2C0, I2C_FLAG_ADDSEND) == RESET) { }
    i2c_flag_clear(I2C0, I2C_FLAG_ADDSEND);
    i2c_data_transmit(I2C0, addr);
    while (i2c_flag_get(I2C0, I2C_FLAG_BTC) == RESET) { }

    i2c_start_on_bus(I2C0);                              /* RESTART */
    while (i2c_flag_get(I2C0, I2C_FLAG_SBSEND) == RESET) { }
    i2c_data_transmit(I2C0, EEPROM_ADDR | 0x01U);
    while (i2c_flag_get(I2C0, I2C_FLAG_ADDSEND) == RESET) { }
    i2c_flag_clear(I2C0, I2C_FLAG_ADDSEND);

    for (uint16_t i = 0; i < len; i++) {
        if (i == len - 1) {                              /* 最后一个字节前关 ACK */
            i2c_ack_config(I2C0, I2C_ACK_DISABLE);
        }
        while (i2c_flag_get(I2C0, I2C_FLAG_RBNE) == RESET) { }
        buf[i] = i2c_data_receive(I2C0);
    }
    i2c_stop_on_bus(I2C0);
    i2c_ack_config(I2C0, I2C_ACK_ENABLE);
}

/* 连续写：按 8 字节页拆，页内连续，跨页先等写周期 */
void eeprom_write(uint8_t addr, const uint8_t *buf, uint16_t len)
{
    uint16_t remaining = len;

    while (remaining > 0) {
        uint16_t page_left = EEPROM_PAGE - (addr % EEPROM_PAGE);  /* 本页还能写几字节 */
        uint16_t n = (remaining < page_left) ? remaining : page_left;

        i2c_start_on_bus(I2C0);
        while (i2c_flag_get(I2C0, I2C_FLAG_SBSEND) == RESET) { }
        i2c_data_transmit(I2C0, EEPROM_ADDR);
        while (i2c_flag_get(I2C0, I2C_FLAG_ADDSEND) == RESET) { }
        i2c_flag_clear(I2C0, I2C_FLAG_ADDSEND);
        i2c_data_transmit(I2C0, addr);
        while (i2c_flag_get(I2C0, I2C_FLAG_BTC) == RESET) { }
        for (uint16_t i = 0; i < n; i++) {
            i2c_data_transmit(I2C0, buf[i]);
            while (i2c_flag_get(I2C0, I2C_FLAG_BTC) == RESET) { }
        }
        i2c_stop_on_bus(I2C0);

        addr       += (uint8_t)n;
        buf        += n;
        remaining  -= n;
        eeprom_wait_ready();                       /* 等写周期（ACK 查询） */
    }
}
```

### 2. SSD1306 基础帧（外接 OLED）

```c
#include "gd32f30x.h"

#define OLED_ADDR   0x78U        /* 0x3C << 1 */

static uint8_t oled_fb[128 * 64 / 8];    /* 1KB 显存：每字节 8 个纵向像素 */

void oled_write_cmd(uint8_t cmd)
{
    /* START → 0x78 → 控制字节 0x00 → 命令 */
    i2c_start_on_bus(I2C0);
    while (i2c_flag_get(I2C0, I2C_FLAG_SBSEND) == RESET) { }
    i2c_data_transmit(I2C0, OLED_ADDR);
    while (i2c_flag_get(I2C0, I2C_FLAG_ADDSEND) == RESET) { }
    i2c_flag_clear(I2C0, I2C_FLAG_ADDSEND);
    i2c_data_transmit(I2C0, 0x00U);                    /* Co=0, D/C#=0 → 命令 */
    while (i2c_flag_get(I2C0, I2C_FLAG_BTC) == RESET) { }
    i2c_data_transmit(I2C0, cmd);
    while (i2c_flag_get(I2C0, I2C_FLAG_BTC) == RESET) { }
    i2c_stop_on_bus(I2C0);
}

void oled_set_pos(uint8_t x, uint8_t page)
{
    oled_write_cmd(0xB0U + page);                      /* 页地址 0~7 */
    oled_write_cmd(((x & 0xF0U) >> 4) | 0x10U);        /* 列高 4 位 */
    oled_write_cmd((x & 0x0FU) | 0x00U);               /* 列低 4 位 */
}

void oled_flush(void)                                  /* 全量刷一帧 */
{
    for (uint8_t page = 0; page < 8; page++) {
        oled_set_pos(0, page);
        /* 数据帧：START → 0x78 → 0x40 → 128 字节数据 */
        i2c_start_on_bus(I2C0);
        while (i2c_flag_get(I2C0, I2C_FLAG_SBSEND) == RESET) { }
        i2c_data_transmit(I2C0, OLED_ADDR);
        while (i2c_flag_get(I2C0, I2C_FLAG_ADDSEND) == RESET) { }
        i2c_flag_clear(I2C0, I2C_FLAG_ADDSEND);
        i2c_data_transmit(I2C0, 0x40U);                /* D/C#=1 → 数据 */
        while (i2c_flag_get(I2C0, I2C_FLAG_BTC) == RESET) { }
        for (uint8_t i = 0; i < 128; i++) {
            i2c_data_transmit(I2C0, oled_fb[page * 128 + i]);
            while (i2c_flag_get(I2C0, I2C_FLAG_BTC) == RESET) { }
        }
        i2c_stop_on_bus(I2C0);
    }
}

void oled_draw_pixel(uint8_t x, uint8_t y, uint8_t on)
{
    if (x >= 128 || y >= 64) return;
    if (on) {
        oled_fb[(y / 8) * 128 + x] |=  (1U << (y % 8));
    } else {
        oled_fb[(y / 8) * 128 + x] &= ~(1U << (y % 8));
    }
}
```

### 3. 小系统：ADC → EEPROM → OLED

```c
int main(void)
{
    uint8_t  page = 0U;
    uint16_t last_raw = 0xFFFFU;

    systick_config();
    usart0_init();
    i2c0_init();          /* 内含 eeprom_init */
    eeprom_init();
    oled_init();          /* SSD1306 初始化序列（对比度/充电泵/正常显示） */
    adc_dma_init();       /* 第 11 章成果 */

    while (1) {
        uint16_t raw = g_adc_buf[0];               /* 电位器 */
        if (raw != last_raw) {                     /* 变化才刷新 */
            last_raw = raw;
            /* 掉电保存最近 8 个采样（环形） */
            eeprom_write_byte(0x00 + page, (uint8_t)(raw >> 8));
            eeprom_write_byte(0x08 + page, (uint8_t)(raw & 0xFF));
            page = (page + 1U) & 0x07U;

            oled_show_string(0, 0, "POT:");
            oled_show_uint(32, 0, raw);
            oled_flush();
            printf("raw=%u saved to page %u\r\n", raw, page);
        }
        delay_1ms(100);
    }
}
```

---

## 五、自我检测

1. 画出驱动分层图：main / eeprom / oled / i2c 各自负责什么。
2. SSD1306 的"命令字节"和"数据字节"怎么区分？控制字节 0x00 和 0x40 各是什么？
3. 显存 128×64 为什么是 1KB？坐标 (65, 20) 在显存第几字节第几位？
4. 连续写跨页时，`page_left` 怎么算？为什么必须等写周期？
5. 连续读的 ACK 策略：最后一个字节前做什么？为什么？
6. I2C 全量刷 1KB @100kHz 理论要多久？实际为什么更慢？怎么优化？
7. AT24C02 和 OLED 共用 I2C0，为什么能共存？前提是什么？
8. 板载 TFT（EXMC）和 I2C OLED 各适合什么场景？

---

## 六、常见坑

| 现象 | 原因 |
|---|---|
| OLED 全白/全黑/花屏 | 初始化序列不完整；或页/列地址没设对；或对比度没调 |
| OLED 只亮一角 | 显存分页错：128×64 = 8 页 × 128 列，不是 64 行连续排 |
| AT24C02 和 OLED 同时用时 OLED 卡 | 地址冲突（OLED 0x78 与 24C02 0xA0 不同才对）；或 ACK 查询死等 |
| 跨页写后数据错乱 | 没按 8 字节页拆；或写完没等写周期 |
| 连续读最后一字节错 | 最后一个字节前没关 ACK；或读完没 STOP 就重新 START |
| 刷新很慢/闪 | I2C 100kHz 全刷 1KB 太慢；改局部刷新/400kHz/SPI OLED |
| 字符串显示缺列 | 字库每字节 8 像素纵向排列，取模方式要和显存排布一致 |
| I2C 挂死整线 | 从机拉死 SDA；用 `i2c_software_reset_config` 或断电恢复 |

---

## 七、拓展练习

1. 补全 SSD1306 初始化序列和 8×16 ASCII 字库，显示字符串+数字（打表不用背）。
2. 局部刷新：只重绘变化区域，串口打前后耗时对比。
3. 上电恢复：从 AT24C02 读回上次的 8 个采样显示到 OLED，验证掉电保存。
4. （协议本质）写一个 GPIO 模拟 I2C（位段版），与硬件 I2C 对比速率和代码量。
5. （板载 TFT）查 3.5 寸屏控制器型号，用 EXMC 写初始化 + 填色，和 OLED 对比。
6. AP3216C 光感：读 I2C 数据，OLED 上画环境光曲线（简化版示波器）。

---

## 八、本章速查卡模板（学完抄一页纸）

```
【第13章 IIC/OLED速查】
分层  ：main 只见 eeprom_xxx/oled_xxx；i2c_flag_get 只出现在驱动层
AT24C02：0xA0/0xA1；256B；页 8B；写周期 ACK 查询；连续读末字节前关 ACK
OLED  ：0x78；控制字节 0x00=命令 0x40=数据；显存 8 页×128 列=1KB
        (x,y)→fb[(y/8)*128+x] bit(y%8)；刷新前设 页0xB0+page / 列高|0x10 / 列低
板载  ：TFT=EXMC(D0-D15+NE1)，触摸=PF9/PF10，AP3216C=I2C0
坑    ：初始化不全；分页错；跨页；末字节 ACK；I2C 全刷慢
```
