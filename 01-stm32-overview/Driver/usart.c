/*!
    \file    usart.c
    \brief   调试串口驱动实现（GD32F30x SPL，阻塞发送）

    \note    串口/引脚选择见 usart.h（当前 USART0：PA9=TX / PA10=RX，板载 CH340C）。
             SPL 的 usart_baudrate_set() 会自动区分 USART0(APB2 120MHz) /
             USART1/2(APB1 60MHz) 计算分频，无需手工处理。
*/
#include <stddef.h>         /* NULL */

#include "usart.h"

/*!
    \brief      初始化调试串口：DEBUG_BAUD，8N1
    \param[in]  none
    \param[out] none
    \retval     none
*/
void usart_init(void)
{
    rcu_periph_clock_enable(DEBUG_USART_RCU);

    /* TX 复用推挽输出，RX 上拉输入（与官方例程一致，悬空时不会误触发起始位） */
    gpio_init(DEBUG_USART_GPIO, GPIO_MODE_AF_PP, GPIO_OSPEED_50MHZ, DEBUG_TX_PIN);
    gpio_init(DEBUG_USART_GPIO, GPIO_MODE_IPU, GPIO_OSPEED_50MHZ, DEBUG_RX_PIN);

    usart_deinit(DEBUG_USART);
    usart_baudrate_set(DEBUG_USART, DEBUG_BAUD);
    usart_parity_config(DEBUG_USART, USART_PM_NONE);
    usart_word_length_set(DEBUG_USART, USART_WL_8BIT);
    usart_stop_bit_set(DEBUG_USART, USART_STB_1BIT);
    /* 关键：必须单独使能发送/接收。
       usart_deinit() 会把 CTL0 清零（TEN/REN=0），只调 usart_enable()（置 UEN）
       TX 引脚不会有任何输出 —— 这是"串口无输出"的根因。 */
    usart_transmit_config(DEBUG_USART, USART_TRANSMIT_ENABLE);
    usart_receive_config(DEBUG_USART, USART_RECEIVE_ENABLE);
    usart_enable(DEBUG_USART);
}

/*!
    \brief      发送一个字节（阻塞）
    \param[in]  byte: 待发送字节
    \param[out] none
    \retval     none
*/
void usart_send_byte(uint8_t byte)
{
    usart_data_transmit(DEBUG_USART, byte);
    while(RESET == usart_flag_get(DEBUG_USART, USART_FLAG_TBE)){
    }
}

/*!
    \brief      发送一段数据（阻塞）
    \param[in]  data: 数据指针
    \param[in]  len:  字节数
    \param[out] none
    \retval     none
*/
void usart_send(const uint8_t *data, uint16_t len)
{
    uint16_t i;

    if(data == NULL){
        return;
    }
    for(i = 0; i < len; i++){
        usart_send_byte(data[i]);
    }
}
