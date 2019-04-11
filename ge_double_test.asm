; Point doubling for E : y^2 = x^3 - 3*x + 13318
;
; Author: Amber Sprenkels <amber@electricdusk.com>

global crypto_scalarmult_curve13318_avx2_ge_double_asm

%include "fe10x4_carry.asm"
%include "fe10x4_mul.asm"
%include "fe10x4_square.asm"

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
    sub rsp, 6*10*32
    
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
    %xdefine t4         rsp + 4*10*32
    %xdefine t5         rsp + 5*10*32

    %assign i 0
    %rep 10
        ; TODO(dsprenkels) The reciprocal throughput of this block is 3 cycles.
        ; I.e. the front-end does not seem to be able to keep up. This block
        ; would be an ideal spot to precompute some squaring values to slow
        ; down the back-end.
        ; For example: all diagonals, or adjacent terms.
    
        vpbroadcastq ymm0, qword [x + i*8]          ; [X, X, X, X]
        vpbroadcastq ymm1, qword [y + i*8]          ; [Y, Y, Y, Y]
        vpbroadcastq ymm2, qword [z + i*8]          ; [Z, Z, Z, Z]
    
        vpaddq ymm3, ymm0, ymm2                     ; [X+Z, X+Z, X+Z, X+Z]
        vpblendd ymm5, ymm3, ymm0, 0b00001100       ; [X+Z, X, X+Z, X+Z]
        vpblendd ymm6, ymm2, ymm1, 0b00110000       ; [Z, Z, Y, Z]
        vpblendd ymm5, ymm5, ymm6, 0b11110000       ; [X+Z, X, Y, Z]
        vmovdqa [t0 + 32*i], ymm5                   ; t0 = [X+Z, X, Y, Z]
    
        vpaddq ymm1, ymm1, ymm1                     ; [2Y, 2Y, 2Y, 2Y]
        vmovdqa [t2 + 32*i], ymm1                   ; t2 = [2Y, 2Y, 2Y, 2Y]
        vpblendd ymm0, ymm0, ymm2, 0b00110011       ; [Z, X, Z, X]
        vmovdqa [t3 + 32*i], ymm0                   ; t3 = [Z, X, Z, X]
    
        %assign i (i + 1) % 10
    %endrep
    
    fe10x4_square t1, t0, t5    ; compute [X^2 + Z^2 - 2XZ, v1, v2, v3]
    
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
        sub r8, r12                                 ; compute v12
        add r9, r12                                 ; compute v13
        sub rax, r10                                ; compute v25
        
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
            %assign ymm2p32P 13
        %elif i == 1
            vpbroadcastq ymm12, qword [rel .const_2p32P + 8]
            %assign ymm2p32P 12
        %elif i == 2
            vpbroadcastq ymm13, qword [rel .const_2p32P + 16]
            %assign ymm2p32P 13
        %elif i % 2 == 1
            %assign ymm2p32P 12
        %else
            %assign ymm2p32P 13
        %endif        
        vpaddq ymm%[i], ymm%[i], ymm%[ymm2p32P]
        
        %assign i (i + 1) % 10
    %endrep
    fe10x4_carry_body_store_owords t2, t3       ; t2 = [v22, v12, 2Y, 2Y]
                                                ; t3 = [v25, v13, X, Z]
                                                
    fe10x4_mul_body t2, t3, t5                  ; compute [v26, v14, v28, v4]    
    fe10x4_carry_body_store_owords_hipart t1, t2+16
            ; ymm[] = [v26, v14, v28,  v4]
            ; t1    = [v28,  v4,  v2,  v3]
            ; t2    = [v22, v12, v28,  v4]
    
    ; At this point we have to wait a small while until the oword stores in the
    ; carry chain can be used again in the multiplication. In the meantime, we
    ; will burn ~10 cycles to compute Y3.
    ;
    
    %assign i 2
    %rep 10
        vpermilpd xmm15, xmm%[i], 0b11          ; v14
        vpaddq xmm%[i], xmm%[i], xmm15          ; compute v27
        vmovq qword [y3 + 8*i], xmm%[i]         ; store y3
    
        %assign i (i + 1) % 10
    %endrep
    
    fe10x4_mul_body t1, t2, t5                  ; compute [v30, v15, v32, ??]
    fe10x4_carry_body
    
    ; TODO(dsprenkels) If we add a bogus limb to the memory where Z3 is stored,
    ; we can use `vextracti128 m, y, i` instead of `vextracti128, x, y, i`,
    ; which will reduce the pressure on port 5.
    ; TODO(dsprenkels) Inline this piece into the carry chain
    %assign i 2
    %rep 10
        %if i == 0
            vmovdqa xmm15, oword [rel .const_4P]
            %assign xmm4P 15
        %elif i == 3
            vmovdqa xmm14, oword [rel .const_4P + 16]
            %assign xmm4P 14
        %elif i == 2
            vmovdqa xmm13, oword [rel .const_4P + 32]
            %assign xmm4P 13
        %elif i % 2 == 1
            %assign xmm4P 14
        %else
            %assign xmm4P 13
        %endif        

        vpermilpd xmm10, xmm%[i], 0b11      ; v15
        vpsllq ymm11, ymm%[i], 2            ; compute [??, ??, v34, ??]
        vpsubq xmm12, xmm%[i], xmm%[xmm4P]  ; force underflow in v30
        vextracti128 xmm11, ymm11, 1        ; v34
        vpsubq xmm10, xmm10, xmm12          ; compute v31
        vmovq qword [z3 + 8*i], xmm11
        vmovq qword [x3 + 8*i], xmm10
        
        %assign i (i + 1) % 10
    %endrep
    
    %pop ge_double_ctx
    mov rsp, rbp
    pop rbp
    pop r12
    pop r11
    pop r10
    ret
    
section .rodata

fe10x4_carry_consts
fe10x4_square_consts

align 16, db 0
.const_4P:
times 2 dq 0xFFFFFB4
times 2 dq 0x7FFFFFC
times 2 dq 0xFFFFFFC
align 8, db 0
.const_2p32P:
dq 0x3FFFFED00000000
dq 0x1FFFFFF00000000
dq 0x3FFFFFF00000000
