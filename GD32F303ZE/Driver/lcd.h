/*!
    \file    lcd.h
    \brief   LED 驱动（LED1 = PA8）

    \note    本文件内容为 LED 驱动。文件名是 lcd，如需改为 led.c/led.h，
             直接重命名文件并把 App/main.c 里的 #include 一起改掉即可。
             板上另有 LED2=PE6、LED3=PF6（见板级速查卡），需要时按同样方式添加。
*/
#ifndef LCD_H
#define LCD_H

#include "gd32f30x.h"

/* ---------------- LED 引脚（麒麟ARM 板） ---------------- */
#define LED1_GPIO           GPIOA
#define LED1_PIN            GPIO_PIN_8
#define LED1_RCU            RCU_GPIOA

/*!
    \brief      初始化 LED1 为推挽输出，默认熄灭
    \param[in]  none
    \param[out] none
    \retval     none
*/
void led_init(void);

/*!
    \brief      点亮 LED1
*/
void led_on(void);

/*!
    \brief      熄灭 LED1
*/
void led_off(void);

/*!
    \brief      翻转 LED1 状态
*/
void led_toggle(void);

#endif /* LCD_H */
