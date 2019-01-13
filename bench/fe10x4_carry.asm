; Benchmarks for field carry
;
; Author: Amber Sprenkels <amber@electricdusk.com>

%include "bench.asm"
%include "../fe10x4_carry.asm"

section .rodata:

_bench1_name: db `fe10x4_carry\0`

align 8, db 0
_bench_fns_arr: dq fe10x4_carry
_bench_names_arr: dq _bench1_name
_bench_fns: dq _bench_fns_arr
_bench_names: dq _bench_names_arr
_bench_fns_n: dd 1

section .bss
align 32
scratch_space: resb 1536

section .text

fe10x4_carry:
    bench_prologue
    fe10x4_carry_body
    bench_epilogue
    ret

section .rodata
fe10x4_carry_consts