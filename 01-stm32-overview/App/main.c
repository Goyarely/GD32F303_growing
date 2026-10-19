/*!
    \file    main.c
    \brief   GD32F303ZE 麒麟ARM 主程序
             LED1(PA8) 500ms 闪烁 + 调试串口每秒打印一次状态

    \note    LED 驱动见 Driver/lcd.c（led_init/led_on/led_off），
             调试串口见 Driver/usart.c（usart_init/usart_send，当前 USART1 PA2/PA3）。
             printf 输出由 App/syscalls.c 的 _write() 经 usart_send() 重定向到串口。
*/
#include "gd32f30x.h"
#include "systick.h"
#include "usart.h"
#include "lcd.h"
#include <stdio.h>

/*!
    \brief      main function

    \note       系统时钟由 system_gd32f30x.c 中选择的宏决定：
                __SYSTEM_CLOCK_120M_PLL_HXTAL
                外部 8MHz 晶振 -> PLL x15 -> CK_SYS=120MHz
                CK_AHB=120MHz, CK_APB1=60MHz, CK_APB2=120MHz

    \param[in]  none
    \param[out] none
    \retval     none
*/
int main(void)
{
    systick_config();       /* 1ms 时基 + delay_1ms */
    led_init();             /* LED1 = PA8 */
    usart_init();           /* 调试串口 115200 8N1 */

    printf("\r\nGD32F303ZE 麒麟ARM ready, CK_SYS=%luHz CK_AHB=%luHz CK_APB1=%luHz CK_APB2=%luHz\r\n",
           (unsigned long)rcu_clock_freq_get(CK_SYS), (unsigned long)rcu_clock_freq_get(CK_AHB),
           (unsigned long)rcu_clock_freq_get(CK_APB1), (unsigned long)rcu_clock_freq_get(CK_APB2));

    uint32_t tick = 0;
    while(1){
        led_on();
        delay_1ms(500);
        led_off();
        delay_1ms(500);
        /* 主循环周期打印：随时打开串口都能看到输出，无需复位 */
        printf("tick %lu, LED1 off, CK_SYS=%luHz\r\n",
               (unsigned long)++tick, (unsigned long)rcu_clock_freq_get(CK_SYS));
    }
}
