; 4x vectorized carry ripple implementation for integers modulo 2^255 - 19
;
; Author: Amber Sprenkels <amber@electricdusk.com>

%ifndef FE10_CARRY_
%define FE10_CARRY_

%macro fe10x4_carry_load 1
    ; load field element
    vmovdqa ymm0, yword [%1 + 0*32]
    vmovdqa ymm1, yword [%1 + 1*32]
    vmovdqa ymm2, yword [%1 + 2*32]
    vmovdqa ymm3, yword [%1 + 3*32]
    vmovdqa ymm4, yword [%1 + 4*32]
    vmovdqa ymm5, yword [%1 + 5*32]
    vmovdqa ymm6, yword [%1 + 6*32]
    vmovdqa ymm7, yword [%1 + 7*32]
    vmovdqa ymm8, yword [%1 + 8*32]
    vmovdqa ymm9, yword [%1 + 9*32]
%endmacro

%macro fe10x4_carry_store 1
    ; store field element
    vmovdqa yword [%1 + 0*32], ymm0
    vmovdqa yword [%1 + 1*32], ymm1
    vmovdqa yword [%1 + 2*32], ymm2
    vmovdqa yword [%1 + 3*32], ymm3
    vmovdqa yword [%1 + 4*32], ymm4
    vmovdqa yword [%1 + 5*32], ymm5
    vmovdqa yword [%1 + 6*32], ymm6
    vmovdqa yword [%1 + 7*32], ymm7
    vmovdqa yword [%1 + 8*32], ymm8
    vmovdqa yword [%1 + 9*32], ymm9
%endmacro

%macro fe10x4_carry_body 0
    ; Do a double interleaved carry ripple:
    ;
    ; - Ripple a: h0 -> h1 -> h2 -> h3 -> h4 -> h5 -> h6
    ; - Ripple b: h5 -> h6 -> h7 -> h8 -> h9 -> h0 -> h1
    ;
    vmovdqa ymm13, yword [rel .MASK26]
    vmovdqa ymm12, yword [rel .MASK25]
    vpsrlq ymm15, ymm0, 26      ; Round 1a
    vpaddq ymm1, ymm1, ymm15
    vpand ymm0, ymm0, ymm13
    vpsrlq ymm15, ymm5, 25      ; Round 1b
    vpaddq ymm6, ymm6, ymm15
    vpand ymm5, ymm5, ymm12
    vpsrlq ymm15, ymm1, 25      ; Round 2a
    vpaddq ymm2, ymm2, ymm15
    vpand ymm1, ymm1, ymm12
    vpsrlq ymm15, ymm6, 26      ; Round 2b
    vpaddq ymm7, ymm7, ymm15
    vpand ymm6, ymm6, ymm13
    vpsrlq ymm15, ymm2, 26      ; Round 3a
    vpaddq ymm3, ymm3, ymm15
    vpand ymm2, ymm2, ymm13
    vpsrlq ymm15, ymm7, 25      ; Round 3b
    vpaddq ymm8, ymm8, ymm15
    vpand ymm7, ymm7, ymm12
    vpsrlq ymm15, ymm3, 25      ; Round 4a
    vpaddq ymm4, ymm4, ymm15
    vpand ymm3, ymm3, ymm12
    vpsrlq ymm15, ymm8, 26      ; Round 4b
    vpaddq ymm9, ymm9, ymm15
    vpand ymm8, ymm8, ymm13
    vpsrlq ymm15, ymm4, 26      ; Round 5a
    vpaddq ymm5, ymm5, ymm15
    vpand ymm4, ymm4, ymm13
    vpsrlq ymm15, ymm9, 25      ; Round 5b
    vpsllq ymm14, ymm15, 4
    vpaddq ymm0, ymm0, ymm14
    vpaddq ymm14, ymm15, ymm15
    vpaddq ymm15, ymm14, ymm15
    vpaddq ymm0, ymm0, ymm15
    vpand ymm9, ymm9, ymm12
    vpsrlq ymm15, ymm5, 25       ; Round 6a
    vpaddq ymm6, ymm6, ymm15
    vpand ymm5, ymm5, ymm12
    vpsrlq ymm15, ymm0, 26       ; Round 6b
    vpaddq ymm1, ymm1, ymm15
    vpand ymm0, ymm0, ymm13
