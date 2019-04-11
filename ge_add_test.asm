; Point addition for E : y^2 = x^3 - 3*x + 13318
;
; Author: Amber Sprenkels <amber@electricdusk.com>

global crypto_scalarmult_curve13318_avx2_ge_add_asm

%include "fe10x4_carry.asm"
%include "fe10x4_mul.asm"

section .text

crypto_scalarmult_curve13318_avx2_ge_add_asm:
    ; Add two points on the curve
    ;
    ; Inputs:
    ;   - [rsi]: First operand -- ( x1 : y1 : z1 )
    ;   - [rdx]: Second operand -- ( x2 : y2 : z2 )
    ;
    ; Output:
    ;   - [rdi]: Sum of the two inputs -- ( x3 : y3 : z3 )
    ;
    push r10
    push r11
    push r12
    push r13
    push rbp
    mov rbp, rsp
    and rsp, -32
    sub rsp, 6*10*32
    
    %push ge_add_ctx
    %xdefine x3          rdi
    %xdefine y3          rdi + 10*8
    %xdefine z3          rdi + 20*8
    %xdefine x1          rsi
    %xdefine y1          rsi + 10*8
    %xdefine z1          rsi + 20*8
    %xdefine x2          rdx
    %xdefine y2          rdx + 10*8
    %xdefine z2          rdx + 20*8
    %xdefine t0          rsp
    %xdefine t1          rsp + 1*10*32
    %xdefine t2          rsp + 2*10*32
    %xdefine t3          rsp + 3*10*32
    %xdefine t4          rsp + 4*10*32
    %xdefine t5          rsp + 5*10*32
    
    %assign i 0
    %rep 10
        ; TODO(dsprenkels) In this part, because of the broadcasts and the blends, the front-end
        ; cannot keep up. To slow the back-end down, we can precompute the first couple of vpmuludq
        ; instructions from the first multiplication.
    
        vpbroadcastq ymm0, qword [x1 + i*8]         ; [x1, x1, x1, x1]
        vpbroadcastq ymm1, qword [y1 + i*8]         ; [y1, y1, y1, y1]
        vpbroadcastq ymm2, qword [z1 + i*8]         ; [z1, z1, z1, z1]
        vpbroadcastq ymm3, qword [x2 + i*8]         ; [x2, x2, x2, x2]
        vpbroadcastq ymm4, qword [y2 + i*8]         ; [y2, y2, y2, y2]
        vpbroadcastq ymm5, qword [z2 + i*8]         ; [z2, z2, z2, z2]
        
        vpblendd ymm6, ymm0, ymm1, 0b11000000       ; [x1, x1, x1, y1]
        vpblendd ymm7, ymm1, ymm2, 0b11000011       ; [z1, y1, y1, z1]
        vpaddq ymm6, ymm6, ymm7                     ; compute [v14, v4, v4, v9] ≤ ??
        vmovdqa yword [t3 + 32*i], ymm6             ; t3 = [??, ??, v4, v9]
        vpblendd ymm8, ymm3, ymm4, 0b11000000       ; [x2, x2, x2, y2]
        vpblendd ymm9, ymm4, ymm5, 0b11000011       ; [z2, y2, y2, z2]
        vpaddq ymm8, ymm8, ymm9                     ; compute [v15, v5, v5, v10] ≤ ??
        vmovdqa yword [t4 + 32*i], ymm8             ; t4 = [??, ??, v5, v10]

        vpblendd ymm7, ymm7, ymm0, 0b00001100       ; [z1, x1, y1, z1]
        vpblendd ymm7, ymm7, ymm6, 0b00000011       ; [v14, x1, y1, z1]
        vmovdqa yword [t0 + 32*i], ymm7             ; t0 = [v14, x1, y1, z1]
        vpblendd ymm9, ymm9, ymm3, 0b00001100       ; [z2, x2, y2, z2]
        vpblendd ymm9, ymm9, ymm8, 0b00000011       ; [v15, x2, y2, z2]
        vmovdqa yword [t1 + 32*i], ymm9             ; t1 = [v15, x2, y2, z2]

        ; [2019-01-22] Checked v14
        ; [2019-01-22] Checked v15
        %assign i (i + 1) % 10
    %endrep

    fe10x4_mul t2, t0, t1, t5                   ; compute [v16, v1, v2, v3]
    ; [2019-01-22] Checked v16
    ; [2019-01-22] Checked v1
    ; [2019-01-22] Checked v2
    ; [2019-01-22] Checked v3
    
    %assign i 0
    %rep 10
        %if i == 0
            %assign j 0
        %elif i % 2 == 1
            %assign j 1
        %else
            %assign j 2
        %endif
    
        ; TODO(dsprenkels) This block has enough latency, that we don't need the interleaving
        ; carry chain here. We would do good to put a non-interleaved carry chain at the end
        ; of this block.
        ; TODO(dsprenkels) Moreover, just as the previous block, in this block it looks like the
        ; front-end cannot keep up with the back-end. So after having done the partial carry chain,
        ; we may be able to precompute some of the multiply. However, note that due to extra
        ; introduced latency, this could actually slow down this part.
    
        mov r9, qword [t2 + 32*i + 8]           ; v1
        mov r11, qword [t2 + 32*i + 24]         ; v3
        mov r10, qword [t2 + 32*i + 16]         ; v2
        lea r12, [r9 + r11]                     ; compute v17
        mov rax, qword [t2 + 32*i]              ; v16
        lea r13, [r9 + r10]                     ; compute v7
        %if j == 0
            mov r8, 0x3FFFFED0                  ; 4*p
        %elif j == 1
            mov r8, 0x1FFFFFF0                  ; 4*p
        %elif j == 2
            mov r8, 0x3FFFFFF0                  ; 4*p
        %else
            %error
        %endif
        sub r13, r8                             ; v7 - 4*p
        mov qword [t0 + 32*i + 16], r13         ; t0 = [??, ??, v7 - 4*p, ??]
        lea r13, [r10 + r11]                    ; compute v12
        sub r13, r8                             ; v12 - 4*p
        mov qword [t0 + 32*i + 24], r13         ; t0 = [??, ??, v7 - 4*p, v12 - 4*p]
        sub rax, r12                            ; compute v18
        mov r8, rax                             ; rename v18
        imul r12, r11, 13318                    ; compute v19
        imul rax, rax, 13318                    ; compute v25
        sub r8, r12                             ; compute v20
        lea r8, [2*r8 + r8]                     ; compute v22
        mov r13, r8                             ; rename v22
        add r8, r10                             ; compute v24
        sub r10, r13                            ; compute v23
        lea r13, [2*r11 + r11]                  ; compute v27
        sub rax, r9                             ; compute v25 - v1
        sub rax, r13                            ; compute v29
        lea rax, [2*rax + rax]                  ; compute v31
        lea r9, [2*r9 + r9]                     ; compute v33
        sub r9, r13                             ; compute v34

        ; [2019-02-11] Checked v34       
        ; [2019-02-11] Checked v31       
        ; [2019-02-11] Checked v24
        ; [2019-02-11] Checked v23

        vmovq xmm15, rax                        ; [v31, ??]
        vmovq xmm14, r10                        ; [v23, ??]
        vpunpcklqdq xmm15, xmm15, xmm14         ; [v31, v23]
        vmovq xmm%[i], r9                       ; [v34, ??]
        vmovq xmm14, r8                         ; [v24, ??]
        vpunpcklqdq xmm%[i], xmm%[i], xmm14     ; [v34, v24]
        vinserti128 ymm%[i], ymm%[i], xmm15, 1  ; [v34, v24, v31, v23]

        %if i == 0
            vpbroadcastq ymm13, qword [rel .const_2p32P + 8*0]
            %assign ymm2p32P 13
        %elif i == 1
            vpbroadcastq ymm12, qword [rel .const_2p32P + 8*1]
            %assign ymm2p32P 12
        %elif i == 2
            vpbroadcastq ymm13, qword [rel .const_2p32P + 8*1]
            %assign ymm2p32P 13
        %elif i % 2 == 1
            %assign ymm2p32P 12
        %else
            %assign ymm2p32P 13
        %endif        
        vpaddq ymm%[i], ymm%[i], ymm%[ymm2p32P]
    
        %assign i (i + 1) % 10
    %endrep

    fe10x4_carry_body ; See TODO note above previous block
    %assign i 0
    %rep 10
        vmovdqa yword [t2 + 32*i], ymm%[i]          ; t2 = [v34, v24, v31, v23]
        vmovdqa oword [t3 + 32*i], xmm%[i]          ; t3 = [v34, v24, v4, v9]
        vextracti128 oword [t4 + 32*i], ymm%[i], 1  ; t4 = [v31, v23, v5, v10]
        ; TODO(dsprenkels) ^ Merge these stores into carry and precompute 1st mul round
        %assign i (i + 1) % 10
    %endrep
    fe10x4_mul_body t3, t4, t5                  ; compute [v36, v37, v6, v11]
    fe10x4_carry_body

    ; [2019-02-12] Checked v36
    ; [2019-02-12] Checked v37
    ; [2019-02-12] Checked v6
    ; [2019-02-12] Checked v11
    
    %assign i 2
    %rep 10
        vmovq rax, xmm%[i]
        vpextrq r8, xmm%[i], 1
        add rax, r8                             ; compute v38
        mov qword [y3 + 8*i], rax               ; store y3
                
        vmovdqa ymm15, yword [t0 + 32*i]        ; [??, ??, v7 - 4*p, v12 - 4*p]
        vpsubq ymm15, ymm%[i], ymm15            ; compute [??, ??, v8 + 4*p, v13 + 4*p]
        vpermq ymm15, ymm15, 0b11111010         ; [v8, v8, v13, v13]
        vmovdqa yword [t3 + 32*i], ymm15        ; t3 = [v8, v8, v13, v13]
        
        %assign i (i + 1) % 10
    %endrep

    fe10x4_mul_body t3, t2, t5                  ; compute [v42, v39, v35, v41]
    
    ; TODO(dsprenkels) Interleave this loop s.t. we need less registers
    vmovdqa xmm15, oword [rel .const_2p37P_2p37P + 16]
    vmovdqa xmm14, oword [rel .const_2p37P_2p37P + 32]
    %assign i 0
    %rep 10
        %if i == 0
            %assign j 0
        %elif i % 2 == 1
            %assign j 1
        %else
            %assign j 2
        %endif
        
        vpermq ymm13, ymm%[i], 0b00011011       ; [v41, v35, v39, v42]
        %if i == 0
            vpaddq xmm12, xmm%[i], oword [rel .const_2p37P_2p37P]
        %elif i % 2 == 1
            vpaddq xmm12, xmm%[i], xmm15
        %else
            vpaddq xmm12, xmm%[i], xmm14
        %endif
        vpsubq xmm12, xmm12, xmm13              ; compute [??, v40]
        vpaddq xmm13, xmm%[i], xmm13            ; compute [v43, ??] 
        vpblendd xmm%[i], xmm13, xmm12, 0b1100  ; [v43, v40]

        %assign i (i + 1) % 10
    %endrep
    ; TODO(dsprenkels) Implement xmm-specific carry?
    fe10x4_carry_body    
    %assign i 0
    %rep 10
        ; TODO(dsprenkels) We can optimize this if we store x and z packed together
        vmovq rax, xmm%[i]
        mov qword [z3 + 8*i], rax
        vpextrq r8, xmm%[i], 1
        mov qword [x3 + 8*i], r8

        %assign i (i + 1) % 10
    %endrep

    %pop ge_add_ctx
    pop r13
    pop r12
    pop r11
    pop r10
    mov rsp, rbp
    pop rbp
    ret

section .rodata
fe10x4_mul_consts
fe10x4_carry_consts

align 32, db 0
.const_0_0_4P_4P:
times 4 dq 0x3FFFFED0
times 4 dq 0x1FFFFFF0
times 4 dq 0x3FFFFFF0
align 16, db 0
.const_2p37P_2p37P:
times 2 dq 0x7FFFFDA000000000
times 2 dq 0x3FFFFFE000000000
times 2 dq 0x7FFFFFE000000000
align 8, db 0
.const_2p32P:
dq 0x3FFFFED00000000
dq 0x1FFFFFF00000000
dq 0x3FFFFFF00000000
