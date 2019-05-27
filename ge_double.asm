; Point doubling for E : y^2 = x^3 - 3*x + 13318 (macro)
;
; Author: Amber Sprenkels <amber@electricdusk.com>

%ifndef CURVE13318_GE_DOUBLE_ASM_
%define CURVE13318_GE_DOUBLE_ASM_

global crypto_scalarmult_curve13318_avx2_ge_double_asm

%include "fe10x4_carry.asm"
%include "fe10x4_mul.asm"
%include "fe10x4_square.asm"

%macro ge_double 3
    %push ge_double_ctx
    %xdefine x3         rdi
    %xdefine y3         rdi + 10*8
    %xdefine z3         rdi + 20*8
    %xdefine x          rsi
    %xdefine y          rsi + 10*8
    %xdefine z          rsi + 20*8
    %xdefine t0         rsp
    %xdefine t1         rsp + 1*10*32
    %xdefine t2         rsp + 2*10*32
    %xdefine t3         rsp + 3*10*32
    %xdefine t5         rsp + 4*10*32

    %assign i 0
    %rep 10
        ; TODO(dsprenkels) The reciprocal throughput of this block is 3 cycles.
        ; I.e. the front-end does not seem to be able to keep up. This block
        ; would be an ideal spot to precompute some squaring values to slow
        ; down the back-end.
        ; For example: all diagonals, or adjacent terms.

        vpbroadcastq ymm14, qword [x + i*8]          ; [X, X, X, X]
        vpbroadcastq ymm13, qword [y + i*8]          ; [Y, Y, Y, Y]
        vpbroadcastq ymm12, qword [z + i*8]          ; [Z, Z, Z, Z]

        vpaddq ymm11, ymm14, ymm12                   ; [X+Z, X+Z, X+Z, X+Z]
        vpblendd ymm11, ymm11, ymm14, 0b00001100     ; [X+Z, X, X+Z, X+Z]
        vpblendd ymm10, ymm12, ymm13, 0b00110000     ; [Z, Z, Y, Z]
        vpblendd ymm11, ymm11, ymm10, 0b11110000     ; [X+Z, X, Y, Z]
        vmovdqa [t0 + 32*i], ymm11                   ; t0 = [X+Z, X, Y, Z]
        
        ; Precompute first multiplication round
        %if i == 0
            vpmuludq ymm%[i], ymm11, ymm11
            vpaddq ymm15, ymm11, ymm11
        %else
            vpmuludq ymm%[i], ymm15, ymm11
        %endif

        vpaddq ymm13, ymm13, ymm13                   ; [2Y, 2Y, 2Y, 2Y]
        vmovdqa [t2 + 32*i], ymm13                   ; t2 = [2Y, 2Y, 2Y, 2Y]
        vpblendd ymm14, ymm14, ymm12, 0b00110011     ; [Z, X, Z, X]
        vmovdqa [t3 + 32*i], ymm14                   ; t3 = [Z, X, Z, X]

        %assign i (i + 1) % 10
    %endrep

    fe10x4_square_body_skip_first_round t0, t5       ; compute [X^2 + Z^2 - 2XZ, v1, v2, v3]
    fe10x4_carry_body_store t1

    %assign i 0
    %rep 10
        mov rax, qword [t1 + 32*i]                  ; X^2 + Z^2 + 2XZ 
        mov r8, qword [t1 + 32*i + 8]               ; compute v1
        sub rax, r8                                 ; compute Z^2 + 2XZ
        mov r10, qword [t1 + 32*i + 24]             ; compute v3
        sub rax, r10                                ; compute v7 = 2XZ
        mov r9, qword [t1 + 32*i + 16]              ; compute v2
        imul r11, rax, 13318                        ; compute v18
        imul r12, r10, 13318                        ; compute v8
        lea r10, [2*r10 + r10]                      ; compute v17
        sub r11, r10                                ; compute v19
        sub r12, rax                                ; compute v9
        lea rax, [2*r8 + r8]                        ; compute v24
        lea r12, [2*r12 + r12]                      ; compute v11
        sub r11, r8                                 ; compute v20
        lea r11, [2*r11 + r11]                      ; compute v22
        mov r8, r9                                  ; copy v2
        mov r13, r9                                 ; copy v2
        sub r8, r12                                 ; compute v12
        add r9, r12                                 ; compute v13
        sub rax, r10                                ; compute v25
        
        ; Later, for the computation of v33 (through v32), we will need 4*v2
        shl r13, 2                                  ; compute 4*v2
        mov qword [t1 + 32*i + 16], r13             ; t1 = [??, v1, 4*v2, v3]

        ; The largest bound here is that of v22, which is (not tightly)
        ; v|22| ≤ 0.99*2^43. So we add 2^32*p, which is easily larger, to
        ; wrap the values back to the positive domain.
        
        vmovq xmm15, rax                        ; [v25, ??]
        vmovq xmm14, r9                         ; [v13, ??]
        vpunpcklqdq xmm15, xmm15, xmm14         ; [v25, v13]
        vmovq xmm%[i], r11                      ; [v22, ??]
        vmovq xmm14, r8                         ; [v12, ??]
        vpunpcklqdq xmm%[i], xmm%[i], xmm14     ; [v22, v12]
        vinserti128 ymm%[i], ymm%[i], xmm15, 1  ; [v22, v12, v25, v13]
        
        %if i == 0
            vpbroadcastq ymm13, qword [rel .const_2p32P]
            %assign ymm2p37P 13
        %elif i == 1
            vpbroadcastq ymm12, qword [rel .const_2p32P + 8]
            %assign ymm2p37P 12
        %elif i == 2
            vpbroadcastq ymm13, qword [rel .const_2p32P + 16]
            %assign ymm2p37P 13
        %elif i % 2 == 1
            %assign ymm2p37P 12
        %else
            %assign ymm2p37P 13
        %endif        
        vpaddq ymm%[i], ymm%[i], ymm%[ymm2p37P]
        
        %assign i (i + 1) % 10
    %endrep
    fe10x4_carry_body_store_owords t2, t3       ; t2 = [v22, v12, 2Y, 2Y]
                                                ; t3 = [v25, v13, Z, X]
                                                
    fe10x4_mul_body t2, t3, t5                  ; compute [v26, v14, v28, v4]    
    fe10x4_carry_body_store_owords_hipart t1, t2+16
            ; ymm[] = [v26, v14,  v28, v4]
            ; t1    = [v28,  v4, 4*v2, v3]
            ; t2    = [v22, v12,  v28, v4]

    ; At this point we have to wait a small while until the oword stores in the
    ; carry chain can be used again in the multiplication. In the meantime, we
    ; will burn ~10 cycles to compute Y3.
    ;
    vmovdqa ymm15, yword [t1 + 0*32]            ; load f[0]
    %assign i 2
    %rep 10
        vpermilpd xmm14, xmm%[i], 0b11          ; v14
        vpaddq xmm14, xmm%[i], xmm14            ; compute v27
        vpmuludq ymm%[i], ymm15, yword [t2 + i*32]
        vmovq qword [y3 + 8*i], xmm14           ; store y3

        %assign i (i + 1) % 10
    %endrep

    fe10x4_mul_body_skip_first_round t1, t2, t5 ; compute [v30, v15, v34, ??]

    ; TODO(dsprenkels) Inline this piece into the carry chain
    vxorpd ymm12, ymm12, ymm12
    %assign i 0
    %rep 10
        %if i == 0
            vmovdqa ymm15, yword [rel .const_2p37P_2p37P_2p37P_2p37P + 0*32]
            %assign ymm2p37P 15
        %elif i == 1
            vmovdqa ymm14, yword [rel .const_2p37P_2p37P_2p37P_2p37P + 1*32]
            %assign ymm2p37P 14
        %elif i == 2
            vmovdqa ymm13, yword [rel .const_2p37P_2p37P_2p37P_2p37P + 2*32]
            %assign ymm2p37P 13
        %elif i % 2 == 1
            %assign ymm2p37P 14
        %else
            %assign ymm2p37P 13
        %endif        

        vpermq ymm11, ymm%[i], 0b00001001       ; [v15, v34, ??, ??]
        vpsubq ymm10, ymm%[i], ymm%[ymm2p37P]   ; force underflow in v30
        vpblendd ymm10, ymm12, ymm10, 0b00000011 ; [v30', 0, 0, 0]
        vpsubq ymm%[i], ymm11, ymm10            ; [v31, v34, ??, ??]

        %assign i (i + 1) % 10
    %endrep

    ; TODO(dsprenkels) Maybe implement a xmm-specific carry chain?
    fe10x4_carry_body

    %assign i 2
    %rep 10
        ; TODO(dsprenkels) Look into storing x and z packed together, because
        ; this store costs us almost 20 cycles.
        vmovq qword [x3 + 8*i], xmm%[i]
        vpextrq qword [z3 + 8*i], xmm%[i], 1
    
        %assign i (i + 1) % 10
    %endrep

    %pop ge_double_ctx
%endmacro

%macro ge_double_consts 0
    align 32, db 0
    .const_2p37P_2p37P_2p37P_2p37P:
    times 4 dq 0x7FFFFDA000000000
    times 4 dq 0x3FFFFFE000000000
    times 4 dq 0x7FFFFFE000000000
    align 8, db 0
    .const_2p32P:
    dq 0x3FFFFED00000000
    dq 0x1FFFFFF00000000
    dq 0x3FFFFFF00000000
%endmacro

%endif