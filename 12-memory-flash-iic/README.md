# 12 · 存储器分类 + 内部 FLASH + IIC 协议

> 对应课程：12-存储器分类+FLASH+IIC协议
> 前置要求：第 07 章（串口）、第 11 章（ADC，可选）
> 建议耗时：5-7 天

---

## 本章实板资源

| 资源 | 参数 | 说明 |
|---|---|---|
| 内部 FLASH | **512KB**，基址 0x08000000 | FMC 控制；掉电保持 |
| 内部 SRAM | 64KB，基址 0x20000000 | 变量/栈/堆 |
| AT24C02 EEPROM | **2Kbit = 256 字节**，I2C0(PB6/PB7)，地址 0xA0/0xA1 | 板载，4.7k 上拉已有 |
| 外部 SRAM | IS62WV51216（512KB），EXMC | 第 13 章后可拓展 |

---

## 一、学习内容

### 1. 存储器分类（先建立地图）

| 类型 | 掉电 | 速度 | 本板实例 | 用途 |
|---|---|---|---|---|
| ROM/Flash | 保持 | 慢（写）/快（读） | 512KB 内部 FLASH | 程序 + 常量 + 掉电数据 |
| SRAM | 丢失 | 快 | 64KB 内部 + 512KB EXMC | 变量、栈、堆 |
| EEPROM | 保持 | 慢 | AT24C02（I2C） | 小量频繁改的参数 |
| NOR/NAND Flash | 保持 | 中 | GD25Q32（SPI，第 14 章） | 大数据块、日志 |

**三条铁律**：

1. 常量（`const`）和字符串放 Flash（`.rodata`），别浪费 SRAM
2. 掉电要存的数据 → EEPROM/内部 FLASH，**不能放 SRAM**
3. Flash/EEPROM **写前必擦、有寿命、写周期 ms 级**，别在中断里写

### 2. 内部 FLASH 操作（FMC）

- 解锁：`fmc_unlock()`（写完 `fmc_lock()` 重新上锁）
- 擦除：`fmc_page_erase(page_address)`——**按页擦**（GD32F30x 页大小查手册，常见 2KB）
- 编程：`fmc_word_program(address, data)`（32 位字）/ `fmc_halfword_program`（16 位）
- 状态：`fmc_flag_get(FMC_FLAG_BUSY)`，写完必须等 BUSY 清
- 返回值 `fmc_state_enum`（`FMC_READY / FMC_BUSY / FMC_WPERR / FMC_PGERR`）

```
注意：0x08000000 同时"是代码所在地"——擦自己所在的页 = 删自己程序。
    初学者把数据页放在程序末尾之后（看 .map 里代码实际占多少），别覆盖向量表！
```

### 3. I2C 协议（AT24C02 的'语言'）

- 两线：**SCL(PB6)** 时钟 + **SDA(PB7)** 数据，**开漏 + 上拉**（板载 4.7k）
- 帧格式：

```
START | 器件地址(7bit)+R/W | ACK | 数据... | ACK | STOP
```

- AT24C02 器件地址：`1010 000` + 片选 = **0xA0（写）/ 0xA1（读）**
- **页写**：24C02 一页 **8 字节**；跨页要拆开发
- 写周期 ~5ms（写完芯片内部在搬，期间不应答——**查询 ACK** 判断写完）
- SPL 是"事件轮询式"：每步等一个标志

### 4. I2C 事件序列（写 1 字节到 AT24C02）

```c
i2c_start_on_bus(I2C0);                     /* START */
while(!i2c_flag_get(I2C0, I2C_FLAG_SBSEND));    /* 等起始位发出 */
i2c_data_transmit(I2C0, 0xA0);              /* 发器件地址+写 */
while(!i2c_flag_get(I2C0, I2C_FLAG_ADDSEND));   /* 等地址发送 */
i2c_flag_clear(I2C0, I2C_FLAG_ADDSEND);         /* 清 ADDSEND（读 STAT0/STAT1） */
i2c_data_transmit(I2C0, word_addr);         /* 发片内字地址 */
while(!i2c_flag_get(I2C0, I2C_FLAG_BTC));       /* 等字节传输完 */
i2c_data_transmit(I2C0, data);
while(!i2c_flag_get(I2C0, I2C_FLAG_BTC));
i2c_stop_on_bus(I2C0);                      /* STOP */
```

