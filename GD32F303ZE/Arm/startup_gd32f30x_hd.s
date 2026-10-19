/*!
    \file    startup_gd32f30x_hd.s
    \brief   GNU GCC startup file for GD32F303ZE (GD32F303ZET6, GD32F30x HD)

    \note    由 GigaDevice 官方 ARM 版 startup_gd32f30x_hd.s 移植为 GNU as 语法，
             向量表顺序与官方一致：16 个内核异常 + 60 个外部中断(IRQ0~IRQ59)。
             中断处理函数为 weak 别名，用户可在 App/gd32f30x_it.c 中重定义。

    \version 移植自 GD32F30x_Firmware_Library_V2.1.5
*/

    .syntax unified
    .cpu cortex-m4
    .thumb

/* .isr_vector 由链接脚本放到 Flash 起始地址 0x08000000 */
    .section .isr_vector,"a",%progbits
    .align 2
    .globl __isr_vector
__isr_vector:
    .word   _estack                             /* Top of Stack */
    .word   Reset_Handler                       /* Reset Handler */
    .word   NMI_Handler                         /* NMI Handler */
    .word   HardFault_Handler                   /* Hard Fault Handler */
    .word   MemManage_Handler                   /* MPU Fault Handler */
    .word   BusFault_Handler                    /* Bus Fault Handler */
    .word   UsageFault_Handler                  /* Usage Fault Handler */
    .word   0                                   /* Reserved */
    .word   0                                   /* Reserved */
    .word   0                                   /* Reserved */
    .word   0                                   /* Reserved */
    .word   SVC_Handler                         /* SVCall Handler */
    .word   DebugMon_Handler                    /* Debug Monitor Handler */
    .word   0                                   /* Reserved */
    .word   PendSV_Handler                      /* PendSV Handler */
    .word   SysTick_Handler                     /* SysTick Handler */

    /* external interrupts handler, IRQ 0 - 59 */
    .word   WWDGT_IRQHandler                    /* 0:Window Watchdog Timer */
    .word   LVD_IRQHandler                      /* 1:LVD through EXTI Line detect */
    .word   TAMPER_IRQHandler                   /* 2:Tamper through EXTI Line detect */
    .word   RTC_IRQHandler                      /* 3:RTC through EXTI Line */
    .word   FMC_IRQHandler                      /* 4:FMC */
    .word   RCU_CTC_IRQHandler                  /* 5:RCU and CTC */
    .word   EXTI0_IRQHandler                    /* 6:EXTI Line 0 */
    .word   EXTI1_IRQHandler                    /* 7:EXTI Line 1 */
    .word   EXTI2_IRQHandler                    /* 8:EXTI Line 2 */
    .word   EXTI3_IRQHandler                    /* 9:EXTI Line 3 */
    .word   EXTI4_IRQHandler                    /* 10:EXTI Line 4 */
    .word   DMA0_Channel0_IRQHandler            /* 11:DMA0 Channel0 */
    .word   DMA0_Channel1_IRQHandler            /* 12:DMA0 Channel1 */
    .word   DMA0_Channel2_IRQHandler            /* 13:DMA0 Channel2 */
    .word   DMA0_Channel3_IRQHandler            /* 14:DMA0 Channel3 */
    .word   DMA0_Channel4_IRQHandler            /* 15:DMA0 Channel4 */
    .word   DMA0_Channel5_IRQHandler            /* 16:DMA0 Channel5 */
    .word   DMA0_Channel6_IRQHandler            /* 17:DMA0 Channel6 */
    .word   ADC0_1_IRQHandler                   /* 18:ADC0 and ADC1 */
    .word   USBD_HP_CAN0_TX_IRQHandler          /* 19:USBD HP and CAN0 TX */
    .word   USBD_LP_CAN0_RX0_IRQHandler         /* 20:USBD LP and CAN0 RX0 */
    .word   CAN0_RX1_IRQHandler                 /* 21:CAN0 RX1 */
    .word   CAN0_EWMC_IRQHandler                /* 22:CAN0 EWMC */
    .word   EXTI5_9_IRQHandler                  /* 23:EXTI5 to EXTI9 */
    .word   TIMER0_BRK_IRQHandler               /* 24:TIMER0 Break */
    .word   TIMER0_UP_IRQHandler                /* 25:TIMER0 Update */
    .word   TIMER0_TRG_CMT_IRQHandler           /* 26:TIMER0 Trigger and Commutation */
    .word   TIMER0_Channel_IRQHandler           /* 27:TIMER0 Channel Capture Compare */
    .word   TIMER1_IRQHandler                   /* 28:TIMER1 */
    .word   TIMER2_IRQHandler                   /* 29:TIMER2 */
    .word   TIMER3_IRQHandler                   /* 30:TIMER3 */
    .word   I2C0_EV_IRQHandler                  /* 31:I2C0 Event */
    .word   I2C0_ER_IRQHandler                  /* 32:I2C0 Error */
    .word   I2C1_EV_IRQHandler                  /* 33:I2C1 Event */
    .word   I2C1_ER_IRQHandler                  /* 34:I2C1 Error */
    .word   SPI0_IRQHandler                     /* 35:SPI0 */
    .word   SPI1_IRQHandler                     /* 36:SPI1 */
    .word   USART0_IRQHandler                   /* 37:USART0 */
    .word   USART1_IRQHandler                   /* 38:USART1 */
    .word   USART2_IRQHandler                   /* 39:USART2 */
    .word   EXTI10_15_IRQHandler                /* 40:EXTI10 to EXTI15 */
    .word   RTC_Alarm_IRQHandler                /* 41:RTC Alarm */
    .word   USBD_WKUP_IRQHandler                /* 42:USBD Wakeup */
    .word   TIMER7_BRK_IRQHandler               /* 43:TIMER7 Break */
    .word   TIMER7_UP_IRQHandler                /* 44:TIMER7 Update */
    .word   TIMER7_TRG_CMT_IRQHandler           /* 45:TIMER7 Trigger and Commutation */
    .word   TIMER7_Channel_IRQHandler           /* 46:TIMER7 Channel Capture Compare */
    .word   ADC2_IRQHandler                     /* 47:ADC2 */
    .word   EXMC_IRQHandler                     /* 48:EXMC */
    .word   SDIO_IRQHandler                     /* 49:SDIO */
    .word   TIMER4_IRQHandler                   /* 50:TIMER4 */
    .word   SPI2_IRQHandler                     /* 51:SPI2 */
    .word   UART3_IRQHandler                    /* 52:UART3 */
    .word   UART4_IRQHandler                    /* 53:UART4 */
    .word   TIMER5_IRQHandler                   /* 54:TIMER5 */
    .word   TIMER6_IRQHandler                   /* 55:TIMER6 */
    .word   DMA1_Channel0_IRQHandler            /* 56:DMA1 Channel0 */
    .word   DMA1_Channel1_IRQHandler            /* 57:DMA1 Channel1 */
    .word   DMA1_Channel2_IRQHandler            /* 58:DMA1 Channel2 */
    .word   DMA1_Channel3_4_IRQHandler          /* 59:DMA1 Channel3 and Channel4 */

    .section .text.Reset_Handler
    .weak Reset_Handler
    .type Reset_Handler, %function
