/*!
    \file    syscalls.c
    \brief   newlib(nano) 系统调用桩，让 printf/puts 等 libc 函数可用

    \note    EIDE 工程选项"使用系统调用"(--specs=nosys.specs)必须保持关闭
             (.eide/eide.yml: not-use-syscalls: false)，否则会与这里的定义重复。
             _write  -> 调用 Driver/usart.c 的 usart_send（串口见 usart.h）
             _sbrk   -> 链接脚本 Arm/gd32f303ze.ld 预留的堆(_heap_start/_heap_end)
*/
#include <stdio.h>
#include <errno.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#include "usart.h"

/* 链接脚本中预留的堆边界 */
extern char _heap_start;
extern char _heap_end;

/*!
    \brief      write to file descriptor, retarget to debug UART
    \param[in]  fd: file descriptor (1=stdout, 2=stderr)
    \param[in]  ptr: buffer
    \param[in]  len: length
    \param[out] none
    \retval     length written, -1 on error
*/
int _write(int fd, char *ptr, int len)
{
    if((STDOUT_FILENO != fd) && (STDERR_FILENO != fd)){
        errno = EBADF;
        return -1;
    }

    usart_send((const uint8_t *)ptr, (uint16_t)len);

    return len;
}

/*!
    \brief      read from file descriptor (not implemented)
*/
int _read(int fd, char *ptr, int len)
{
    (void)fd;
    (void)ptr;
    (void)len;
    return 0;
}

/*!
    \brief      close file descriptor (not implemented)
*/
int _close(int fd)
{
    (void)fd;
    return -1;
}

/*!
    \brief      seek in file (not implemented)
*/
off_t _lseek(int fd, off_t offset, int whence)
{
    (void)fd;
    (void)offset;
    (void)whence;
    return -1;
}

/*!
    \brief      status of file descriptor: treat as character device
*/
int _fstat(int fd, struct stat *st)
{
    if(NULL == st){
        errno = EBADF;
        return -1;
    }
    st->st_mode = S_IFCHR;
    return 0;
}

/*!
    \brief      query if file descriptor is a tty
*/
int _isatty(int fd)
{
    (void)fd;
    return 1;
}

/*!
    \brief      get process id (dummy)
*/
int _getpid(void)
{
    return 1;
}

/*!
    \brief      send signal to process (not implemented)
*/
int _kill(int pid, int sig)
{
    (void)pid;
    (void)sig;
    errno = EINVAL;
    return -1;
}

/*!
    \brief      heap allocation for malloc, use the heap reserved in linker script
    \param[in]  incr: increment in bytes
    \param[out] none
    \retval     pointer to allocated block, (void *)-1 on error
*/
void *_sbrk(int incr)
{
    static char *heap_ptr = NULL;
    char *prev_ptr;

    if(NULL == heap_ptr){
        heap_ptr = &_heap_start;
    }
    prev_ptr = heap_ptr;

    if((heap_ptr + incr) > &_heap_end){
        errno = ENOMEM;
        return (void *)-1;
    }
    heap_ptr += incr;

    return (void *)prev_ptr;
}
