; Point doubling for E : y^2 = x^3 - 3*x + 13318 (test)
;
; Author: Amber Sprenkels <amber@electricdusk.com>

global crypto_scalarmult_curve13318_avx2_ge_double_asm

%include "ge_double.asm"

section .text

crypto_scalarmult_curve13318_avx2_ge_double_asm:
    ; Double a point on the curve
    ;
    ; Inputs:
    ;   - [rsi]: Only operand -- ( x : y : z )
    ;
    ; Output:
    ;   - [rdi]: Sum of the two inputs -- ( x3 : y3 : z3 )
    ;
    ; This doubling routine is based on Algorithm 3 from the
    ; Renes-Costello-Batina addition formulas. Instead, we use the Karatsuba
    ; trick to compute `v7 = 2XZ = (X + Z)^2 - X^2 - Y^2 = (X + Z)^2 - v1 - v3`.
    ;
    push r10
    push r11
    push r12
    push rbp
    mov rbp, rsp
    and rsp, -32
    sub rsp, 5*10*32
    
    ge_double rdi, rsi, rsp
    
    mov rsp, rbp
    pop rbp
    pop r12
    pop r11
    pop r10
    ret
    
section .rodata

ge_double_consts
fe10x4_square_consts
fe10x4_carry_consts
