; Test functions for fe10_carry.asm
;
; Author: Amber Sprenkels <amber@electricdusk.com>

global crypto_scalarmult_curve13318_avx2_fe10x4_carry
global crypto_scalarmult_curve13318_avx2_fe10x4_carry2

%include "fe10x4_carry.asm"

section .text
crypto_scalarmult_curve13318_avx2_fe10x4_carry2:
    fe10x4_carry_load rdi
    fe10x4_carry_body
    fe10x4_carry_store rdi
    ret
    
section .rodata
fe10x4_carry_consts

section .text
crypto_scalarmult_curve13318_avx2_fe10x4_carry:
    fe10x4_carry_load rdi
    fe10x4_carry_body_store rdi
    ret
    
section .rodata
fe10x4_carry_consts
