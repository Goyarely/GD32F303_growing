/*!
    \file    systick.h
    \brief   systick delay for GD32F303ZE
*/
#ifndef SYSTICK_H
#define SYSTICK_H

#include "gd32f30x.h"

/* configure systick timer for 1ms interrupts */
void systick_config(void);

/* delay a time in milliseconds */
void delay_1ms(uint32_t count);

/* decrement the delay counter, called from SysTick_Handler */
void delay_decrement(void);

#endif /* SYSTICK_H */
