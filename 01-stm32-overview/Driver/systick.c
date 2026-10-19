/*!
    \file    systick.c
    \brief   systick configuration for GD32F303ZE

    \note    延时实现：SysTick 1ms 中断里递减计数，
            主循环轮询计数到零（与官方 Template 一致）
*/
#include "gd32f30x.h"
#include "systick.h"

volatile static uint32_t delay_count;

/*!
    \brief      configure systick
    \param[in]  none
    \param[out] none
    \retval     none
*/
void systick_config(void)
{
    /* setup systick timer for 1000Hz interrupts */
    if(SysTick_Config(SystemCoreClock / 1000U)){
        /* capture error */
        while(1){
        }
    }
    /* configure the systick handler priority */
    NVIC_SetPriority(SysTick_IRQn, 0x00U);
}

/*!
    \brief      delay a time in milliseconds
    \param[in]  count: count in milliseconds
    \param[out] none
    \retval     none
*/
void delay_1ms(uint32_t count)
{
    delay_count = count;

    while(0U != delay_count){
    }
}

/*!
    \brief      delay decrement
    \param[in]  none
    \param[out] none
    \retval     none
*/
void delay_decrement(void)
{
    if(0U != delay_count){
        delay_count--;
    }
}
