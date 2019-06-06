; Select an element from a lookup table
;
; Author: Amber Sprenkels <amber@electricdusk.com>

%ifndef CURVE13318_SELECT_MAC_ASM_
%define CURVE13318_SELECT_MAC_ASM_

%macro select 2
    ; Select the element from the lookup table at index `idx` and put the
    ; element in ymm0-ymm8.
    ; C-type: void select(ge dest, uint8_t idx, const ge ptable[16])
    ;
    ; Arguments (may not be rax!):
    ;   - %1: general purpose register containing idx (unsigned)
    ;   - %2: pointer to the start of the lookup table
    ;
    ; Anatomy of this routine:
    ; For each scan of the lookup table we will need to do one load and one
    ; vpand instruction. For both of these ops, the reciprocal throughput
    ; is 0.33.
    ;
    ; We use the following registers as accumulators:
    ;   - ymm0: {X[0]-X[7]}
    ;   - ymm1: {X[8]-Y[5]}
    ;   - ymm2: {Y[6]-Z[3]}
    ;   - ymm3: {Z[4]-Z[9], ??, ??}

    ; conditionally move the elements from ptable
    
    vmovq xmm15, %1
    vpbroadcastd ymm15, xmm15
    vpcmpeqd ymm14, ymm15, yword [rel .select_idxs + 32*0]
    vpand ymm0, ymm14, yword [%2 + 128*0 + 32*0]
    vpand ymm1, ymm14, yword [%2 + 128*0 + 32*1]
    vpand ymm2, ymm14, yword [%2 + 128*0 + 32*2]
    vpand ymm3, ymm14, yword [%2 + 128*0 + 32*3]
    
    %assign i 1
    %rep 15
        vpcmpeqd ymm14, ymm15, yword [rel .select_idxs + 32*i]
        vpand ymm13, ymm14, yword [%2 + 128*i + 32*0]
        vpor ymm0, ymm0, ymm13
        vpand ymm13, ymm14, yword [%2 + 128*i + 32*1]
        vpor ymm1, ymm1, ymm13
        vpand ymm13, ymm14, yword [%2 + 128*i + 32*2]
        vpor ymm2, ymm2, ymm13
        vpand ymm13, ymm14, yword [%2 + 128*i + 32*3]
        vpor ymm3, ymm3, ymm13
        %assign i i+1
    %endrep
    
    vpcmpeqd ymm14, ymm15, yword [rel .select_neutral_idx]
    vpand ymm13, ymm14, yword [rel .const_y0_is_1]
    vpor ymm1, ymm1, ymm13
%endmacro

%macro select_consts 0
    align 32, db 0
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
%endmacro

%endif