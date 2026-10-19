/* GD32F303ZE (GD32F303ZET6) 链接脚本
   Cortex-M4 @120MHz, 512KB Flash @0x08000000, 64KB SRAM @0x20000000
   与 Arm/startup_gd32f30x_hd.s 配套使用（_estack/_sidata/_sdata/_edata/_sbss/_ebss）*/

ENTRY(Reset_Handler)

MEMORY
{
  FLASH (rx)  : ORIGIN = 0x08000000, LENGTH = 512K
  RAM   (rwx) : ORIGIN = 0x20000000, LENGTH = 64K
}

/* 栈顶：SRAM 末尾 0x20010000 */
_estack = ORIGIN(RAM) + LENGTH(RAM);

SECTIONS
{
  /* 中断向量表必须位于 Flash 起始处 */
  .isr_vector :
  {
    . = ALIGN(4);
    KEEP(*(.isr_vector))
    . = ALIGN(4);
  } > FLASH

  .text :
  {
    . = ALIGN(4);
    *(.text.Reset_Handler)        /* 复位入口放最前 */
    *(.text*)
    *(.rodata*)
    KEEP(*(.init))
    KEEP(*(.fini))

    . = ALIGN(4);
    _etext = .;
  } > FLASH

  /* C++ 异常展开表（当前纯 C 工程为空，保留以防万一）*/
  .ARM.extab :
  {
    *(.ARM.extab* .gnu.linkonce.armextab.*)
  } > FLASH

  .ARM.exidx :
  {
    __exidx_start = .;
    *(.ARM.exidx* .gnu.linkonce.armexidx.*)
    __exidx_end = .;
  } > FLASH

  /* .data：运行在 SRAM，初值保存在 FLASH（LMA = _etext）*/
  _sidata = LOADADDR(.data);

  .data :
  {
    . = ALIGN(4);
    _sdata = .;
    *(.data*)
    . = ALIGN(4);
    _edata = .;
  } > RAM AT > FLASH

  .bss (NOLOAD) :
  {
    . = ALIGN(4);
    _sbss = .;
    *(.bss*)
    *(COMMON)
    . = ALIGN(4);
    _ebss = .;
  } > RAM

  /* 预留堆（实现 _sbrk 时使用；当前工程未用 malloc 可不实现）*/
  .heap_stacksection (NOLOAD) :
  {
    . = ALIGN(8);
    _heap_start = .;
    . = . + 0x400;                /* 1KB 堆 */
    _heap_end = .;
    . = ALIGN(8);
  } > RAM

  /* 丢弃调试信息等无用段，减小镜像 */
  /DISCARD/ :
  {
    *(.note*)
    *(.comment*)
  }
}