Reset_Handler:
    bl      SystemInit                         /* 时钟与 FPU 初始化(system_gd32f30x.c) */

    /* copy .data from FLASH to SRAM */
    ldr     r0, =_sidata
    ldr     r1, =_sdata
    ldr     r2, =_edata
1:  cmp     r1, r2
    ittt    lo
    ldrlo   r3, [r0], #4
    strlo   r3, [r1], #4
    blo     1b

    /* zero fill .bss */
    ldr     r0, =_sbss
    ldr     r1, =_ebss
    movs    r3, #0
2:  cmp     r0, r1
    it      lo
    strlo   r3, [r0], #4
    blo     2b

    bl      main
    bx      lr

    .section .text.Default_Handler,"ax",%progbits
    .weak NMI_Handler
    .thumb_set NMI_Handler, Default_Handler

    .weak HardFault_Handler
    .thumb_set HardFault_Handler, Default_Handler

    .weak MemManage_Handler
    .thumb_set MemManage_Handler, Default_Handler

    .weak BusFault_Handler
    .thumb_set BusFault_Handler, Default_Handler

    .weak UsageFault_Handler
    .thumb_set UsageFault_Handler, Default_Handler

    .weak SVC_Handler
    .thumb_set SVC_Handler, Default_Handler

    .weak DebugMon_Handler
    .thumb_set DebugMon_Handler, Default_Handler

    .weak PendSV_Handler
    .thumb_set PendSV_Handler, Default_Handler

    .weak SysTick_Handler
    .thumb_set SysTick_Handler, Default_Handler

    .weak WWDGT_IRQHandler
    .thumb_set WWDGT_IRQHandler, Default_Handler

    .weak LVD_IRQHandler
    .thumb_set LVD_IRQHandler, Default_Handler

    .weak TAMPER_IRQHandler
    .thumb_set TAMPER_IRQHandler, Default_Handler

    .weak RTC_IRQHandler
    .thumb_set RTC_IRQHandler, Default_Handler

    .weak FMC_IRQHandler
    .thumb_set FMC_IRQHandler, Default_Handler

    .weak RCU_CTC_IRQHandler
    .thumb_set RCU_CTC_IRQHandler, Default_Handler

    .weak EXTI0_IRQHandler
    .thumb_set EXTI0_IRQHandler, Default_Handler

    .weak EXTI1_IRQHandler
    .thumb_set EXTI1_IRQHandler, Default_Handler

    .weak EXTI2_IRQHandler
    .thumb_set EXTI2_IRQHandler, Default_Handler

    .weak EXTI3_IRQHandler
    .thumb_set EXTI3_IRQHandler, Default_Handler

    .weak EXTI4_IRQHandler
    .thumb_set EXTI4_IRQHandler, Default_Handler

    .weak DMA0_Channel0_IRQHandler
    .thumb_set DMA0_Channel0_IRQHandler, Default_Handler

    .weak DMA0_Channel1_IRQHandler
    .thumb_set DMA0_Channel1_IRQHandler, Default_Handler

    .weak DMA0_Channel2_IRQHandler
    .thumb_set DMA0_Channel2_IRQHandler, Default_Handler

    .weak DMA0_Channel3_IRQHandler
    .thumb_set DMA0_Channel3_IRQHandler, Default_Handler

    .weak DMA0_Channel4_IRQHandler
    .thumb_set DMA0_Channel4_IRQHandler, Default_Handler

    .weak DMA0_Channel5_IRQHandler
    .thumb_set DMA0_Channel5_IRQHandler, Default_Handler

    .weak DMA0_Channel6_IRQHandler
    .thumb_set DMA0_Channel6_IRQHandler, Default_Handler

    .weak ADC0_1_IRQHandler
    .thumb_set ADC0_1_IRQHandler, Default_Handler

    .weak USBD_HP_CAN0_TX_IRQHandler
    .thumb_set USBD_HP_CAN0_TX_IRQHandler, Default_Handler

    .weak USBD_LP_CAN0_RX0_IRQHandler
    .thumb_set USBD_LP_CAN0_RX0_IRQHandler, Default_Handler

    .weak CAN0_RX1_IRQHandler
    .thumb_set CAN0_RX1_IRQHandler, Default_Handler

    .weak CAN0_EWMC_IRQHandler
    .thumb_set CAN0_EWMC_IRQHandler, Default_Handler

    .weak EXTI5_9_IRQHandler
    .thumb_set EXTI5_9_IRQHandler, Default_Handler

    .weak TIMER0_BRK_IRQHandler
    .thumb_set TIMER0_BRK_IRQHandler, Default_Handler

    .weak TIMER0_UP_IRQHandler
    .thumb_set TIMER0_UP_IRQHandler, Default_Handler

    .weak TIMER0_TRG_CMT_IRQHandler
    .thumb_set TIMER0_TRG_CMT_IRQHandler, Default_Handler

    .weak TIMER0_Channel_IRQHandler
    .thumb_set TIMER0_Channel_IRQHandler, Default_Handler

    .weak TIMER1_IRQHandler
    .thumb_set TIMER1_IRQHandler, Default_Handler

    .weak TIMER2_IRQHandler
    .thumb_set TIMER2_IRQHandler, Default_Handler

    .weak TIMER3_IRQHandler
    .thumb_set TIMER3_IRQHandler, Default_Handler

    .weak I2C0_EV_IRQHandler
    .thumb_set I2C0_EV_IRQHandler, Default_Handler

    .weak I2C0_ER_IRQHandler
    .thumb_set I2C0_ER_IRQHandler, Default_Handler

    .weak I2C1_EV_IRQHandler
    .thumb_set I2C1_EV_IRQHandler, Default_Handler

    .weak I2C1_ER_IRQHandler
    .thumb_set I2C1_ER_IRQHandler, Default_Handler

    .weak SPI0_IRQHandler
    .thumb_set SPI0_IRQHandler, Default_Handler

    .weak SPI1_IRQHandler
    .thumb_set SPI1_IRQHandler, Default_Handler

    .weak USART0_IRQHandler
    .thumb_set USART0_IRQHandler, Default_Handler

    .weak USART1_IRQHandler
    .thumb_set USART1_IRQHandler, Default_Handler

    .weak USART2_IRQHandler
    .thumb_set USART2_IRQHandler, Default_Handler

    .weak EXTI10_15_IRQHandler
    .thumb_set EXTI10_15_IRQHandler, Default_Handler

    .weak RTC_Alarm_IRQHandler
    .thumb_set RTC_Alarm_IRQHandler, Default_Handler

    .weak USBD_WKUP_IRQHandler
    .thumb_set USBD_WKUP_IRQHandler, Default_Handler

    .weak TIMER7_BRK_IRQHandler
    .thumb_set TIMER7_BRK_IRQHandler, Default_Handler

    .weak TIMER7_UP_IRQHandler
    .thumb_set TIMER7_UP_IRQHandler, Default_Handler

    .weak TIMER7_TRG_CMT_IRQHandler
    .thumb_set TIMER7_TRG_CMT_IRQHandler, Default_Handler

    .weak TIMER7_Channel_IRQHandler
    .thumb_set TIMER7_Channel_IRQHandler, Default_Handler

    .weak ADC2_IRQHandler
    .thumb_set ADC2_IRQHandler, Default_Handler

    .weak EXMC_IRQHandler
    .thumb_set EXMC_IRQHandler, Default_Handler

    .weak SDIO_IRQHandler
    .thumb_set SDIO_IRQHandler, Default_Handler

    .weak TIMER4_IRQHandler
    .thumb_set TIMER4_IRQHandler, Default_Handler

    .weak SPI2_IRQHandler
    .thumb_set SPI2_IRQHandler, Default_Handler

    .weak UART3_IRQHandler
    .thumb_set UART3_IRQHandler, Default_Handler

    .weak UART4_IRQHandler
    .thumb_set UART4_IRQHandler, Default_Handler

    .weak TIMER5_IRQHandler
    .thumb_set TIMER5_IRQHandler, Default_Handler

    .weak TIMER6_IRQHandler
    .thumb_set TIMER6_IRQHandler, Default_Handler

    .weak DMA1_Channel0_IRQHandler
    .thumb_set DMA1_Channel0_IRQHandler, Default_Handler

    .weak DMA1_Channel1_IRQHandler
    .thumb_set DMA1_Channel1_IRQHandler, Default_Handler

    .weak DMA1_Channel2_IRQHandler
    .thumb_set DMA1_Channel2_IRQHandler, Default_Handler

    .weak DMA1_Channel3_4_IRQHandler
    .thumb_set DMA1_Channel3_4_IRQHandler, Default_Handler

    .type Default_Handler, %function
Default_Handler:
    b       .