---

## 二、学习目标

- [ ] 能画出本板存储器地图（Flash/SRAM/EEPROM/外部 SRAM 各自地址和用途）
- [ ] 能独立写一页内部 FLASH（解锁→擦→写→读回校验），不覆盖程序
- [ ] 能徒手画出 I2C 的 START/地址/ACK/数据/STOP 时序
- [ ] 能写出 AT24C02 的字节读写驱动（查询式）
- [ ] 能解释页写限制和写周期

---

## 三、学习方法

1. **先画后写**：I2C 时序先画在纸上（含 ACK 位），再照图写代码。
2. **逻辑分析仪/示波器抓 SDA/SCL**：和画的时序逐位对账——I2C 是"看得见"的总线。
3. **FLASH 安全实验**：先用 `.map` 找到代码结束地址，数据页放它后面；写前先读回旧值备份。
4. **对照 ST 手册时序图**：GD32F30x 的 I2C 与 STM32F1 几乎一样，当年的笔记直接能用。

---

## 四、标准示例

### 1. 内部 FLASH 写一页（带安全边界）

```c
#include "gd32f30x.h"

/* 数据页：放在程序之后。先用 .map 看代码占多少，保守取 0x0807F000（512K 末页） */
#define DATA_PAGE_ADDR   0x0807F000U
#define DATA_WORD_NUM    512U        /* 2KB 页 / 4 字节 */

fmc_state_enum flash_write_page(uint32_t addr, const uint32_t *data, uint32_t words)
{
    fmc_state_enum state;

    fmc_unlock();
    state = fmc_page_erase(addr);
    if (state != FMC_READY) {
        fmc_lock();
        return state;
    }

    for (uint32_t i = 0; i < words; i++) {
        state = fmc_word_program(addr + i * 4U, data[i]);
        if (state != FMC_READY) {
            fmc_lock();
            return state;
        }
    }
    fmc_lock();
    return FMC_READY;
}

int main(void)
{
    uint32_t wr[DATA_WORD_NUM];
    uint32_t rd[DATA_WORD_NUM];
    uint8_t  ok = 1U;

    systick_config();
    usart0_init();

    for (uint32_t i = 0; i < DATA_WORD_NUM; i++) {
        wr[i] = 0x5A5A0000U + i;
    }

    if (flash_write_page(DATA_PAGE_ADDR, wr, DATA_WORD_NUM) != FMC_READY) {
        printf("flash write fail\r\n");
        while (1) { }
    }

    for (uint32_t i = 0; i < DATA_WORD_NUM; i++) {
        rd[i] = *(volatile uint32_t *)(DATA_PAGE_ADDR + i * 4U);
        if (rd[i] != wr[i]) ok = 0U;
    }
    printf("flash verify %s\r\n", ok ? "OK" : "FAIL");
    while (1) { }
}
```

> ⚠️ **写之前一定看 `.map` 确认 `DATA_PAGE_ADDR` 没被代码占用**；
> 第一次实验建议先用"读回-比对"确认边界，别直接擦。

### 2. I2C0 + AT24C02 字节读写（查询式）

