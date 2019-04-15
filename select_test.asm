; Test function for lookup table scanning

%include "select.asm"

global crypto_scalarmult_curve13318_avx2_select

section .text

crypto_scalarmult_curve13318_avx2_select:
    vpxor ymm0, ymm0, ymm0
    vpxor ymm1, ymm1, ymm1
    vpxor ymm2, ymm2, ymm2
    vpxor ymm3, ymm3, ymm3
    vpxor ymm4, ymm4, ymm4
    vpxor ymm5, ymm5, ymm5
    vpxor ymm6, ymm6, ymm6
    vpxor xmm7, xmm7, xmm7
    select rsi, rdx
    vmovdqa yword [rdi + 32*0], ymm0
    vmovdqa yword [rdi + 32*1], ymm1
    vmovdqa yword [rdi + 32*2], ymm2
    vmovdqa yword [rdi + 32*3], ymm3
    vmovdqa yword [rdi + 32*4], ymm4
    vmovdqa yword [rdi + 32*5], ymm5
    vmovdqa yword [rdi + 32*6], ymm6
    vmovdqa oword [rdi + 32*7], xmm7
    ret

