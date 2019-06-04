; Squaring test for field elements (integers modulo 2^255 - 19)
;
; Author: Amber Sprenkels <amber@electricdusk.com>

global crypto_scalarmult_curve13318_avx2_fe10x4_square_asm

%include "fe10x4_square.mac.asm"

crypto_scalarmult_curve13318_avx2_fe10x4_square_asm:
    push rbp
    mov rbp, rsp
    and rsp, -32
    sub rsp, 2*32

    fe10x4_square_body rsi, rsp

    vmovdqa yword [rdi + 0*32], ymm0
    vmovdqa yword [rdi + 1*32], ymm1
    vmovdqa yword [rdi + 2*32], ymm2
    vmovdqa yword [rdi + 3*32], ymm3
    vmovdqa yword [rdi + 4*32], ymm4
    vmovdqa yword [rdi + 5*32], ymm5
    vmovdqa yword [rdi + 6*32], ymm6
    vmovdqa yword [rdi + 7*32], ymm7
    vmovdqa yword [rdi + 8*32], ymm8
    vmovdqa yword [rdi + 9*32], ymm9

    mov rsp, rbp
    pop rbp
    ret

section .rodata:
fe10x4_square_consts