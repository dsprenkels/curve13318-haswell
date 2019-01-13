; Multiplication macros for field elements (integers modulo 2^255 - 19)
;
; Author: Amber Sprenkels <amber@electricdusk.com>

%ifndef FE10X4_MUL_ASM_
%define FE10X4_MUL_ASM_

%include "fe10x4_carry.asm"

%macro fe10x4_mul_body 3
    ; The multipliction in this routine is based on the multiplication as described in [NeonCrypto].
    ; Tl;dr. We precompute in parallel:
    ;   - (19*g_1, ..., 19*g_9)
    ;   - (2*f_1, 2*f_3, ... 2*f_9)
    ; Then we do a regular O(n^2) modular multiplication.
    ; 
    ; Inputs:
    ;   - %1: Operand `f`
    ;   - %2: Operand `g`
    ;   - %3: 224 bytes of usable stack space
    ;
    ; Useful reciprocal throughputs:
    ;   - pmuludq:     1.0 cycle @ p0
    ;   - paddq/psubq: 0.5 cycle @ p15
    ;   - psllq:       1.0 cycle @ p0
    ; ^ We see that uops from vpmuludq/vpsllq collide on port 0. vpmuludq is a lot more powerful,
    ;   so we don't need to use it, unless p23 pressure or latency is relevant at some point.
    ;
    ; Analysis of op counts:
    ;   - n^2 multiplications: 100 vpmuludq
    ;   - *19 precomputation:    9 vpmuludq
    ;   - accumulate:           90 vpaddq/vpsubq
    ;   - add precomputation:    5 vpaddq/vpsubq
    ;   = 109*p0 + 47.5*p15
    ; An addition chain to 19:
    ;   - 1 -> 2 -> 4 (-> 3) -> 8 -> 16 -> 19: 6 paddq/psubq = 3*p15
    ;   - If we do 9 of these chains, instead of their respective pmuludq's, we get:
    ;   = 100*p0 + 74.5*p15
    ; However, the instruction bandwith of the Haswell front-end seems to be too slow to keep up
    ; with the flow of all the vpaddq's. So we will do the (*19) op using a vpmuludq.
    ;
    ; TODO(dsprenkels) We must benchmark if this is actually better inside the ge_* routines.
    ;
    %push fe10x4_mul_body_ctx
    
    ; round 1/10
    vmovdqa ymm15, yword [%1 + 0*32]
    vpmuludq ymm0, ymm15, yword [%2 + 0*32]
    vpmuludq ymm1, ymm15, yword [%2 + 1*32]
    vpmuludq ymm2, ymm15, yword [%2 + 2*32]
    vpmuludq ymm3, ymm15, yword [%2 + 3*32]
    vpmuludq ymm4, ymm15, yword [%2 + 4*32]
    vpmuludq ymm5, ymm15, yword [%2 + 5*32]
    vpmuludq ymm6, ymm15, yword [%2 + 6*32]
    vpmuludq ymm7, ymm15, yword [%2 + 7*32]
    vpmuludq ymm8, ymm15, yword [%2 + 8*32]
    vpmuludq ymm9, ymm15, yword [%2 + 9*32]

    ; round 2/10
    vmovdqa ymm15, yword [%1 + 1*32]            ; load f[1]
    vpaddq ymm14, ymm15, ymm15                  ; compute 2*f[1]
    vmovdqa ymm13, yword [rel .const_19]
    vpmuludq ymm12, ymm13, yword [%2 + 9*32]    ; compute 19*g[9]
    vmovdqa yword [%3 + 6*32], ymm12           ; spill 19*g[9]

    vpmuludq ymm10, ymm14, ymm12
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, yword [%2 + 0*32]
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm14, yword [%2 + 1*32]
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [%2 + 2*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm14, yword [%2 + 3*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [%2 + 4*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm14, yword [%2 + 5*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [%2 + 6*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm14, yword [%2 + 7*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [%2 + 8*32]
    vpaddq ymm9, ymm9, ymm10

    ; round 3/10
    vmovdqa ymm15, yword [%1 + 2*32]            ; load f[2]
    vpmuludq ymm11, ymm13, yword [%2 + 8*32]    ; compute 19*g[8]
    vmovdqa yword [%3 + 5*32], ymm11           ; spill 19*g[8]

    vpmuludq ymm10, ymm15, ymm11
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm12
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm15, yword [%2 + 0*32]
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [%2 + 1*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm15, yword [%2 + 2*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [%2 + 3*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm15, yword [%2 + 4*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [%2 + 5*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm15, yword [%2 + 6*32]
    vpaddq ymm8, ymm8, ymm10    
    vpmuludq ymm10, ymm15, yword [%2 + 7*32]
    vpaddq ymm9, ymm9, ymm10

    ; Round 4/10
    vmovdqa ymm15, yword [%1 + 3*32]            ; load f[3]
    vpaddq ymm14, ymm15, ymm15                  ; compute 2*f[3]             
    vpmuludq ymm12, ymm13, yword [%2 + 7*32]    ; compute 19*g[7]
    vmovdqa yword [%3 + 4*32], ymm12           ; spill 19*g[7]

    vpmuludq ymm10, ymm14, ymm12
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm11
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm14, yword [%3 + 6*32]
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [%2 + 0*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm14, yword [%2 + 1*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [%2 + 2*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm14, yword [%2 + 3*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [%2 + 4*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm14, yword [%2 + 5*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [%2 + 6*32]
    vpaddq ymm9, ymm9, ymm10

    ; Round 5/10
    vmovdqa ymm15, yword [%1 + 4*32]            ; load f[4]
    vpmuludq ymm11, ymm13, yword [%2 + 6*32]    ; compute 19*g[6]
    vmovdqa yword [%3 + 3*32], ymm11           ; spill 19*g[6]

    vpmuludq ymm10, ymm15, ymm11
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm12
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm15, yword [%3 + 5*32]
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [%3 + 6*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm15, yword [%2 + 0*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [%2 + 1*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm15, yword [%2 + 2*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [%2 + 3*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm15, yword [%2 + 4*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [%2 + 5*32]
    vpaddq ymm9, ymm9, ymm10

    ; Round 6/10
    vmovdqa ymm15, yword [%1 + 5*32]            ; load f[5]
    vpaddq ymm14, ymm15, ymm15                  ; compute 2*f[5]         
    vpmuludq ymm12, ymm13, yword [%2 + 5*32]    ; compute 19*g[5] 
    vmovdqa yword [%3 + 2*32], ymm12           ; spill 19*g[5]

    vpmuludq ymm10, ymm14, ymm12
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm11
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm14, yword [%3 + 4*32]
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [%3 + 5*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm14, yword [%3 + 6*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [%2 + 0*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm14, yword [%2 + 1*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [%2 + 2*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm14, yword [%2 + 3*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [%2 + 4*32]
    vpaddq ymm9, ymm9, ymm10

    ; Round 7/10
    vmovdqa ymm15, yword [%1 + 6*32]            ; load f[6]
    vpmuludq ymm11, ymm13, yword [%2 + 4*32]    ; compute 19*g[4]
    vmovdqa yword [%3 + 1*32], ymm11           ; spill 19*g[4]

    vpmuludq ymm10, ymm15, ymm11
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm12
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm15, yword [%3 + 3*32]
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [%3 + 4*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm15, yword [%3 + 5*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [%3 + 6*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm15, yword [%2 + 0*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [%2 + 1*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm15, yword [%2 + 2*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [%2 + 3*32]
    vpaddq ymm9, ymm9, ymm10

    ; Round 8/10
    vmovdqa ymm15, yword [%1 + 7*32]            ; load f[7]
    vpaddq ymm14, ymm15, ymm15                  ; compute 2*f[7]         
    vpmuludq ymm12, ymm13, yword [%2 + 3*32]    ; compute 19*g[8]
    vmovdqa yword [%3 + 0*32], ymm12

    vpmuludq ymm10, ymm14, ymm12
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm11
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm14, yword [%3 + 2*32]
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [%3 + 3*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm14, yword [%3 + 4*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [%3 + 5*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm14, yword [%3 + 6*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [%2 + 0*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm14, yword [%2 + 1*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [%2 + 2*32]
    vpaddq ymm9, ymm9, ymm10

    ; Round 9/10
    vmovdqa ymm15, yword [%1 + 8*32]            ; load f[8]
    vpmuludq ymm11, ymm13, yword [%2 + 2*32]    ; compute 19*g[2]

    vpmuludq ymm10, ymm15, ymm11
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm12
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm15, yword [%3 + 1*32]
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [%3 + 2*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm15, yword [%3 + 3*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [%3 + 4*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm15, yword [%3 + 5*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [%3 + 6*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm15, yword [%2 + 0*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [%2 + 1*32]
    vpaddq ymm9, ymm9, ymm10

    ; Round 10/10
    vmovdqa ymm15, yword [%1 + 9*32]            ; load f[9]
    vpaddq ymm14, ymm15, ymm15                  ; compute 2*f[9]         
    vpmuludq ymm12, ymm13, yword [%2 + 1*32]    ; compute 19*g[1]

    vpmuludq ymm10, ymm14, ymm12
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm11
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm14, yword [%3 + 0*32]
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [%3 + 1*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm14, yword [%3 + 2*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [%3 + 3*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm14, yword [%3 + 4*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [%3 + 5*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm14, yword [%3 + 6*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [%2 + 0*32]
    vpaddq ymm9, ymm9, ymm10
    
    %pop fe10x4_mul_body_ctx
%endmacro

%macro fe10x4_mul 4
    %push fe10x4_mul_ctx
    
    fe10x4_mul_body %2, %3, %4
    fe10x4_carry_body
    fe10x4_carry_store %1
    
    %pop fe10x4_mul_ctx
% error
%endmacro

%macro fe10x4_mul_consts 0
    ; The other macros in this file are dependent on this constant. If
    ; you call the other macros in this file, define these values after
    ; your call in the .rodata section.

    align 32, db 0
    .const_19: times 4 dq 19
%endmacro

%endif
