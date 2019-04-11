; Benchmarks for some shuffling ops
;
; Author: Amber Sprenkels <amber@electricdusk.com>

%include "bench.asm"

_bench1_name: db `vpermilpd_vpextrq\0`
_bench2_name: db `vpermilpd_vpermilpd\0`

align 8, db 0
_bench_fns_arr:
dq vpermilpd_vpextrq, vpermilpd_vpermilpd

_bench_names_arr:
dq _bench1_name, _bench2_name

_bench_fns: dq _bench_fns_arr
_bench_names: dq _bench_names_arr
_bench_fns_n: dd 2

section .bss
align 32
scratch_space: resb 1536

section .text

vpermilpd_vpextrq:
    bench_prologue
    %assign i 0
    %rep 1000
        vpextrq rax, xmm%[i], 1
        vmovq r8, xmm%[i]
        add rax, r8
        %assign i (i + 1) % 10
    %endrep
    bench_epilogue
    ret

vpermilpd_vpermilpd:
    bench_prologue
    vpxor ymm15, ymm15, ymm15
    %assign i 0
    %rep 1000
        vpermilpd xmm15, xmm%[i], 0b11
        vpaddq xmm%[i], xmm%[i], xmm15
        vmovq qword [rel scratch_space], xmm%[i]
        %assign i (i + 1) % 10
    %endrep
    bench_epilogue
    ret
