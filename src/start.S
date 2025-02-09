/* SPDX-License-Identifier: MIT */

#define UART_BASE 0x20a0a0000
#define UTRSTAT 0x010
#define UTXH 0x020

.extern _start_c
.extern _stack_bot

.section .init, "ax"

.globl _start
.type _start, @function
_start:
    mov x9, x0

    mov w0, 'm'
    bl debug_putc
    
    mov w0, '1'
    bl debug_putc

    adrp x1, _stack_bot
    mov sp, x1
    
    mov w0, 'n'
    bl debug_putc

    adrp x0, _base
    mov x10, x0
    adrp x1, _rela_start
    add x1, x1, :lo12:_rela_start
    adrp x2, _rela_end
    add x2, x2, :lo12:_rela_end
    bl apply_rela

    mov w0, '1'
    bl debug_putc
    mov w0, 0xd /* '\r', clang compat */
    bl debug_putc
    mov w0, '\n'
    bl debug_putc
    
    mrs x8, CurrentEL
    cmp x8, #0xc
    beq start_el3

    mov x0, x9
    mov x1, x10
    bl _start_c
    b .

start_el3:
    adrp x8, _stack_bot_el3
    mov sp, x8
    mov x0, x9
    mov x1, x10
    msr tpidr_el3, xzr
    adrp x6, _stack_bot
    adr x7, _start_c
    b el3_eret_to_el1

el3_eret_to_el1:
    adr x8, _start /* What is the right addresss here? */
    msr sctlr_el1, xzr

    mrs x8, scr_el3
    orr x8, x8, #(1<<10) // EL1 execution state is AArch64
    orr x8, x8, #(1<<0)  // EL1 is non-secure
    msr scr_el3, x8
    msr elr_el3, x7 // Set EL1 entry point
    mov x8, #0x5 // EL1h
    msr spsr_el3, x8

    msr sp_el1, x6 // Set EL1 stack pointer

    eret

.globl debug_putc
.type debug_putc, @function
debug_putc:
    ldr x1, =UART_BASE

1:
    ldr w2, [x1, UTRSTAT]
    tst w2, #2
    beq 1b
    str w0, [x1, UTXH]
    ret

.pool