%endmacro

%macro fe10x4_carry_body_store 1
    ; Do a double interleaved carry ripple:
    ;
    ; - Ripple a: h0 -> h1 -> h2 -> h3 -> h4 -> h5 -> h6
    ; - Ripple b: h5 -> h6 -> h7 -> h8 -> h9 -> h0 -> h1
    ;
    vmovdqa ymm13, yword [rel .MASK26]
    vmovdqa ymm12, yword [rel .MASK25]
    vpsrlq ymm15, ymm0, 26      ; Round 1a
    vpaddq ymm1, ymm1, ymm15
    vpand ymm0, ymm0, ymm13
    vpsrlq ymm15, ymm5, 25      ; Round 1b
    vpaddq ymm6, ymm6, ymm15
    vpand ymm5, ymm5, ymm12
    vpsrlq ymm15, ymm1, 25      ; Round 2a
    vpaddq ymm2, ymm2, ymm15
    vpand ymm1, ymm1, ymm12
    vpsrlq ymm15, ymm6, 26      ; Round 2b
    vpaddq ymm7, ymm7, ymm15
    vpand ymm6, ymm6, ymm13
    vpsrlq ymm15, ymm2, 26      ; Round 3a
    vpaddq ymm3, ymm3, ymm15
    vpand ymm2, ymm2, ymm13
    vmovdqa yword [%1 + 2*32], ymm2
    vpsrlq ymm15, ymm7, 25      ; Round 3b
    vpaddq ymm8, ymm8, ymm15
    vpand ymm7, ymm7, ymm12
    vmovdqa yword [%1 + 7*32], ymm7
    vpsrlq ymm15, ymm3, 25      ; Round 4a
    vpaddq ymm4, ymm4, ymm15
    vpand ymm3, ymm3, ymm12
    vmovdqa yword [%1 + 3*32], ymm3
    vpsrlq ymm15, ymm8, 26      ; Round 4b
    vpaddq ymm9, ymm9, ymm15
    vpand ymm8, ymm8, ymm13
    vmovdqa yword [%1 + 8*32], ymm8
    vpsrlq ymm15, ymm4, 26      ; Round 5a
    vpaddq ymm5, ymm5, ymm15
    vpand ymm4, ymm4, ymm13
    vmovdqa yword [%1 + 4*32], ymm4
    vpsrlq ymm15, ymm9, 25      ; Round 5b
    vpsllq ymm14, ymm15, 4
    vpaddq ymm0, ymm0, ymm14
    vpaddq ymm14, ymm15, ymm15
    vpaddq ymm15, ymm14, ymm15
    vpaddq ymm0, ymm0, ymm15
    vpand ymm9, ymm9, ymm12
    vmovdqa yword [%1 + 9*32], ymm9
    vpsrlq ymm15, ymm5, 25       ; Round 6a
    vpaddq ymm6, ymm6, ymm15
    vmovdqa yword [%1 + 6*32], ymm6
    vpand ymm5, ymm5, ymm12
    vmovdqa yword [%1 + 5*32], ymm5
    vpsrlq ymm15, ymm0, 26       ; Round 6b
    vpaddq ymm1, ymm1, ymm15
    vmovdqa yword [%1 + 1*32], ymm1
    vpand ymm0, ymm0, ymm13
    vmovdqa yword [%1 + 0*32], ymm0
%endmacro

