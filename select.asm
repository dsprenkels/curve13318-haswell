; Test function for lookup table scanning

%include "select.mac.asm"

global crypto_scalarmult_curve13318_avx2_select

section .text

crypto_scalarmult_curve13318_avx2_select:
    select rsi, rdx
    vmovdqa yword [rdi + 32*0], ymm0
    vmovdqa yword [rdi + 32*1], ymm1
    vmovdqa yword [rdi + 32*2], ymm2
    vmovdqa yword [rdi + 32*3], ymm3
    ret

section .rodata
select_consts

