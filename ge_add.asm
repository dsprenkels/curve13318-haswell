; Curve addition for E : y^2 = x^3 - 3*x + 13318 (test)
;
; Author: Amber Sprenkels <amber@electricdusk.com>

global crypto_scalarmult_curve13318_avx2_ge_add_asm

%include "ge_add.mac.asm"

section .text

crypto_scalarmult_curve13318_avx2_ge_add_asm:
    ; Add two points on the curve
    ;
    ; Inputs:
    ;   - [rsi]: First operand -- ( x1 : y1 : z1 )
    ;   - [rdx]: Second operand -- ( x2 : y2 : z2 )
    ;
    ; Output:
    ;   - [rdi]: Sum of the two inputs
    ;
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push rbp
    mov rbp, rsp
    and rsp, -32
    sub rsp, 6*10*32
    
    ge_add rdi, rsi, rdx, rsp
    
    mov rsp, rbp
    pop rbp
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    ret

section .rodata
ge_add_consts
fe10x4_mul_consts
fe10x4_carry_consts
