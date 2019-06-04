; Ladder for shared secret point multiplication
;
; Author: Amber Sprenkels <amber@electricdusk.com>

%include "ge_double.asm"
%include "ge_add.asm"
%include "select.asm"

global crypto_scalarmult_curve13318_avx2_ladder

section .text
crypto_scalarmult_curve13318_avx2_ladder:
    ; Double-and-add ladder for shared secret point multiplication
    ;
    ; Arguments:
    ;   ge q:               [rdi]
    ;   uint8_t *windows:   [rsi]
    ;   ge ptable[16]:      [rdx]
    ;
    %xdefine stack_size 7*10*32
    %xdefine tmp        rsp + 6*10*32

    ; prologue
    push rbp
    mov rbp, rsp
    and rsp, -32
    sub rsp, stack_size
    
    ; just use the red zone ¯\_(ツ)_/¯
    mov qword [rsp - 8], r8
    mov qword [rsp - 16], r9
    mov qword [rsp - 24], r10
    mov qword [rsp - 32], r11
    mov qword [rsp - 40], r12
    mov qword [rsp - 48], r13
    mov qword [rsp - 56], rbx
    mov qword [rsp - 64], r15
    mov r15, rcx
        
    ; start loop
    xor rcx, rcx
.ladderstep:
    mov rbx, 5
.ladderstep_double:
    ge_double rdi, rdi, rsp
    sub rbx, 1
    jnz .ladderstep_double
    
    ; Reset the ymm bank
    vpxor ymm0, ymm0, ymm0
    vpxor ymm1, ymm1, ymm1
    vpxor ymm2, ymm2, ymm2
    vpxor ymm3, ymm3, ymm3
    vpxor ymm4, ymm4, ymm4
    vpxor ymm5, ymm5, ymm5
    vpxor ymm6, ymm6, ymm6
    vpxor ymm7, ymm7, ymm7
    vpxor ymm8, ymm8, ymm8
    vpxor xmm9, xmm9, xmm9
    
.compute_idx:
    
    ; Our lookup table is one-based indexed. The neutral element is not stored
    ; in `ptable`, but written by `select`. The mapping from `bits` to `idx`
    ; is defined by the following:
    ;
    ; compute_idx :: Word5 -> Word5
    ; compute_idx bits
    ;   |  0 <= bits < 16 = bits - 1  // sign is (+)
    ;   | 16 <= bits < 32 = ~bits     // sign is (-)
    movzx r10, byte [rsi + rcx] ; bits
    mov rax, r10                ; copy bits
    shr r10, 4
    and r10, 1                  ; sign
    lea r11, [r10 - 1]          ; ~signmask
    neg r10                     ; signmask
    lea r9, [rax - 1]           ; bits - 1
    and r9, r11                 ; (bits - 1) & ~signmask
    not rax                     ; ~bits
    and rax, r10                ; ~bits & signmask
    mov r8, rax
    or r8, r9                   ; idx (not zx'd)
    and r8, 0x1F                ; force idx to be in [0, 0x1F]
    ; At this point r10 is signmask. It will not be killed in select.
    
    select r8b, rdx
    ;   - ymm0: {X[0], X[1], X[2], X[3]}
    ;   - ymm1: {X[4], X[5], X[6], X[7]}
    ;   - ymm2: {X[8], X[9], Y[0], Y[1]}
    ;   - ymm3: {Y[2], Y[3], Y[4], Y[5]}
    ;   - ymm4: {Y[6], Y[7], Y[8], Y[9]}
    ;   - ymm5: {Z[0], Z[1], Z[2], Z[3]}
    ;   - ymm6: {Z[4], Z[5], Z[6], Z[7]}
    ;   - xmm7: {Z[8], Z[9]}
    
    vmovdqa yword [tmp + 0*32], ymm0
    vmovdqa yword [tmp + 1*32], ymm1
    
    ; conditionally negate Y if sign == 1 (i.e. if signmask == 0xFFF...)
    vmovq xmm15, r10            
    vpbroadcastq ymm15, xmm15   ; signmask
    vpcmpeqd ymm14, ymm14, ymm14
    vpxor ymm14, ymm14, ymm15   ; ~signmask
    ; conditionally negate Y
    vmovdqa ymm11, yword [rel .const_4P + 0*32]
    vpsubq ymm13, ymm11, ymm2
    vpand ymm13, ymm13, ymm15
    vpand ymm12, ymm2, ymm14
    vpor ymm13, ymm13, ymm12
    vpblendd ymm2, ymm2, ymm13, 0b11110000
    vmovdqa yword [tmp + 2*32], ymm2
    vmovdqa ymm11, yword [rel .const_4P + 1*32]
    vpsubq ymm13, ymm11, ymm3
    vpand ymm13, ymm13, ymm15
    vpand ymm12, ymm3, ymm14
    vpor ymm3, ymm13, ymm12
    vmovdqa yword [tmp + 3*32], ymm3
    vpsubq ymm13, ymm11, ymm4
    vpand ymm13, ymm13, ymm15
    vpand ymm12, ymm4, ymm14
    vpor ymm4, ymm13, ymm12
    vmovdqa yword [tmp + 4*32], ymm4
    
    vmovdqa yword [tmp + 5*32], ymm5
    vmovdqa yword [tmp + 6*32], ymm6
    vmovdqa oword [tmp + 7*32], xmm7
    
    ; add q and p into q
    ge_add rdi, rdi, tmp, rsp
    
    ; loop repeat
    add rcx, 1
    cmp rcx, 51
    jl .ladderstep

.end:
    ; epilogue
    mov r15, qword [rsp - 64]
    mov rbx, qword [rsp - 56]
    mov r13, qword [rsp - 48]
    mov r12, qword [rsp - 40]
    mov r11, qword [rsp - 32]
    mov r10, qword [rsp - 24]
    mov r9, qword [rsp - 16]
    mov r8, qword [rsp - 8]
    mov rsp, rbp
    pop rbp
    vzeroupper
    ret


section .rodata

align 32, db 0
.MASK26: times 4 dq 0x3FFFFFF
.MASK25: times 4 dq 0x1FFFFFF

.const_2p37P_2p37P_2p37P_2p37P:
times 4 dq 0x7FFFFDA000000000
times 4 dq 0x3FFFFFE000000000
times 4 dq 0x7FFFFFE000000000

.const_4P:
dq 0x00000000, 0x00000000, 0x3FFFFED0, 0x1FFFFFF0
dq 0x3FFFFFF0, 0x1FFFFFF0, 0x3FFFFFF0, 0x1FFFFFF0

align 16, db 0
.const_2p37P_0:
dq 0x7FFFFDA000000000, 0x00
dq 0x3FFFFFE000000000, 0x00
dq 0x7FFFFFE000000000, 0x00

align 8, db 0
.const_2p32P:
dq 0x3FFFFED00000000
dq 0x1FFFFFF00000000
dq 0x3FFFFFF00000000

align 8, db 0
.const_19: dq 19

