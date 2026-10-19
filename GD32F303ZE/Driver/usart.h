/*!
    \file    usart.h
    \brief   调试串口驱动（阻塞收发）

    \note    串口选择在这里配置：
             USART0：PA9(TX) / PA10(RX) → 板载 CH340C (J10)
                     该口带 DTR/RTS 一键下载电路（控制 BOOT0/NRST），
                     普通串口工具打开端口会把 MCU 按在复位里（无输出 + LED 停），
                     需用 tools/serial_monitor.py
             USART1：PA2(TX) / PA3(RX) → JP1/JP2 排针引出，外接 USB-TTL
                     无自动复位电路干扰（当前使用）

             注意：USART2 的 PB10/PB11 接板上 ESP8684 WiFi 模组，勿占用；
                   UART3/4 的引脚在本板被 SDIO 占用。
*/
#ifndef USART_H
#define USART_H

#include "gd32f30x.h"

/* ---------------- 调试串口配置（当前：USART0，板载 CH340C / J10）---------------- */
#define DEBUG_USART         USART0
#define DEBUG_USART_RCU     RCU_USART0
#define DEBUG_USART_GPIO    GPIOA
#define DEBUG_TX_PIN        GPIO_PIN_9        /* PA9  = USART0_TX */
#define DEBUG_RX_PIN        GPIO_PIN_10       /* PA10 = USART0_RX */
#define DEBUG_BAUD          115200U

/* 如改用外置 USB-TTL（JP1/JP2 排针，无 DTR/RTS 自动复位干扰），把上面 6 行换成：
   #define DEBUG_USART         USART1
   #define DEBUG_USART_RCU     RCU_USART1
   #define DEBUG_USART_GPIO    GPIOA
   #define DEBUG_TX_PIN        GPIO_PIN_2
   #define DEBUG_RX_PIN        GPIO_PIN_3
   #define DEBUG_BAUD          115200U
*/

/*!
    \brief      初始化调试串口：DEBUG_BAUD，8N1
    \param[in]  none
    \param[out] none
    \retval     none
*/
void usart_init(void);

/*!
    \brief      发送一个字节（阻塞，等 TBE 置位）
    \param[in]  byte: 待发送字节
    \param[out] none
    \retval     none
*/
void usart_send_byte(uint8_t byte);

/*!
    \brief      发送一段数据（阻塞）
    \param[in]  data: 数据指针
    \param[in]  len:  字节数
    \param[out] none
    \retval     none
*/
void usart_send(const uint8_t *data, uint16_t len);

#endif /* USART_H */