%macro fe10x4_carry_body_store_owords 2
    ; Do a double interleaved carry ripple:
    ;
    ; - Ripple a: h0 -> h1 -> h2 -> h3 -> h4 -> h5 -> h6
    ; - Ripple b: h5 -> h6 -> h7 -> h8 -> h9 -> h0 -> h1
    ;    
    vmovdqa ymm13, yword [rel .MASK26]
    vmovdqa ymm12, yword [rel .MASK25]
    vpsrlq ymm15, ymm0, 26      ; Round 1a
    vpaddq ymm1, ymm1, ymm15
    vpand ymm0, ymm0, ymm13
    vpsrlq ymm15, ymm5, 25      ; Round 1b
    vpaddq ymm6, ymm6, ymm15
    vpand ymm5, ymm5, ymm12
    vpsrlq ymm15, ymm1, 25      ; Round 2a
    vpaddq ymm2, ymm2, ymm15
    vpand ymm1, ymm1, ymm12
    vpsrlq ymm15, ymm6, 26      ; Round 2b
    vpaddq ymm7, ymm7, ymm15
    vpand ymm6, ymm6, ymm13
    vpsrlq ymm15, ymm2, 26      ; Round 3a
    vpaddq ymm3, ymm3, ymm15
    vpand ymm2, ymm2, ymm13
    vmovdqa oword [%1 + 2*32], xmm2
    vextracti128 oword [%2 + 2*32], ymm2, 1
    vpsrlq ymm15, ymm7, 25      ; Round 3b
    vpaddq ymm8, ymm8, ymm15
    vpand ymm7, ymm7, ymm12
    vmovdqa oword [%1 + 7*32], xmm7
    vextracti128 oword [%2 + 7*32], ymm7, 1
    vpsrlq ymm15, ymm3, 25      ; Round 4a
    vpaddq ymm4, ymm4, ymm15
    vpand ymm3, ymm3, ymm12
    vmovdqa oword [%1 + 3*32], xmm3
    vextracti128 oword [%2 + 3*32], ymm3, 1
    vpsrlq ymm15, ymm8, 26      ; Round 4b
    vpaddq ymm9, ymm9, ymm15
    vpand ymm8, ymm8, ymm13
    vmovdqa oword [%1 + 8*32], xmm8
    vextracti128 oword [%2 + 8*32], ymm8, 1
    vpsrlq ymm15, ymm4, 26      ; Round 5a
    vpaddq ymm5, ymm5, ymm15
    vpand ymm4, ymm4, ymm13
    vmovdqa oword [%1 + 4*32], xmm4
    vextracti128 oword [%2 + 4*32], ymm4, 1
    vpsrlq ymm15, ymm9, 25      ; Round 5b
    vpsllq ymm14, ymm15, 4
    vpaddq ymm0, ymm0, ymm14
    vpaddq ymm14, ymm15, ymm15
    vpaddq ymm15, ymm14, ymm15
    vpaddq ymm0, ymm0, ymm15
    vpand ymm9, ymm9, ymm12
    vmovdqa oword [%1 + 9*32], xmm9
    vextracti128 oword [%2 + 9*32], ymm9, 1
    vpsrlq ymm15, ymm5, 25       ; Round 6a
    vpaddq ymm6, ymm6, ymm15
    vmovdqa oword [%1 + 6*32], xmm6
    vextracti128 oword [%2 + 6*32], ymm6, 1
    vpand ymm5, ymm5, ymm12
    vmovdqa oword [%1 + 5*32], xmm5
    vextracti128 oword [%2 + 5*32], ymm5, 1
    vpsrlq ymm15, ymm0, 26       ; Round 6b
    vpaddq ymm1, ymm1, ymm15
    vmovdqa oword [%1 + 1*32], xmm1
    vextracti128 oword [%2 + 1*32], ymm1, 1
    vpand ymm0, ymm0, ymm13
    vmovdqa oword [%1 + 0*32], xmm0
    vextracti128 oword [%2 + 0*32], ymm0, 1
%endmacro