```c
#include "gd32f30x.h"

/* AT24C02 写地址 = 0xA0（1010 000_0），读地址 = 0xA1（1010 000_1）；
   地址字节由 i2c_data_transmit() 直接发出，R/W 位在最低位 */
#define EEPROM_ADDR   0xA0U
#define EEPROM_PAGE   8U           /* AT24C02：8 字节/页，256 字节容量 */

void i2c0_init(void)
{
    rcu_periph_clock_enable(RCU_GPIOB);
    rcu_periph_clock_enable(RCU_I2C0);

    /* SCL/SDA：AF_OD（开漏复用，板载 4.7k 上拉） */
    gpio_init(GPIOB, GPIO_MODE_AF_OD, GPIO_OSPEED_50MHZ,
              GPIO_PIN_6 | GPIO_PIN_7);

    i2c_deinit(I2C0);
    i2c_clock_config(I2C0, 100000U, I2C_DTCY_2);              /* 100kHz 标准模式 */
    i2c_mode_addr_config(I2C0, I2C_I2CMODE_ENABLE,
                         I2C_ADDFORMAT_7BITS, 0x00U);        /* 主机模式，本机地址无所谓 */
    i2c_ack_config(I2C0, I2C_ACK_ENABLE);
    i2c_enable(I2C0);
}

void eeprom_write_byte(uint8_t addr, uint8_t data)
{
    i2c_start_on_bus(I2C0);
    while (i2c_flag_get(I2C0, I2C_FLAG_SBSEND) == RESET) { }

    i2c_data_transmit(I2C0, EEPROM_ADDR);                     /* 0xA0 + 写 */
    while (i2c_flag_get(I2C0, I2C_FLAG_ADDSEND) == RESET) { }
    i2c_flag_clear(I2C0, I2C_FLAG_ADDSEND);

    i2c_data_transmit(I2C0, addr);                            /* 片内字地址 */
    while (i2c_flag_get(I2C0, I2C_FLAG_BTC) == RESET) { }

    i2c_data_transmit(I2C0, data);
    while (i2c_flag_get(I2C0, I2C_FLAG_BTC) == RESET) { }

    i2c_stop_on_bus(I2C0);
    delay_1ms(5);                                             /* 等内部写周期（或用 ACK 查询） */
}

uint8_t eeprom_read_byte(uint8_t addr)
{
    uint8_t data;

    /* 假写：定位读指针 */
    i2c_start_on_bus(I2C0);
    while (i2c_flag_get(I2C0, I2C_FLAG_SBSEND) == RESET) { }
    i2c_data_transmit(I2C0, EEPROM_ADDR);
    while (i2c_flag_get(I2C0, I2C_FLAG_ADDSEND) == RESET) { }
    i2c_flag_clear(I2C0, I2C_FLAG_ADDSEND);
    i2c_data_transmit(I2C0, addr);
    while (i2c_flag_get(I2C0, I2C_FLAG_BTC) == RESET) { }

    /* RESTART + 读 */
    i2c_start_on_bus(I2C0);
    while (i2c_flag_get(I2C0, I2C_FLAG_SBSEND) == RESET) { }
    i2c_data_transmit(I2C0, EEPROM_ADDR | 0x01U);             /* +读位 */
    while (i2c_flag_get(I2C0, I2C_FLAG_ADDSEND) == RESET) { }
    i2c_flag_clear(I2C0, I2C_FLAG_ADDSEND);

    /* 只读 1 字节：先关 ACK，读完发 STOP */
    i2c_ack_config(I2C0, I2C_ACK_DISABLE);
    while (i2c_flag_get(I2C0, I2C_FLAG_RBNE) == RESET) { }
    data = (uint8_t)i2c_data_receive(I2C0);
    i2c_stop_on_bus(I2C0);
    i2c_ack_config(I2C0, I2C_ACK_ENABLE);                     /* 恢复，供下次 */

    return data;
}
```

### 3. 页写（8 字节，不跨页）+ ACK 查询

```c
void eeprom_write_page(uint8_t page_addr, const uint8_t *buf)
{
    i2c_start_on_bus(I2C0);
    while (i2c_flag_get(I2C0, I2C_FLAG_SBSEND) == RESET) { }
    i2c_data_transmit(I2C0, EEPROM_ADDR);
    while (i2c_flag_get(I2C0, I2C_FLAG_ADDSEND) == RESET) { }
    i2c_flag_clear(I2C0, I2C_FLAG_ADDSEND);
    i2c_data_transmit(I2C0, page_addr);
    while (i2c_flag_get(I2C0, I2C_FLAG_BTC) == RESET) { }

    for (uint8_t i = 0; i < EEPROM_PAGE; i++) {               /* 8 字节一页 */
        i2c_data_transmit(I2C0, buf[i]);
        while (i2c_flag_get(I2C0, I2C_FLAG_BTC) == RESET) { }
    }
    i2c_stop_on_bus(I2C0);
}

/* ACK 查询：反复 START+发地址，直到收到 ACK（ADDSEND 置起）= 写周期完成 */
void eeprom_wait_ready(void)
{
    while (1) {
        i2c_start_on_bus(I2C0);
        while (i2c_flag_get(I2C0, I2C_FLAG_SBSEND) == RESET) { }
        i2c_data_transmit(I2C0, EEPROM_ADDR);
        if (i2c_flag_get(I2C0, I2C_FLAG_ADDSEND) != RESET) {
            i2c_flag_clear(I2C0, I2C_FLAG_ADDSEND);
            i2c_stop_on_bus(I2C0);
            return;
        }
        i2c_stop_on_bus(I2C0);
        delay_1ms(1);
    }
}
```

