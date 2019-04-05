; Multiplication macros for field elements (integers modulo 2^255 - 19)
;
; Author: Amber Sprenkels <amber@electricdusk.com>

%ifndef FE10X4_SQUARE_ASM_
%define FE10X4_SQUARE_ASM_

%include "fe10x4_carry.asm"

%macro fe10x4_square_body 2
    ; The squaring operations in this routine is based on the multiplication in fe10x4_mul.asm
    ; Tl;dr. We precompute in parallel:
    ;   - (19*f_5, ..., 19*f_9)
    ;   - (2*f_1, 2*f_3, ... 2*f_7)
    ; Then we do a regular O(n^2) modular squaring.
    ; 
    ; Inputs:
    ;   - %1: Operand `f`
    ;   - %2: 64 bytes of usable stack space
    ;
    ; Output:
    ;   - ymm{0-9}: Result `h`
    ;
    %push fe10x4_square_body_ctx
    
    %xdefine f19_8 %2 + 0*32
    %xdefine f19_9 %2 + 1*32
    
    ; round 1/10
    vmovdqa ymm15, yword [%1 + 0*32]            ; load f[0]
    vpmuludq ymm0, ymm15, ymm15
    vpaddq ymm15, ymm15, ymm15                  ; compute 2*f[0]
    vpmuludq ymm1, ymm15, yword [%1 + 1*32]
    vpmuludq ymm2, ymm15, yword [%1 + 2*32]
    vpmuludq ymm3, ymm15, yword [%1 + 3*32]
    vpmuludq ymm4, ymm15, yword [%1 + 4*32]
    vpmuludq ymm5, ymm15, yword [%1 + 5*32]
    vpmuludq ymm6, ymm15, yword [%1 + 6*32]
    vpmuludq ymm7, ymm15, yword [%1 + 7*32]
    vpmuludq ymm8, ymm15, yword [%1 + 8*32]
    vpmuludq ymm9, ymm15, yword [%1 + 9*32]

    ; round 2/10
    vmovdqa ymm14, yword [%1 + 1*32]            ; load f[1]
    vpaddq ymm15, ymm14, ymm14                  ; compute 2*f[1]
    vpbroadcastq ymm13, qword [rel .const_19]
    vpmuludq ymm12, ymm13, yword [%1 + 9*32]    ; compute 19*f[9]
    vmovdqa yword [f19_9], ymm12                ; spill 19*f[9]

    vpmuludq ymm10, ymm15, ymm14
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [%1 + 2*32]
    vpaddq ymm3, ymm3, ymm10
    vpaddq ymm14, ymm15, ymm15                  ; compute 4*f[1]
    vpmuludq ymm10, ymm14, yword [%1 + 3*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [%1 + 4*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm14, yword [%1 + 5*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [%1 + 6*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm14, yword [%1 + 7*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [%1 + 8*32]
    vpaddq ymm9, ymm9, ymm10
    vpmuludq ymm10, ymm14, ymm12
    vpaddq ymm0, ymm0, ymm10
    
    ; round 3/10
    vmovdqa ymm15, yword [%1 + 2*32]            ; load f[2]
    vpmuludq ymm11, ymm13, yword [%1 + 8*32]    ; compute 19*f[8]
    vmovdqa yword [f19_8], ymm11                ; spill 19*f[8]

    vpmuludq ymm10, ymm15, ymm15
    vpaddq ymm4, ymm4, ymm10
    vpaddq ymm15, ymm15, ymm15                  ; compute 2*f[2]
    vpmuludq ymm10, ymm15, yword [%1 + 3*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm15, yword [%1 + 4*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [%1 + 5*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm15, yword [%1 + 6*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [%1 + 7*32]
    vpaddq ymm9, ymm9, ymm10
    vpmuludq ymm10, ymm15, ymm11
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm12
    vpaddq ymm1, ymm1, ymm10
    
    ; round 4/10
    vmovdqa ymm14, yword [%1 + 3*32]            ; load f[3]
    vpaddq ymm15, ymm14, ymm14                  ; compute 2*f[3]
    vpmuludq ymm11, ymm13, yword [%1 + 7*32]    ; compute 19*f[7]
    
    vpmuludq ymm10, ymm15, ymm14
    vpaddq ymm6, ymm6, ymm10
    vpaddq ymm14, ymm15, ymm15                  ; compute 4*f[3]
    vpmuludq ymm10, ymm15, yword [%1 + 4*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm14, yword [%1 + 5*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [%1 + 6*32]
    vpaddq ymm9, ymm9, ymm10
    vpmuludq ymm10, ymm14, ymm11
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, yword [f19_8]
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm14, ymm12
    vpaddq ymm2, ymm2, ymm10
    
    ; round 5/10
    vmovdqa ymm15, yword [%1 + 4*32]            ; load f[4]
    vpmuludq ymm14, ymm13, yword [%1 + 6*32]    ; compute 19*f[6]
    
    vpmuludq ymm10, ymm15, ymm15
    vpaddq ymm8, ymm8, ymm10
    vpaddq ymm15, ymm15, ymm15                  ; compute 2*f[4]
    vpmuludq ymm10, ymm15, yword [%1 + 5*32]
    vpaddq ymm9, ymm9, ymm10
    vpmuludq ymm10, ymm15, ymm14
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm11
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm15, yword [f19_8]
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, ymm12
    vpaddq ymm3, ymm3, ymm10
    
    ; round 6/10
    vmovdqa ymm15, yword [%1 + 5*32]            ; load f[5]
    vpmuludq ymm13, ymm13, ymm15                ; compute 19*f[5]
    vpaddq ymm15, ymm15, ymm15                  ; compute 2*f[5]
    
    vpmuludq ymm10, ymm15, ymm13
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm14
    vpaddq ymm1, ymm1, ymm10
    vpaddq ymm13, ymm15, ymm15                  ; compute 4*f[5]
    vpmuludq ymm10, ymm13, ymm11
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [f19_8]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm13, ymm12
    vpaddq ymm4, ymm4, ymm10
    
    ; round 7/10
    vmovdqa ymm15, yword [%1 + 6*32]            ; load f[6]
    
    vpmuludq ymm10, ymm15, ymm14
    vpaddq ymm2, ymm2, ymm10
    vpaddq ymm15, ymm15, ymm15                  ; compute 2*f[6]
    vpmuludq ymm10, ymm15, ymm11
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm15, yword [f19_8]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, ymm12
    vpaddq ymm5, ymm5, ymm10
    
    ; round 8/10
    vmovdqa ymm15, yword [%1 + 7*32]            ; load f[7]
    vpaddq ymm15, ymm15, ymm15                  ; compute 2*f[7]
    
    vpmuludq ymm10, ymm15, ymm11
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [f19_8]
    vpaddq ymm5, ymm5, ymm10
    vpaddq ymm15, ymm15, ymm15                  ; compute 4*f[7]
    vpmuludq ymm10, ymm15, ymm12
    vpaddq ymm6, ymm6, ymm10
    
    ; round 9/10
    vmovdqa ymm15, yword [%1 + 8*32]            ; load f[8]
    
    vpmuludq ymm10, ymm15, yword [f19_8]
    vpaddq ymm6, ymm6, ymm10
    vpaddq ymm15, ymm15, ymm15                  ; compute 2*f[8]
    vpmuludq ymm10, ymm15, ymm12
    vpaddq ymm7, ymm7, ymm10
    
    ; round 10/10
    vpmuludq ymm10, ymm12, yword [%1 + 9*32]    ; compute f[9]*(19*f[9])
    vpaddq ymm10, ymm10, ymm10                  ; 38*f[9]*f[9]
    vpaddq ymm8, ymm8, ymm10

    %pop fe10x4_square_body_ctx
%endmacro

%macro fe10x4_square 3
    %push fe10x4_square_ctx
    
    fe10x4_square_body %2, %3
    fe10x4_carry_body
    fe10x4_carry_store %1
    
    %pop fe10x4_square_ctx
%endmacro

%macro fe10x4_square_consts 0
    ; The other macros in this file are dependent on this constant. If
    ; you call the other macros in this file, define these values after
    ; your call in the .rodata section.

    align 8, db 0
    .const_19: dq 19
%endmacro

%endif
