; Select an element from a lookup table
;
; Author: Amber Sprenkels <amber@electricdusk.com>

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
    ;   - ymm0: {X[0]-X[3]}
    ;   - ymm1: {X[4]-X[7]}
    ;   - ymm2: {X[8]-Y[1]}
    ;   - ymm3: {Y[2]-Y[5]}
    ;   - ymm4: {Y[6]-Y[9]}
    ;   - ymm5: {Z[0]-Z[3]}
    ;   - ymm6: {Z[4]-Z[7]}
    ;   - xmm7: {Z[8]-Z[9]}

    ; conditionally move the elements from ptable
    
    cmp %1, 1
    sbb rax, rax
    
    %assign i 0
    %rep 15
        vmovq xmm15, rax
        vpbroadcastq ymm15, xmm15

        ; Immediately precompute the mask for the next round
        xor rax, rax
        cmp %1, i+1
        sete al
        neg rax

        %assign j 0
        %rep 7
            vpand ymm14, ymm15, yword [%2 + 240*i + 32*j]
            vpor ymm%[j], ymm%[j], ymm14
            %assign j j+1
        %endrep
        vpand xmm14, xmm15, oword [%2 + 240*i + 32*7]
        vpor xmm7, xmm7, xmm14

        %assign i i+1
    %endrep
    
    vmovq xmm15, rax
    vpbroadcastq ymm15, xmm15

    ; Immediately precompute the mask for the neutral-element round
    xor rax, rax
    cmp %1, 31
    sete al

    %assign j 0
    %rep 7
        vpand ymm14, ymm15, yword [%2 + 240*i + 32*j]
        vpor ymm%[j], ymm%[j], ymm14
        %assign j j+1
    %endrep
    vpand xmm14, xmm15, oword [%2 + 240*i + 32*7]
    vpor xmm7, xmm7, xmm14

    ; conditionally move the neutral element if idx == 31
    vmovq xmm14, rax
    vpbroadcastq ymm14, xmm14
    vpxor ymm15, ymm15, ymm15
    vpblendd ymm15, ymm15, ymm14, 0b00110000
    vpor ymm2, ymm2, ymm15
%endmacro