%macro fe10x4_carry_body_store_owords_hipart 2
    ; Do a double interleaved carry ripple:
    ;
    ; - Ripple a: h0 -> h1 -> h2 -> h3 -> h4 -> h5 -> h6
    ; - Ripple b: h5 -> h6 -> h7 -> h8 -> h9 -> h0 -> h1
    ;    
    vmovdqa ymm13, yword [rel .MASK26]
    vmovdqa ymm12, yword [rel .MASK25]
    vpsrlq ymm15, ymm0, 26      ; Round 1a
    vpaddq ymm1, ymm1, ymm15
    vpand ymm0, ymm0, ymm13
    vpsrlq ymm15, ymm5, 25      ; Round 1b
    vpaddq ymm6, ymm6, ymm15
    vpand ymm5, ymm5, ymm12
    vpsrlq ymm15, ymm1, 25      ; Round 2a
    vpaddq ymm2, ymm2, ymm15
    vpand ymm1, ymm1, ymm12
    vpsrlq ymm15, ymm6, 26      ; Round 2b
    vpaddq ymm7, ymm7, ymm15
    vpand ymm6, ymm6, ymm13
    vpsrlq ymm15, ymm2, 26      ; Round 3a
    vpaddq ymm3, ymm3, ymm15
    vpand ymm2, ymm2, ymm13
    vextracti128 oword [%1 + 2*32], ymm2, 1
    vextracti128 oword [%2 + 2*32], ymm2, 1
    vpsrlq ymm15, ymm7, 25      ; Round 3b
    vpaddq ymm8, ymm8, ymm15
    vpand ymm7, ymm7, ymm12
    vextracti128 oword [%1 + 7*32], ymm7, 1
    vextracti128 oword [%2 + 7*32], ymm7, 1
    vpsrlq ymm15, ymm3, 25      ; Round 4a
    vpaddq ymm4, ymm4, ymm15
    vpand ymm3, ymm3, ymm12
    vextracti128 oword [%1 + 3*32], ymm3, 1
    vextracti128 oword [%2 + 3*32], ymm3, 1
    vpsrlq ymm15, ymm8, 26      ; Round 4b
    vpaddq ymm9, ymm9, ymm15
    vpand ymm8, ymm8, ymm13
    vextracti128 oword [%1 + 8*32], ymm8, 1
    vextracti128 oword [%2 + 8*32], ymm8, 1
    vpsrlq ymm15, ymm4, 26      ; Round 5a
    vpaddq ymm5, ymm5, ymm15
    vpand ymm4, ymm4, ymm13
    vextracti128 oword [%1 + 4*32], ymm4, 1
    vextracti128 oword [%2 + 4*32], ymm4, 1
    vpsrlq ymm15, ymm9, 25      ; Round 5b
    vpsllq ymm14, ymm15, 4
    vpaddq ymm0, ymm0, ymm14
    vpaddq ymm14, ymm15, ymm15
    vpaddq ymm15, ymm14, ymm15
    vpaddq ymm0, ymm0, ymm15
    vpand ymm9, ymm9, ymm12
    vextracti128 oword [%1 + 9*32], ymm9, 1
    vextracti128 oword [%2 + 9*32], ymm9, 1
    vpsrlq ymm15, ymm5, 25       ; Round 6a
    vpaddq ymm6, ymm6, ymm15
    vextracti128 oword [%1 + 6*32], ymm6, 1
    vextracti128 oword [%2 + 6*32], ymm6, 1
    vpand ymm5, ymm5, ymm12
    vextracti128 oword [%1 + 5*32], ymm5, 1
    vextracti128 oword [%2 + 5*32], ymm5, 1
    vpsrlq ymm15, ymm0, 26       ; Round 6b
    vpaddq ymm1, ymm1, ymm15
    vextracti128 oword [%1 + 1*32], ymm1, 1
    vextracti128 oword [%2 + 1*32], ymm1, 1
    vpand ymm0, ymm0, ymm13
    vextracti128 oword [%1 + 0*32], ymm0, 1
    vextracti128 oword [%2 + 0*32], ymm0, 1
%endmacro


%macro fe10x4_carry_consts 0
    align 32, db 0
    .MASK26: times 4 dq 0x3FFFFFF
    .MASK25: times 4 dq 0x1FFFFFF
%endmacro

%endif