---

## 五、自我检测

1. 画出本板存储器地图：内部 Flash、SRAM、EEPROM、外部 SRAM 的地址和容量。
2. `fmc_page_erase` 擦的最小单位是什么？写之前不擦会发生什么？
3. 为什么不能拿内部 Flash 当"频繁写的变量"用？
4. 徒手画出"AT24C02 写 1 字节"的完整 I2C 时序（含两个 ACK）。
5. AT24C02 页写为什么限制 8 字节？跨页写会出什么现象？
6. "假写 + RESTART + 读" 为什么要假写那一步？
7. 读单字节为什么要先 `I2C_ACK_DISABLE`？读完为什么必须 STOP？
8. `I2C_FLAG_BTC` 和 `I2C_FLAG_TBE/RBNE` 分别在什么时机用？

---

## 六、常见坑

| 现象 | 原因 |
|---|---|
| I2C 全程无 SBSEND | ① SCL/SDA 没配 `AF_OD`；② 忘开 `RCU_I2C0`；③ 上拉没焊（板载有，外接模块要查） |
| 地址发完卡住 | 等错标志：地址阶段等 `ADDSEND`，数据阶段等 `BTC` |
| 读回 0xFF | 器件没应答（地址错/没上拉）；或"假写"步骤漏了 |
| 写进去读出来不对 | 没等写周期（5ms）就读；或跨页写了 |
| 偶发读错 | ACK 时序错：读 N 字节要在倒数第二字节关 ACK |
| FLASH 写完读回旧值 | ① 没等 BUSY；② 页没擦干净；③ 写之前没 `fmc_unlock` |
| **擦了 Flash 程序变砖** | 擦到代码页了！先看 `.map`，数据页放程序之后 |
| `fmc_page_erase` 返回 WPERR | 没解锁或页地址不对齐 |
| I2C 从设备把总线拉死 | 从机异常时 SDA 拉低；必要时 `i2c_software_reset_config` 或断电 |

---

## 七、拓展练习

1. 写一个 `eeprom_write(buf, addr, len)`：自动按 8 字节页拆包 + ACK 查询，支持跨页。
2. 掉电参数存储：把"LED 亮度档位 + 校准值"存 AT24C02，上电读回恢复；验证掉电再上电。
3. FLASH 双缓冲：两个数据页轮换写（A/B），每次写新的那页并更新页码，掉电后总能找到最新——工业常用套路。
4. 用逻辑分析仪抓 I2C 时序，和自己画的图逐位对账（找不到分析仪就用示波器看 SCL 频率）。
5. 统计 AT24C02 写吞吐：1 万次页写要多久？解释为什么 EEPROM 不能当 SRAM 用。
6. 把 `delay_1ms(5)` 等写周期换成 ACK 查询，测总耗时差异。

---

## 八、本章速查卡模板（学完抄一页纸）

```
【第12章 存储/IIC速查】
FLASH ：512KB@0x08000000；fmc_unlock→page_erase→word_program→lock；写前必擦；等 BUSY
        ★数据页放程序之后（看 .map），别擦代码页
I2C   ：SCL=PB6 SDA=PB7（AF_OD，4.7k 上拉）；100kHz：i2c_clock_config(I2C0,100000,I2C_DTCY_2)
        START→SBSEND→0xA0→ADDSEND(清)→字地址→BTC→数据→BTC→STOP
        读：假写定位→START→0xA1→关ACK→RBNE→读→STOP
标志  ：SBSEND(起始) ADDSEND(地址) BTC(字节完) TBE(发送空) RBNE(接收不空)
EEPROM：AT24C02 256B；页写 8B；写周期 5ms（ACK 查询代替延时）
坑    ：忘 AF_OD；等错标志；跨页；读前不假写；擦 Flash 擦到代码
```
