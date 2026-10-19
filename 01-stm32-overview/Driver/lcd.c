/*!
    \file    lcd.c
    \brief   LED 驱动实现（LED1 = PA8）

    \note    LED 极性以实物为准；本板 LED1 接 PA8（经 1k 限流）。
*/
#include "lcd.h"

/* 记录当前状态，供 led_toggle 使用（led_on/led_off 会同步更新） */
static uint8_t s_led_on = 0U;

/*!
    \brief      初始化 LED1 为推挽输出，默认熄灭
    \param[in]  none
    \param[out] none
    \retval     none
*/
void led_init(void)
{
    rcu_periph_clock_enable(LED1_RCU);
    gpio_init(LED1_GPIO, GPIO_MODE_OUT_PP, GPIO_OSPEED_50MHZ, LED1_PIN);
    led_off();
}

/*!
    \brief      点亮 LED1
*/
void led_on(void)
{
    gpio_bit_set(LED1_GPIO, LED1_PIN);
    s_led_on = 1U;
}

/*!
    \brief      熄灭 LED1
*/
void led_off(void)
{
    gpio_bit_reset(LED1_GPIO, LED1_PIN);
    s_led_on = 0U;
}

/*!
    \brief      翻转 LED1 状态
*/
void led_toggle(void)
{
    if(0U != s_led_on){
        led_off();
    }else{
        led_on();
    }
}
