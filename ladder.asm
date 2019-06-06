; Ladder for shared secret point multiplication
;
; Author: Amber Sprenkels <amber@electricdusk.com>

%include "ge_double.mac.asm"
%include "ge_add.mac.asm"
%include "select.mac.asm"

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
        
    ; start loop
    xor rcx, rcx
.ladderstep:
    mov rbx, 5
.ladderstep_double:
    ge_double rdi, rdi, rsp
    sub rbx, 1
    jnz .ladderstep_double
    
.ladderstep_compute_idx:
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

.ladderstep_select:
    select r8, rdx
    ;   - ymm0: {X[0],X[1],X[2],X[3],X[4],X[5],X[6],X[7]}
    ;   - ymm1: {X[8],X[9],Y[0],Y[1],Y[2],Y[3],Y[4],Y[5]}
    ;   - ymm2: {Y[6],Y[7],Y[8],Y[9],Z[0],Z[1],Z[2],Z[3]}
    ;   - ymm3: {Z[4],Z[5],Z[6],Z[7],Z[8],Z[9],  ??,  ??}
    
.ladderstep_invert_y:
    vmovdqa yword [tmp + 0*32], ymm0
    ; conditionally negate Y if sign == 1 (i.e. if signmask == 0xFFF...)
    vmovq xmm15, r10
    vpbroadcastq ymm15, xmm15   ; signmask
    vpcmpeqd ymm14, ymm14, ymm14
    vpxor ymm14, ymm14, ymm15   ; ~signmask
    ; conditionally negate Y
    vmovdqa ymm13, yword [rel .const_4P_at_Y + 0*32]
    vpsubd ymm13, ymm13, ymm1
    vpand ymm13, ymm13, ymm15
    vpand ymm12, ymm1, ymm14
    vpor ymm13, ymm13, ymm12
    vpblendd ymm1, ymm1, ymm13, 0b11111100
    vmovdqa yword [tmp + 1*32], ymm1
    vmovdqa ymm13, yword [rel .const_4P_at_Y + 1*32]
    vpsubd ymm13, ymm13, ymm2
    vpand ymm13, ymm13, ymm15
    vpand ymm12, ymm2, ymm14
    vpor ymm13, ymm13, ymm12
    vpblendd ymm2, ymm2, ymm13, 0b00001111
    vmovdqa yword [tmp + 2*32], ymm2
    vmovdqa yword [tmp + 3*32], ymm3
    
.ladderstep_add:
    ; add q and p into q
    ge_add rdi, tmp, rdi, rsp
    
    ; loop repeat
    add rcx, 1
    cmp rcx, 51
    jl .ladderstep

.end:
    ; epilogue
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

.const_4P_at_Y:
dd 0x0000000, 0x0000000, 0xFFFFFB4, 0x7FFFFFC, 0xFFFFFFC, 0x7FFFFFC, 0xFFFFFFC, 0x7FFFFFC
dd 0xFFFFFFC, 0x7FFFFFC, 0xFFFFFFC, 0x7FFFFFC, 0x0000000, 0x0000000, 0x0000000, 0x0000000

.select_idxs:
times 8 dd 0
times 8 dd 1
times 8 dd 2
times 8 dd 3
times 8 dd 4
times 8 dd 5
times 8 dd 6
times 8 dd 7
times 8 dd 8
times 8 dd 9
times 8 dd 10
times 8 dd 11
times 8 dd 12
times 8 dd 13
times 8 dd 14
times 8 dd 15
.select_neutral_idx:
; Select only the third limb
times 8 dd 0x1F
.const_y0_is_1:
times 8 dd 0, 0, 1, 0, 0, 0, 0, 0

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

