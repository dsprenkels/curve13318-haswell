; Benchmarks for field multiplication
;
; Author: Amber Sprenkels <amber@electricdusk.com>

%include "bench.asm"

section .rodata:

_bench1_name: db `fe10x4_mul_orig\0`
_bench2_name: db `fe10x4_mul_vpmuludq19\0`
_bench3_name: db `fe10x4_mul_vpsllq\0`
_bench4_name: db `fe10x4_mul_easy_reorder\0`
_bench5_name: db `fe10x4_mul_vpmuludq19_2\0`
_bench6_name: db `fe10x4_mul_shortened\0`

align 8, db 0
_bench_fns_arr:
dq fe10x4_mul_orig, fe10x4_mul_vpmuludq19, fe10x4_mul_vpsllq, fe10x4_mul_easy_reorder, fe10x4_mul_vpmuludq19_2, fe10x4_mul_shortened

_bench_names_arr:
dq _bench1_name, _bench2_name, _bench3_name, _bench4_name, _bench5_name, _bench6_name

_bench_fns: dq _bench_fns_arr
_bench_names: dq _bench_names_arr
_bench_fns_n: dd 6

section .bss
align 32
scratch_space: resb 1536

section .text

fe10x4_mul_orig:
    ; The multipliction in this routine is based on the multiplication as described in [NeonCrypto].
    ; Tl;dr. We precompute in parallel:
    ;   - (19*g_1, ..., 19*g_9)
    ;   - (2*f_1, 2*f_3, ... 2*f_9)
    ; Then we do a regular O(n^2) modular multiplication.
    ; 
    ; Inputs:
    ;   - rdi: Product `h` of `f` and `g`
    ;   - rsi: Operand `f`
    ;   - rdx: Operand `g`
    ;
    ; Useful reciprocal throughputs:
    ;   - pmuludq:     1.0 cycle @ p0
    ;   - paddq/psubq: 0.5 cycle @ p15
    ;   - psllq:       1.0 cycle @ p0
    ; ^ We see that uops from vpmuludq/vpsllq collide on port 0. vpmuludq is a lot more powerful,
    ;   so we don't need to use it, unless p23 pressure or latency is relevant at some point.
    ;
    ; Analysis of op counts:
    ;   - n^2 multiplications: 100 vpmuludq
    ;   - *19 precomputation:    9 vpmuludq
    ;   - accumulate:           90 vpaddq/vpsubq
    ;   - add precomputation:    5 vpaddq/vpsubq
    ;   = 109*p0 + 47.5*p15
    ; An addition chain to 19:
    ;   - 1 -> 2 -> 4 (-> 3) -> 8 -> 16 -> 19: 6 paddq/psubq = 3*p15
    ;   - If we do 9 of these chains, instead of their respective pmuludq's, we get:
    ;   = 100*p0 + 74.5*p15
    ; So we opt to compute the (19*) by addition chain (or hybrid).
    ;
    ; TODO(dsprenkels) The Haswell microarchitercture front-end has two types of decoders:
    ;   - 1 decoder that can decode instructions with up to 4 micro ops.
    ;   - 3 decoders that decode only instructions with a single micro ops.
    ; llvm-mca says that the dispatch width on haswell is 4 micro ops in any case. In this respect,
    ; all the `vpmuludq`/`vpaddq` pairs kill the decode performance, because they allow only the
    ; dispatch of 3 micro ops.
    ; To fix the performance, I could split multi-micro op instructions (`vpmuludq`s with
    ; immediate addresses) into a separate `vpmuludq`s and `vmovdqa`s to parallelize the decode.
    ; Downside: This may degrade the performance by incidentally killing the fetch bandwith.
    ; NOTE! This reasoning does not take microfusion into account! (Actually, I cannot reconstruct
    ; the dispatch pattern from llvm-mca from the Intel docs. I should probably benchmark first,
    ; maybe there's stuff thats not implemented in the CPU model in LLVM.)
    ;
    ; TODO(dsprenkels) We must benchmark if this is actually better inside the ge_* routines.
    ;
    lea rdi, [rel scratch_space]
    lea rsi, [rel scratch_space+320]
    bench_prologue
    lea rdx, [rel scratch_space+640]

    sub rsp, 10*32

    ; round 1/10
    vmovdqa ymm15, yword [rsi + 0*32]
    vpmuludq ymm0, ymm15, yword [rdx + 0*32]
    vpmuludq ymm1, ymm15, yword [rdx + 1*32]
    vpmuludq ymm2, ymm15, yword [rdx + 2*32]
    vpmuludq ymm3, ymm15, yword [rdx + 3*32]
    vpmuludq ymm4, ymm15, yword [rdx + 4*32]
    vpmuludq ymm5, ymm15, yword [rdx + 5*32]
    vpmuludq ymm6, ymm15, yword [rdx + 6*32]
    vpmuludq ymm7, ymm15, yword [rdx + 7*32]
    vpmuludq ymm8, ymm15, yword [rdx + 8*32]
    vpmuludq ymm9, ymm15, yword [rdx + 9*32]

    ; round 2/10
    vmovdqa ymm15, yword [rsi + 1*32]        ; load f[1]
    vpaddq ymm14, ymm15, ymm15              ; compute 2*f[1]
    vmovdqa ymm13, yword [rdx + 9*32]        ;  1*g[9] 
    vpaddq ymm10, ymm13, ymm13              ;  2*g[9]
    vpaddq ymm13, ymm10, ymm13              ;  3*g[9]
    vpaddq ymm10, ymm10, ymm10              ;  4*g[9]
    vpaddq ymm10, ymm10, ymm10              ;  8*g[9]
    vpaddq ymm10, ymm10, ymm10              ; 16*g[9]
    vpaddq ymm13, ymm10, ymm13              ; compute 19*g[9]
    vmovdqa yword [rsp + 9*32], ymm13        ; spill 19*g[9]

    vpmuludq ymm10, ymm14, ymm13
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 1*32]
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 2*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 3*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 4*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 5*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 6*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 7*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 8*32]
    vpaddq ymm9, ymm9, ymm10

    ; round 3/10
    vmovdqa ymm15, yword [rsi + 2*32]        ; load f[2]
    vmovdqa ymm12, yword [rdx + 8*32]        ;  1*g[8] 
    vpaddq ymm10, ymm12, ymm12              ;  2*g[8]
    vpaddq ymm12, ymm10, ymm12              ;  3*g[8]
    vpaddq ymm10, ymm10, ymm10              ;  4*g[8]
    vpaddq ymm10, ymm10, ymm10              ;  8*g[8]
    vpaddq ymm10, ymm10, ymm10              ; 16*g[8]
    vpaddq ymm12, ymm10, ymm12              ; compute 19*g[8]
    vmovdqa yword [rsp + 8*32], ymm12        ; spill 19*g[8]

    vpmuludq ymm10, ymm15, ymm12
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm13
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 1*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 2*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 3*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 4*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 5*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 6*32]
    vpaddq ymm8, ymm8, ymm10    
    vpmuludq ymm10, ymm15, yword [rdx + 7*32]
    vpaddq ymm9, ymm9, ymm10

    ; Round 4/10
    vmovdqa ymm15, yword [rsi + 3*32]        ; load f[3]
    vpaddq ymm14, ymm15, ymm15              ; compute 2*f[3]             
    vmovdqa ymm11, yword [rdx + 7*32]        ;  1*g[7] 
    vpaddq ymm10, ymm11, ymm11              ;  2*g[7]
    vpaddq ymm11, ymm10, ymm11              ;  3*g[7]
    vpaddq ymm10, ymm10, ymm10              ;  4*g[7]
    vpaddq ymm10, ymm10, ymm10              ;  8*g[7]
    vpaddq ymm10, ymm10, ymm10              ; 16*g[7]
    vpaddq ymm11, ymm10, ymm11              ; compute 19*g[7]
    vmovdqa yword [rsp + 7*32], ymm11        ; spill 19*g[7]

    vpmuludq ymm10, ymm14, ymm11
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm12
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm14, ymm13
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 1*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 2*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 3*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 4*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 5*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 6*32]
    vpaddq ymm9, ymm9, ymm10

    ; Round 5/10
    vmovdqa ymm15, yword [rsi + 4*32]        ; load f[4]
    vmovdqa ymm13, yword [rdx + 6*32]        ;  1*g[6] 
    vpaddq ymm10, ymm13, ymm13              ;  2*g[6]
    vpaddq ymm13, ymm10, ymm13              ;  3*g[6]
    vpaddq ymm10, ymm10, ymm10              ;  4*g[6]
    vpaddq ymm10, ymm10, ymm10              ;  8*g[6]
    vpaddq ymm10, ymm10, ymm10              ; 16*g[6]
    vpaddq ymm13, ymm10, ymm13              ; compute 19*g[6]
    vmovdqa yword [rsp + 6*32], ymm13        ; spill 19*g[6]

    vpmuludq ymm10, ymm15, ymm13
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm11
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm15, ymm12
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 9*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 1*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 2*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 3*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 4*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 5*32]
    vpaddq ymm9, ymm9, ymm10

    ; Round 6/10
    vmovdqa ymm15, yword [rsi + 5*32]       ; load f[5]
    vpaddq ymm14, ymm15, ymm15              ; compute 2*f[5]         
    vmovdqa ymm12, yword [rdx + 5*32]       ;  1*g[5] 
    vpaddq ymm10, ymm12, ymm12              ;  2*g[5]
    vpaddq ymm12, ymm10, ymm12              ;  3*g[5]
    vpaddq ymm10, ymm10, ymm10              ;  4*g[5]
    vpaddq ymm10, ymm10, ymm10              ;  8*g[5]
    vpaddq ymm10, ymm10, ymm10              ; 16*g[5]
    vpaddq ymm12, ymm10, ymm12              ; compute 19*g[5]
    vmovdqa yword [rsp + 5*32], ymm12       ; spill 19*g[5]

    vpmuludq ymm10, ymm14, ymm12
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm13
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm14, ymm11
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 8*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm14, yword [rsp + 9*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 1*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 2*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 3*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 4*32]
    vpaddq ymm9, ymm9, ymm10

    ; Round 7/10
    vmovdqa ymm15, yword [rsi + 6*32]        ; load f[6]
    vmovdqa ymm11, yword [rdx + 4*32]        ;  1*g[4] 
    vpaddq ymm10, ymm11, ymm11              ;  2*g[4]
    vpaddq ymm11, ymm10, ymm11              ;  3*g[4]
    vpaddq ymm10, ymm10, ymm10              ;  4*g[4]
    vpaddq ymm10, ymm10, ymm10              ;  8*g[4]
    vpaddq ymm10, ymm10, ymm10              ; 16*g[4]
    vpaddq ymm11, ymm10, ymm11              ; compute 19*g[4]
    vmovdqa yword [rsp + 4*32], ymm11        ; spill 19*g[4]

    vpmuludq ymm10, ymm15, ymm11
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm12
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm15, ymm13
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 7*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 8*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 9*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 1*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 2*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 3*32]
    vpaddq ymm9, ymm9, ymm10

    ; Round 8/10
    vmovdqa ymm15, yword [rsi + 7*32]        ; load f[7]
    vpaddq ymm14, ymm15, ymm15              ; compute 2*f[7]         
    vmovdqa ymm13, yword [rdx + 3*32]        ;  1*g[3] 
    vpaddq ymm10, ymm13, ymm13              ;  2*g[3]
    vpaddq ymm13, ymm10, ymm13              ;  3*g[3]
    vpaddq ymm10, ymm10, ymm10              ;  4*g[3]
    vpaddq ymm10, ymm10, ymm10              ;  8*g[3]
    vpaddq ymm10, ymm10, ymm10              ; 16*g[3]
    vpaddq ymm13, ymm10, ymm13              ; compute 19*g[3]

    vpmuludq ymm10, ymm14, ymm13
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm11
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm14, ymm12
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 6*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm14, yword [rsp + 7*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 8*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm14, yword [rsp + 9*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 1*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 2*32]
    vpaddq ymm9, ymm9, ymm10

    ; Round 9/10
    vmovdqa ymm15, yword [rsi + 8*32]        ; load f[8]
    vmovdqa ymm12, yword [rdx + 2*32]        ;  1*g[2]
    vpaddq ymm10, ymm12, ymm12              ;  2*g[2]
    vpaddq ymm12, ymm10, ymm12              ;  3*g[2]
    vpaddq ymm10, ymm10, ymm10              ;  4*g[2]
    vpaddq ymm10, ymm10, ymm10              ;  8*g[2]
    vpaddq ymm10, ymm10, ymm10              ; 16*g[2]
    vpaddq ymm12, ymm10, ymm12              ; compute 19*g[2]

    vpmuludq ymm10, ymm15, ymm12
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm13
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm15, ymm11
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 5*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 6*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 7*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 8*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 9*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 1*32]
    vpaddq ymm9, ymm9, ymm10

    ; Round 10/10
    vmovdqa ymm15, yword [rsi + 9*32]        ; load f[9]
    vpaddq ymm14, ymm15, ymm15              ; compute 2*f[9]         
    vmovdqa ymm11, yword [rdx + 1*32]        ;  1*g[1] 
    vpaddq ymm10, ymm11, ymm11              ;  2*g[1]
    vpaddq ymm11, ymm10, ymm11              ;  3*g[1]
    vpaddq ymm10, ymm10, ymm10              ;  4*g[1]
    vpaddq ymm10, ymm10, ymm10              ;  8*g[1]
    vpaddq ymm10, ymm10, ymm10              ; 16*g[1]
    vpaddq ymm11, ymm10, ymm11              ; compute 19*g[9]

    vpmuludq ymm10, ymm14, ymm11
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm12
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm14, ymm13
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 4*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm14, yword [rsp + 5*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 6*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm14, yword [rsp + 7*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 8*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm14, yword [rsp + 9*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm9, ymm9, ymm10

    vmovdqa yword [rdi + 0*32], ymm0
    vmovdqa yword [rdi + 1*32], ymm1
    vmovdqa yword [rdi + 2*32], ymm2
    vmovdqa yword [rdi + 3*32], ymm3
    vmovdqa yword [rdi + 4*32], ymm4
    vmovdqa yword [rdi + 5*32], ymm5
    vmovdqa yword [rdi + 6*32], ymm6
    vmovdqa yword [rdi + 7*32], ymm7
    vmovdqa yword [rdi + 8*32], ymm8
    vmovdqa yword [rdi + 9*32], ymm9

    bench_epilogue
    ret

fe10x4_mul_vpmuludq19:
    lea rdi, [rel scratch_space]
    lea rsi, [rel scratch_space+320]
    bench_prologue
    lea rdx, [rel scratch_space+640]

    sub rsp, 10*32

    ; round 1/10
    vmovdqa ymm15, yword [rsi + 0*32]
    vpmuludq ymm0, ymm15, yword [rdx + 0*32]
    vpmuludq ymm1, ymm15, yword [rdx + 1*32]
    vpmuludq ymm2, ymm15, yword [rdx + 2*32]
    vpmuludq ymm3, ymm15, yword [rdx + 3*32]
    vpmuludq ymm4, ymm15, yword [rdx + 4*32]
    vpmuludq ymm5, ymm15, yword [rdx + 5*32]
    vpmuludq ymm6, ymm15, yword [rdx + 6*32]
    vpmuludq ymm7, ymm15, yword [rdx + 7*32]
    vpmuludq ymm8, ymm15, yword [rdx + 8*32]
    vpmuludq ymm9, ymm15, yword [rdx + 9*32]

    ; round 2/10
    vmovdqa ymm15, yword [rsi + 1*32]        ; load f[1]
    vpaddq ymm14, ymm15, ymm15              ; compute 2*f[1]
    vmovdqa ymm13, yword [rdx + 9*32]        ;  1*g[9] 
    vpaddq ymm10, ymm13, ymm13              ;  2*g[9]
    vpaddq ymm13, ymm10, ymm13              ;  3*g[9]
    vpaddq ymm10, ymm10, ymm10              ;  4*g[9]
    vpaddq ymm10, ymm10, ymm10              ;  8*g[9]
    vpaddq ymm10, ymm10, ymm10              ; 16*g[9]
    vpaddq ymm13, ymm10, ymm13              ; compute 19*g[9]
    vmovdqa yword [rsp + 9*32], ymm13        ; spill 19*g[9]

    vpmuludq ymm10, ymm14, ymm13
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 1*32]
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 2*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 3*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 4*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 5*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 6*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 7*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 8*32]
    vpaddq ymm9, ymm9, ymm10

    ; round 3/10
    vmovdqa ymm15, yword [rsi + 2*32]        ; load f[2]
    vmovdqa ymm12, yword [rdx + 8*32]        ;  1*g[8] 
    vpmuludq ymm12, ymm12, yword [rel .const_19]    ; compute 19*g[8]
    vmovdqa yword [rsp + 8*32], ymm12        ; spill 19*g[8]

    vpmuludq ymm10, ymm15, ymm12
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm13
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 1*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 2*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 3*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 4*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 5*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 6*32]
    vpaddq ymm8, ymm8, ymm10    
    vpmuludq ymm10, ymm15, yword [rdx + 7*32]
    vpaddq ymm9, ymm9, ymm10

    ; Round 4/10
    vmovdqa ymm15, yword [rsi + 3*32]        ; load f[3]
    vpaddq ymm14, ymm15, ymm15              ; compute 2*f[3]             
    vmovdqa ymm11, yword [rdx + 7*32]        ;  1*g[7] 
    vpmuludq ymm11, ymm11, yword [rel .const_19]    ; compute 19*g[7]
    vmovdqa yword [rsp + 7*32], ymm11        ; spill 19*g[7]

    vpmuludq ymm10, ymm14, ymm11
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm12
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm14, ymm13
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 1*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 2*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 3*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 4*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 5*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 6*32]
    vpaddq ymm9, ymm9, ymm10

    ; Round 5/10
    vmovdqa ymm15, yword [rsi + 4*32]        ; load f[4]
    vmovdqa ymm13, yword [rdx + 6*32]        ;  1*g[6] 
    vpmuludq ymm13, ymm13, yword [rel .const_19]    ; compute 19*g[6]
    vmovdqa yword [rsp + 6*32], ymm13        ; spill 19*g[6]

    vpmuludq ymm10, ymm15, ymm13
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm11
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm15, ymm12
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 9*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 1*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 2*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 3*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 4*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 5*32]
    vpaddq ymm9, ymm9, ymm10

    ; Round 6/10
    vmovdqa ymm15, yword [rsi + 5*32]       ; load f[5]
    vpaddq ymm14, ymm15, ymm15              ; compute 2*f[5]         
    vmovdqa ymm12, yword [rdx + 5*32]       ;  1*g[5]
    vpmuludq ymm12, ymm12, yword [rel .const_19]    ; compute 19*g[5] 
    vmovdqa yword [rsp + 5*32], ymm12       ; spill 19*g[5]

    vpmuludq ymm10, ymm14, ymm12
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm13
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm14, ymm11
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 8*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm14, yword [rsp + 9*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 1*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 2*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 3*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 4*32]
    vpaddq ymm9, ymm9, ymm10

    ; Round 7/10
    vmovdqa ymm15, yword [rsi + 6*32]        ; load f[6]
    vmovdqa ymm11, yword [rdx + 4*32]        ;  1*g[4]
    vpmuludq ymm11, ymm11, yword [rel .const_19]    ; compute 19*g[4]
    vmovdqa yword [rsp + 4*32], ymm11        ; spill 19*g[4]

    vpmuludq ymm10, ymm15, ymm11
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm12
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm15, ymm13
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 7*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 8*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 9*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 1*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 2*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 3*32]
    vpaddq ymm9, ymm9, ymm10

    ; Round 8/10
    vmovdqa ymm15, yword [rsi + 7*32]        ; load f[7]
    vpaddq ymm14, ymm15, ymm15              ; compute 2*f[7]         
    vmovdqa ymm13, yword [rdx + 3*32]        ;  1*g[3] 
    vpmuludq ymm13, ymm13, yword [rel .const_19]    ; compute 19*g[8]

    vpmuludq ymm10, ymm14, ymm13
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm11
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm14, ymm12
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 6*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm14, yword [rsp + 7*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 8*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm14, yword [rsp + 9*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 1*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 2*32]
    vpaddq ymm9, ymm9, ymm10

    ; Round 9/10
    vmovdqa ymm15, yword [rsi + 8*32]        ; load f[8]
    vmovdqa ymm12, yword [rdx + 2*32]        ;  1*g[2]
    vpmuludq ymm12, ymm12, yword [rel .const_19]    ; compute 19*g[2]

    vpmuludq ymm10, ymm15, ymm12
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm13
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm15, ymm11
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 5*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 6*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 7*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 8*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 9*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 1*32]
    vpaddq ymm9, ymm9, ymm10

    ; Round 10/10
    vmovdqa ymm15, yword [rsi + 9*32]        ; load f[9]
    vpaddq ymm14, ymm15, ymm15              ; compute 2*f[9]         
    vmovdqa ymm11, yword [rdx + 1*32]        ;  1*g[1] 
    vpmuludq ymm11, ymm11, yword [rel .const_19]    ; compute 19*g[1]

    vpmuludq ymm10, ymm14, ymm11
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm12
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm14, ymm13
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 4*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm14, yword [rsp + 5*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 6*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm14, yword [rsp + 7*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 8*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm14, yword [rsp + 9*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm9, ymm9, ymm10

    vmovdqa yword [rdi + 0*32], ymm0
    vmovdqa yword [rdi + 1*32], ymm1
    vmovdqa yword [rdi + 2*32], ymm2
    vmovdqa yword [rdi + 3*32], ymm3
    vmovdqa yword [rdi + 4*32], ymm4
    vmovdqa yword [rdi + 5*32], ymm5
    vmovdqa yword [rdi + 6*32], ymm6
    vmovdqa yword [rdi + 7*32], ymm7
    vmovdqa yword [rdi + 8*32], ymm8
    vmovdqa yword [rdi + 9*32], ymm9

    bench_epilogue
    ret

section .rodata:
align 32, db 0
.const_19: times 4 dq 19

fe10x4_mul_vpsllq:
    lea rdi, [rel scratch_space]
    lea rsi, [rel scratch_space+320]
    bench_prologue
    lea rdx, [rel scratch_space+640]

    sub rsp, 10*32

    ; round 1/10
    vmovdqa ymm15, yword [rsi + 0*32]
    vpmuludq ymm0, ymm15, yword [rdx + 0*32]
    vpmuludq ymm1, ymm15, yword [rdx + 1*32]
    vpmuludq ymm2, ymm15, yword [rdx + 2*32]
    vpmuludq ymm3, ymm15, yword [rdx + 3*32]
    vpmuludq ymm4, ymm15, yword [rdx + 4*32]
    vpmuludq ymm5, ymm15, yword [rdx + 5*32]
    vpmuludq ymm6, ymm15, yword [rdx + 6*32]
    vpmuludq ymm7, ymm15, yword [rdx + 7*32]
    vpmuludq ymm8, ymm15, yword [rdx + 8*32]
    vpmuludq ymm9, ymm15, yword [rdx + 9*32]

    ; round 2/10
    vmovdqa ymm15, yword [rsi + 1*32]       ; load f[1]
    vpaddq ymm14, ymm15, ymm15              ; compute 2*f[1]
    vmovdqa ymm13, yword [rdx + 9*32]       ;  1*g[9] 
    vpaddq ymm10, ymm13, ymm13              ;  2*g[9]
    vpaddq ymm13, ymm10, ymm13              ;  3*g[9]
    vpsllq ymm10, ymm10, 3                  ; 16*g[9]
    vpaddq ymm13, ymm10, ymm13              ; compute 19*g[9]
    vmovdqa yword [rsp + 9*32], ymm13       ; spill 19*g[9]

    vpmuludq ymm10, ymm14, ymm13
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 1*32]
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 2*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 3*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 4*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 5*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 6*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 7*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 8*32]
    vpaddq ymm9, ymm9, ymm10

    ; round 3/10
    vmovdqa ymm15, yword [rsi + 2*32]       ; load f[2]
    vmovdqa ymm12, yword [rdx + 8*32]       ;  1*g[8] 
    vpaddq ymm10, ymm12, ymm12              ;  2*g[8]
    vpaddq ymm12, ymm10, ymm12              ;  3*g[8]
    vpsllq ymm10, ymm10, 3                  ; 16*g[9]
    vpaddq ymm12, ymm10, ymm12              ; compute 19*g[8]
    vmovdqa yword [rsp + 8*32], ymm12       ; spill 19*g[8]

    vpmuludq ymm10, ymm15, ymm12
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm13
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 1*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 2*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 3*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 4*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 5*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 6*32]
    vpaddq ymm8, ymm8, ymm10    
    vpmuludq ymm10, ymm15, yword [rdx + 7*32]
    vpaddq ymm9, ymm9, ymm10

    ; Round 4/10
    vmovdqa ymm15, yword [rsi + 3*32]       ; load f[3]
    vpaddq ymm14, ymm15, ymm15              ; compute 2*f[3]             
    vmovdqa ymm11, yword [rdx + 7*32]       ;  1*g[7] 
    vpaddq ymm10, ymm11, ymm11              ;  2*g[7]
    vpaddq ymm11, ymm10, ymm11              ;  3*g[7]
    vpsllq ymm10, ymm10, 3                  ; 16*g[9]
    vpaddq ymm11, ymm10, ymm11              ; compute 19*g[7]
    vmovdqa yword [rsp + 7*32], ymm11       ; spill 19*g[7]

    vpmuludq ymm10, ymm14, ymm11
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm12
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm14, ymm13
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 1*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 2*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 3*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 4*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 5*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 6*32]
    vpaddq ymm9, ymm9, ymm10

    ; Round 5/10
    vmovdqa ymm15, yword [rsi + 4*32]       ; load f[4]
    vmovdqa ymm13, yword [rdx + 6*32]       ;  1*g[6] 
    vpaddq ymm10, ymm13, ymm13              ;  2*g[6]
    vpaddq ymm13, ymm10, ymm13              ;  3*g[6]
    vpsllq ymm10, ymm10, 3                  ; 16*g[9]
    vpaddq ymm13, ymm10, ymm13              ; compute 19*g[6]
    vmovdqa yword [rsp + 6*32], ymm13       ; spill 19*g[6]

    vpmuludq ymm10, ymm15, ymm13
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm11
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm15, ymm12
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 9*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 1*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 2*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 3*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 4*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 5*32]
    vpaddq ymm9, ymm9, ymm10

    ; Round 6/10
    vmovdqa ymm15, yword [rsi + 5*32]       ; load f[5]
    vpaddq ymm14, ymm15, ymm15              ; compute 2*f[5]         
    vmovdqa ymm12, yword [rdx + 5*32]       ;  1*g[5] 
    vpaddq ymm10, ymm12, ymm12              ;  2*g[5]
    vpaddq ymm12, ymm10, ymm12              ;  3*g[5]
    vpsllq ymm10, ymm10, 3                  ; 16*g[9]
    vpaddq ymm12, ymm10, ymm12              ; compute 19*g[5]
    vmovdqa yword [rsp + 5*32], ymm12       ; spill 19*g[5]

    vpmuludq ymm10, ymm14, ymm12
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm13
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm14, ymm11
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 8*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm14, yword [rsp + 9*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 1*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 2*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 3*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 4*32]
    vpaddq ymm9, ymm9, ymm10

    ; Round 7/10
    vmovdqa ymm15, yword [rsi + 6*32]       ; load f[6]
    vmovdqa ymm11, yword [rdx + 4*32]        ;  1*g[4] 
    vpaddq ymm10, ymm11, ymm11              ;  2*g[4]
    vpaddq ymm11, ymm10, ymm11              ;  3*g[4]
    vpsllq ymm10, ymm10, 3                  ; 16*g[9]
    vpaddq ymm11, ymm10, ymm11              ; compute 19*g[4]
    vmovdqa yword [rsp + 4*32], ymm11       ; spill 19*g[4]

    vpmuludq ymm10, ymm15, ymm11
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm12
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm15, ymm13
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 7*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 8*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 9*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 1*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 2*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 3*32]
    vpaddq ymm9, ymm9, ymm10

    ; Round 8/10
    vmovdqa ymm15, yword [rsi + 7*32]       ; load f[7]
    vpaddq ymm14, ymm15, ymm15              ; compute 2*f[7]         
    vmovdqa ymm13, yword [rdx + 3*32]       ;  1*g[3] 
    vpaddq ymm10, ymm13, ymm13              ;  2*g[3]
    vpaddq ymm13, ymm10, ymm13              ;  3*g[3]
    vpsllq ymm10, ymm10, 3                  ; 16*g[9]
    vpaddq ymm13, ymm10, ymm13              ; compute 19*g[3]

    vpmuludq ymm10, ymm14, ymm13
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm11
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm14, ymm12
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 6*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm14, yword [rsp + 7*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 8*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm14, yword [rsp + 9*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 1*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 2*32]
    vpaddq ymm9, ymm9, ymm10

    ; Round 9/10
    vmovdqa ymm15, yword [rsi + 8*32]       ; load f[8]
    vmovdqa ymm12, yword [rdx + 2*32]       ;  1*g[2]
    vpaddq ymm10, ymm12, ymm12              ;  2*g[2]
    vpaddq ymm12, ymm10, ymm12              ;  3*g[2]
    vpsllq ymm10, ymm10, 3                  ; 16*g[9]
    vpaddq ymm12, ymm10, ymm12              ; compute 19*g[2]

    vpmuludq ymm10, ymm15, ymm12
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm13
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm15, ymm11
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 5*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 6*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 7*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 8*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 9*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 1*32]
    vpaddq ymm9, ymm9, ymm10

    ; Round 10/10
    vmovdqa ymm15, yword [rsi + 9*32]       ; load f[9]
    vpaddq ymm14, ymm15, ymm15              ; compute 2*f[9]         
    vmovdqa ymm11, yword [rdx + 1*32]       ;  1*g[1] 
    vpaddq ymm10, ymm11, ymm11              ;  2*g[1]
    vpaddq ymm11, ymm10, ymm11              ;  3*g[1]
    vpsllq ymm10, ymm10, 3                  ; 16*g[9]
    vpaddq ymm11, ymm10, ymm11              ; compute 19*g[9]

    vpmuludq ymm10, ymm14, ymm11
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm12
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm14, ymm13
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 4*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm14, yword [rsp + 5*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 6*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm14, yword [rsp + 7*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 8*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm14, yword [rsp + 9*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm9, ymm9, ymm10

    vmovdqa yword [rdi + 0*32], ymm0
    vmovdqa yword [rdi + 1*32], ymm1
    vmovdqa yword [rdi + 2*32], ymm2
    vmovdqa yword [rdi + 3*32], ymm3
    vmovdqa yword [rdi + 4*32], ymm4
    vmovdqa yword [rdi + 5*32], ymm5
    vmovdqa yword [rdi + 6*32], ymm6
    vmovdqa yword [rdi + 7*32], ymm7
    vmovdqa yword [rdi + 8*32], ymm8
    vmovdqa yword [rdi + 9*32], ymm9

    bench_epilogue
    ret

fe10x4_mul_easy_reorder:
    lea rdi, [rel scratch_space]
    lea rsi, [rel scratch_space+320]
    bench_prologue
    lea rdx, [rel scratch_space+640]

    sub rsp, 10*32

    ; round 1/10
    vmovdqa ymm15, yword [rsi + 0*32]
    vpmuludq ymm0, ymm15, yword [rdx + 0*32]
    vpmuludq ymm1, ymm15, yword [rdx + 1*32]
    vpmuludq ymm2, ymm15, yword [rdx + 2*32]
    vpmuludq ymm3, ymm15, yword [rdx + 3*32]
    vpmuludq ymm4, ymm15, yword [rdx + 4*32]
    vpmuludq ymm5, ymm15, yword [rdx + 5*32]
    vpmuludq ymm6, ymm15, yword [rdx + 6*32]
    vpmuludq ymm7, ymm15, yword [rdx + 7*32]
    vpmuludq ymm8, ymm15, yword [rdx + 8*32]
    vpmuludq ymm9, ymm15, yword [rdx + 9*32]

    ; round 2/10
    vmovdqa ymm15, yword [rsi + 1*32]       ; load f[1]
    vpaddq ymm14, ymm15, ymm15              ; compute 2*f[1]
    vmovdqa ymm13, yword [rdx + 9*32]       ;  1*g[9] 
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm1, ymm1, ymm10
    vpaddq ymm10, ymm13, ymm13              ;  2*g[9]
    vpaddq ymm13, ymm10, ymm13              ;  3*g[9]
    vpaddq ymm10, ymm10, ymm10              ;  4*g[9]
    vpaddq ymm10, ymm10, ymm10              ;  8*g[9]
    vpaddq ymm10, ymm10, ymm10              ; 16*g[9]
    vpaddq ymm13, ymm10, ymm13              ; compute 19*g[9]
    vmovdqa yword [rsp + 9*32], ymm13       ; spill 19*g[9]

    vpmuludq ymm10, ymm14, yword [rdx + 1*32]
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 2*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 3*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 4*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 5*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 6*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 7*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 8*32]
    vpaddq ymm9, ymm9, ymm10
    vpmuludq ymm10, ymm14, ymm13
    vpaddq ymm0, ymm0, ymm10

    ; round 3/10
    vmovdqa ymm15, yword [rsi + 2*32]       ; load f[2]
    vmovdqa ymm12, yword [rdx + 8*32]       ;  1*g[8] 
    vpmuludq ymm10, ymm15, ymm13
    vpaddq ymm1, ymm1, ymm10
    vpaddq ymm10, ymm12, ymm12              ;  2*g[8]
    vpaddq ymm12, ymm10, ymm12              ;  3*g[8]
    vpaddq ymm10, ymm10, ymm10              ;  4*g[8]
    vpaddq ymm10, ymm10, ymm10              ;  8*g[8]
    vpaddq ymm10, ymm10, ymm10              ; 16*g[8]
    vpaddq ymm12, ymm10, ymm12              ; compute 19*g[8]
    vmovdqa yword [rsp + 8*32], ymm12       ; spill 19*g[8]

    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 1*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 2*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 3*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 4*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 5*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 6*32]
    vpaddq ymm8, ymm8, ymm10    
    vpmuludq ymm10, ymm15, yword [rdx + 7*32]
    vpaddq ymm9, ymm9, ymm10
    vpmuludq ymm10, ymm15, ymm12
    vpaddq ymm0, ymm0, ymm10

    ; Round 4/10
    vmovdqa ymm15, yword [rsi + 3*32]       ; load f[3]
    vpaddq ymm14, ymm15, ymm15              ; compute 2*f[3]             
    vmovdqa ymm11, yword [rdx + 7*32]       ;  1*g[7] 
    vpmuludq ymm10, ymm15, ymm12
    vpaddq ymm1, ymm1, ymm10
    vpaddq ymm10, ymm11, ymm11              ;  2*g[7]
    vpaddq ymm11, ymm10, ymm11              ;  3*g[7]
    vpaddq ymm10, ymm10, ymm10              ;  4*g[7]
    vpaddq ymm10, ymm10, ymm10              ;  8*g[7]
    vpaddq ymm10, ymm10, ymm10              ; 16*g[7]
    vpaddq ymm11, ymm10, ymm11              ; compute 19*g[7]
    vmovdqa yword [rsp + 7*32], ymm11       ; spill 19*g[7]

    vpmuludq ymm10, ymm14, ymm13
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 1*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 2*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 3*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 4*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 5*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 6*32]
    vpaddq ymm9, ymm9, ymm10
    vpmuludq ymm10, ymm14, ymm11
    vpaddq ymm0, ymm0, ymm10

    ; Round 5/10
    vmovdqa ymm15, yword [rsi + 4*32]       ; load f[4]
    vmovdqa ymm13, yword [rdx + 6*32]       ;  1*g[6] 
    vpmuludq ymm10, ymm15, ymm11
    vpaddq ymm1, ymm1, ymm10
    vpaddq ymm10, ymm13, ymm13              ;  2*g[6]
    vpaddq ymm13, ymm10, ymm13              ;  3*g[6]
    vpaddq ymm10, ymm10, ymm10              ;  4*g[6]
    vpaddq ymm10, ymm10, ymm10              ;  8*g[6]
    vpaddq ymm10, ymm10, ymm10              ; 16*g[6]
    vpaddq ymm13, ymm10, ymm13              ; compute 19*g[6]
    vmovdqa yword [rsp + 6*32], ymm13       ; spill 19*g[6]

    vpmuludq ymm10, ymm15, ymm12
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 9*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 1*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 2*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 3*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 4*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 5*32]
    vpaddq ymm9, ymm9, ymm10
    vpmuludq ymm10, ymm15, ymm13
    vpaddq ymm0, ymm0, ymm10

    ; Round 6/10
    vmovdqa ymm15, yword [rsi + 5*32]       ; load f[5]
    vpaddq ymm14, ymm15, ymm15              ; compute 2*f[5]         
    vpmuludq ymm10, ymm15, ymm13
    vpaddq ymm1, ymm1, ymm10
    vmovdqa ymm12, yword [rdx + 5*32]       ;  1*g[5] 
    vpaddq ymm10, ymm12, ymm12              ;  2*g[5]
    vpaddq ymm12, ymm10, ymm12              ;  3*g[5]
    vpaddq ymm10, ymm10, ymm10              ;  4*g[5]
    vpaddq ymm10, ymm10, ymm10              ;  8*g[5]
    vpaddq ymm10, ymm10, ymm10              ; 16*g[5]
    vpaddq ymm12, ymm10, ymm12              ; compute 19*g[5]
    vmovdqa yword [rsp + 5*32], ymm12       ; spill 19*g[5]

    vpmuludq ymm10, ymm14, ymm11
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 8*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm14, yword [rsp + 9*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 1*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 2*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 3*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 4*32]
    vpaddq ymm9, ymm9, ymm10
    vpmuludq ymm10, ymm14, ymm12
    vpaddq ymm0, ymm0, ymm10

    ; Round 7/10
    vmovdqa ymm15, yword [rsi + 6*32]       ; load f[6]
    vmovdqa ymm11, yword [rdx + 4*32]       ;  1*g[4] 
    vpmuludq ymm10, ymm15, ymm12
    vpaddq ymm1, ymm1, ymm10
    vpaddq ymm10, ymm11, ymm11              ;  2*g[4]
    vpaddq ymm11, ymm10, ymm11              ;  3*g[4]
    vpaddq ymm10, ymm10, ymm10              ;  4*g[4]
    vpaddq ymm10, ymm10, ymm10              ;  8*g[4]
    vpaddq ymm10, ymm10, ymm10              ; 16*g[4]
    vpaddq ymm11, ymm10, ymm11              ; compute 19*g[4]
    vmovdqa yword [rsp + 4*32], ymm11       ; spill 19*g[4]

    vpmuludq ymm10, ymm15, ymm13
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 7*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 8*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 9*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 1*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 2*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 3*32]
    vpaddq ymm9, ymm9, ymm10
    vpmuludq ymm10, ymm15, ymm11
    vpaddq ymm0, ymm0, ymm10

    ; Round 8/10
    vmovdqa ymm15, yword [rsi + 7*32]       ; load f[7]
    vpaddq ymm14, ymm15, ymm15              ; compute 2*f[7]         
    vmovdqa ymm13, yword [rdx + 3*32]       ;  1*g[3] 
    vpmuludq ymm10, ymm15, ymm11
    vpaddq ymm1, ymm1, ymm10
    vpaddq ymm10, ymm13, ymm13              ;  2*g[3]
    vpaddq ymm13, ymm10, ymm13              ;  3*g[3]
    vpaddq ymm10, ymm10, ymm10              ;  4*g[3]
    vpaddq ymm10, ymm10, ymm10              ;  8*g[3]
    vpaddq ymm10, ymm10, ymm10              ; 16*g[3]
    vpaddq ymm13, ymm10, ymm13              ; compute 19*g[3]

    vpmuludq ymm10, ymm14, ymm12
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 6*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm14, yword [rsp + 7*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 8*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm14, yword [rsp + 9*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 1*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 2*32]
    vpaddq ymm9, ymm9, ymm10
    vpmuludq ymm10, ymm14, ymm13
    vpaddq ymm0, ymm0, ymm10

    ; Round 9/10
    vmovdqa ymm15, yword [rsi + 8*32]       ; load f[8]
    vmovdqa ymm12, yword [rdx + 2*32]       ;  1*g[2]
    vpmuludq ymm10, ymm15, ymm13
    vpaddq ymm1, ymm1, ymm10
    vpaddq ymm10, ymm12, ymm12              ;  2*g[2]
    vpaddq ymm12, ymm10, ymm12              ;  3*g[2]
    vpaddq ymm10, ymm10, ymm10              ;  4*g[2]
    vpaddq ymm10, ymm10, ymm10              ;  8*g[2]
    vpaddq ymm10, ymm10, ymm10              ; 16*g[2]
    vpaddq ymm12, ymm10, ymm12              ; compute 19*g[2]

    vpmuludq ymm10, ymm15, ymm11
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 5*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 6*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 7*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 8*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 9*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 1*32]
    vpaddq ymm9, ymm9, ymm10
    vpmuludq ymm10, ymm15, ymm12
    vpaddq ymm0, ymm0, ymm10

    ; Round 10/10
    vmovdqa ymm15, yword [rsi + 9*32]       ; load f[9]
    vpaddq ymm14, ymm15, ymm15              ; compute 2*f[9]         
    vmovdqa ymm11, yword [rdx + 1*32]       ;  1*g[1] 
    vpmuludq ymm10, ymm15, ymm12
    vpaddq ymm1, ymm1, ymm10
    vpaddq ymm10, ymm11, ymm11              ;  2*g[1]
    vpaddq ymm11, ymm10, ymm11              ;  3*g[1]
    vpaddq ymm10, ymm10, ymm10              ;  4*g[1]
    vpaddq ymm10, ymm10, ymm10              ;  8*g[1]
    vpaddq ymm10, ymm10, ymm10              ; 16*g[1]
    vpaddq ymm11, ymm10, ymm11              ; compute 19*g[9]

    vpmuludq ymm10, ymm14, ymm13
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 4*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm14, yword [rsp + 5*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 6*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm14, yword [rsp + 7*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 8*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm14, yword [rsp + 9*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm9, ymm9, ymm10
    vpmuludq ymm10, ymm14, ymm11
    vpaddq ymm0, ymm0, ymm10

    vmovdqa yword [rdi + 0*32], ymm0
    vmovdqa yword [rdi + 1*32], ymm1
    vmovdqa yword [rdi + 2*32], ymm2
    vmovdqa yword [rdi + 3*32], ymm3
    vmovdqa yword [rdi + 4*32], ymm4
    vmovdqa yword [rdi + 5*32], ymm5
    vmovdqa yword [rdi + 6*32], ymm6
    vmovdqa yword [rdi + 7*32], ymm7
    vmovdqa yword [rdi + 8*32], ymm8
    vmovdqa yword [rdi + 9*32], ymm9

    bench_epilogue
    ret

fe10x4_mul_vpmuludq19_2:
    lea rdi, [rel scratch_space]
    lea rsi, [rel scratch_space+320]
    bench_prologue
    lea rdx, [rel scratch_space+640]

    sub rsp, 10*32

    ; round 1/10
    vmovdqa ymm15, yword [rsi + 0*32]
    vpmuludq ymm0, ymm15, yword [rdx + 0*32]
    vpmuludq ymm1, ymm15, yword [rdx + 1*32]
    vpmuludq ymm2, ymm15, yword [rdx + 2*32]
    vpmuludq ymm3, ymm15, yword [rdx + 3*32]
    vpmuludq ymm4, ymm15, yword [rdx + 4*32]
    vpmuludq ymm5, ymm15, yword [rdx + 5*32]
    vpmuludq ymm6, ymm15, yword [rdx + 6*32]
    vpmuludq ymm7, ymm15, yword [rdx + 7*32]
    vpmuludq ymm8, ymm15, yword [rdx + 8*32]
    vpmuludq ymm9, ymm15, yword [rdx + 9*32]

    ; round 2/10
    vmovdqa ymm15, yword [rsi + 1*32]           ; load f[1]
    vpaddq ymm14, ymm15, ymm15                  ; compute 2*f[1]
    vpbroadcastq ymm13, qword [rel .const_19]
    vpmuludq ymm12, ymm13, yword [rdx + 9*32]   ; compute 19*g[9]
    vmovdqa yword [rsp + 9*32], ymm12           ; spill 19*g[9]

    vpmuludq ymm10, ymm14, ymm12
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 1*32]
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 2*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 3*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 4*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 5*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 6*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 7*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 8*32]
    vpaddq ymm9, ymm9, ymm10

    ; round 3/10
    vmovdqa ymm15, yword [rsi + 2*32]           ; load f[2]
    vpmuludq ymm11, ymm13, yword [rdx + 8*32]   ; compute 19*g[8]
    vmovdqa yword [rsp + 8*32], ymm11           ; spill 19*g[8]

    vpmuludq ymm10, ymm15, ymm11
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm12
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 1*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 2*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 3*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 4*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 5*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 6*32]
    vpaddq ymm8, ymm8, ymm10    
    vpmuludq ymm10, ymm15, yword [rdx + 7*32]
    vpaddq ymm9, ymm9, ymm10

    ; Round 4/10
    vmovdqa ymm15, yword [rsi + 3*32]           ; load f[3]
    vpaddq ymm14, ymm15, ymm15                  ; compute 2*f[3]             
    vpmuludq ymm12, ymm13, yword [rdx + 7*32]   ; compute 19*g[7]
    vmovdqa yword [rsp + 7*32], ymm12           ; spill 19*g[7]

    vpmuludq ymm10, ymm14, ymm12
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm11
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm14, yword [rsp + 9*32]
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 1*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 2*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 3*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 4*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 5*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 6*32]
    vpaddq ymm9, ymm9, ymm10

    ; Round 5/10
    vmovdqa ymm15, yword [rsi + 4*32]           ; load f[4]
    vpmuludq ymm11, ymm13, yword [rdx + 6*32]   ; compute 19*g[6]
    vmovdqa yword [rsp + 6*32], ymm11           ; spill 19*g[6]

    vpmuludq ymm10, ymm15, ymm11
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm12
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 8*32]
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 9*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 1*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 2*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 3*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 4*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 5*32]
    vpaddq ymm9, ymm9, ymm10

    ; Round 6/10
    vmovdqa ymm15, yword [rsi + 5*32]           ; load f[5]
    vpaddq ymm14, ymm15, ymm15                  ; compute 2*f[5]         
    vpmuludq ymm12, ymm13, yword [rdx + 5*32]   ; compute 19*g[5] 
    vmovdqa yword [rsp + 5*32], ymm12           ; spill 19*g[5]

    vpmuludq ymm10, ymm14, ymm12
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm11
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm14, yword [rsp + 7*32]
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 8*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm14, yword [rsp + 9*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 1*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 2*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 3*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 4*32]
    vpaddq ymm9, ymm9, ymm10

    ; Round 7/10
    vmovdqa ymm15, yword [rsi + 6*32]           ; load f[6]
    vpmuludq ymm11, ymm13, yword [rdx + 4*32]   ; compute 19*g[4]
    vmovdqa yword [rsp + 4*32], ymm11           ; spill 19*g[4]

    vpmuludq ymm10, ymm15, ymm11
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm12
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 6*32]
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 7*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 8*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 9*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 1*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 2*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 3*32]
    vpaddq ymm9, ymm9, ymm10

    ; Round 8/10
    vmovdqa ymm15, yword [rsi + 7*32]           ; load f[7]
    vpaddq ymm14, ymm15, ymm15                  ; compute 2*f[7]         
    vpmuludq ymm12, ymm13, yword [rdx + 3*32]   ; compute 19*g[8]
    vmovdqa yword [rsp + 3*32], ymm12

    vpmuludq ymm10, ymm14, ymm12
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm11
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm14, yword [rsp + 5*32]
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 6*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm14, yword [rsp + 7*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 8*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm14, yword [rsp + 9*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 1*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 2*32]
    vpaddq ymm9, ymm9, ymm10

    ; Round 9/10
    vmovdqa ymm15, yword [rsi + 8*32]           ; load f[8]
    vpmuludq ymm11, ymm13, yword [rdx + 2*32]   ; compute 19*g[2]

    vpmuludq ymm10, ymm15, ymm11
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm12
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 4*32]
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 5*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 6*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 7*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 8*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 9*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 1*32]
    vpaddq ymm9, ymm9, ymm10

    ; Round 10/10
    vmovdqa ymm15, yword [rsi + 9*32]           ; load f[9]
    vpaddq ymm14, ymm15, ymm15                  ; compute 2*f[9]         
    vpmuludq ymm12, ymm13, yword [rdx + 1*32]   ; compute 19*g[1]

    vpmuludq ymm10, ymm14, ymm12
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm11
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm14, yword [rsp + 3*32]
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 4*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm14, yword [rsp + 5*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 6*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm14, yword [rsp + 7*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 8*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm14, yword [rsp + 9*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm9, ymm9, ymm10

    vmovdqa yword [rdi + 0*32], ymm0
    vmovdqa yword [rdi + 1*32], ymm1
    vmovdqa yword [rdi + 2*32], ymm2
    vmovdqa yword [rdi + 3*32], ymm3
    vmovdqa yword [rdi + 4*32], ymm4
    vmovdqa yword [rdi + 5*32], ymm5
    vmovdqa yword [rdi + 6*32], ymm6
    vmovdqa yword [rdi + 7*32], ymm7
    vmovdqa yword [rdi + 8*32], ymm8
    vmovdqa yword [rdi + 9*32], ymm9

    bench_epilogue
    ret

section .rodata
align 32, db 0
.const_19: dq 19

section .text

fe10x4_mul_shortened:
    lea rdi, [rel scratch_space]
    lea rsi, [rel scratch_space+320]
    bench_prologue
    lea rdx, [rel scratch_space+640]

    sub rsp, 10*32
    

    ; round 1/10
    vmovdqa ymm15, yword [rsi + 0*32]
    vpmuludq ymm0, ymm15, yword [rdx + 0*32]
    vpmuludq ymm1, ymm15, yword [rdx + 1*32]
    vpmuludq ymm2, ymm15, yword [rdx + 2*32]
    vpmuludq ymm3, ymm15, yword [rdx + 3*32]
    vpmuludq ymm4, ymm15, yword [rdx + 4*32]
    mov rbx, rdx
    add rbx, 5*32    
    vpmuludq ymm5, ymm15, yword [rbx + 0*32]
    vpmuludq ymm6, ymm15, yword [rbx + 1*32]
    vpmuludq ymm7, ymm15, yword [rbx + 2*32]
    vpmuludq ymm8, ymm15, yword [rbx + 3*32]
    vpmuludq ymm9, ymm15, yword [rbx + 4*32]
    
    mov rcx, rsp
    add rcx, 5*32

    ; round 2/10
    vmovdqa ymm15, yword [rsi + 1*32]       ; load f[1]
    vpaddq ymm14, ymm15, ymm15              ; compute 2*f[1]
    vmovdqa ymm13, yword [rbx + 4*32]       ;  1*g[9] 
    vpaddq ymm10, ymm13, ymm13              ;  2*g[9]
    vpaddq ymm13, ymm10, ymm13              ;  3*g[9]
    vpaddq ymm10, ymm10, ymm10              ;  4*g[9]
    vpaddq ymm10, ymm10, ymm10              ;  8*g[9]
    vpaddq ymm10, ymm10, ymm10              ; 16*g[9]
    vpaddq ymm13, ymm10, ymm13              ; compute 19*g[9]
    vmovdqa yword [rcx + 4*32], ymm13       ; spill 19*g[9]

    vpmuludq ymm10, ymm14, ymm13
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 1*32]
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 2*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 3*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 4*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm14, yword [rbx + 0*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rbx + 1*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm14, yword [rbx + 2*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [rbx + 3*32]
    vpaddq ymm9, ymm9, ymm10

    ; round 3/10
    vmovdqa ymm15, yword [rsi + 2*32]       ; load f[2]
    vmovdqa ymm12, yword [rbx + 3*32]       ;  1*g[8] 
    vpaddq ymm10, ymm12, ymm12              ;  2*g[8]
    vpaddq ymm12, ymm10, ymm12              ;  3*g[8]
    vpaddq ymm10, ymm10, ymm10              ;  4*g[8]
    vpaddq ymm10, ymm10, ymm10              ;  8*g[8]
    vpaddq ymm10, ymm10, ymm10              ; 16*g[8]
    vpaddq ymm12, ymm10, ymm12              ; compute 19*g[8]
    vmovdqa yword [rcx + 3*32], ymm12       ; spill 19*g[8]

    vpmuludq ymm10, ymm15, ymm12
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm13
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 1*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 2*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 3*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 4*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rbx + 0*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm15, yword [rbx + 1*32]
    vpaddq ymm8, ymm8, ymm10    
    vpmuludq ymm10, ymm15, yword [rbx + 2*32]
    vpaddq ymm9, ymm9, ymm10

    ; Round 4/10
    vmovdqa ymm15, yword [rsi + 3*32]       ; load f[3]
    vpaddq ymm14, ymm15, ymm15              ; compute 2*f[3]             
    vmovdqa ymm11, yword [rbx + 2*32]       ;  1*g[7] 
    vpaddq ymm10, ymm11, ymm11              ;  2*g[7]
    vpaddq ymm11, ymm10, ymm11              ;  3*g[7]
    vpaddq ymm10, ymm10, ymm10              ;  4*g[7]
    vpaddq ymm10, ymm10, ymm10              ;  8*g[7]
    vpaddq ymm10, ymm10, ymm10              ; 16*g[7]
    vpaddq ymm11, ymm10, ymm11              ; compute 19*g[7]
    vmovdqa yword [rcx + 2*32], ymm11       ; spill 19*g[7]

    vpmuludq ymm10, ymm14, ymm11
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm12
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm14, ymm13
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 1*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 2*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 3*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 4*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm14, yword [rbx + 0*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [rbx + 1*32]
    vpaddq ymm9, ymm9, ymm10

    ; Round 5/10
    vmovdqa ymm15, yword [rsi + 4*32]       ; load f[4]
    vmovdqa ymm13, yword [rbx + 1*32]       ;  1*g[6] 
    vpaddq ymm10, ymm13, ymm13              ;  2*g[6]
    vpaddq ymm13, ymm10, ymm13              ;  3*g[6]
    vpaddq ymm10, ymm10, ymm10              ;  4*g[6]
    vpaddq ymm10, ymm10, ymm10              ;  8*g[6]
    vpaddq ymm10, ymm10, ymm10              ; 16*g[6]
    vpaddq ymm13, ymm10, ymm13              ; compute 19*g[6]
    vmovdqa yword [rcx + 1*32], ymm13       ; spill 19*g[6]

    vpmuludq ymm10, ymm15, ymm13
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm11
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm15, ymm12
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 9*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 1*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 2*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 3*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 4*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [rbx + 0*32]
    vpaddq ymm9, ymm9, ymm10

    ; Round 6/10
    vmovdqa ymm15, yword [rsi + 5*32]       ; load f[5]
    vpaddq ymm14, ymm15, ymm15              ; compute 2*f[5]         
    vmovdqa ymm12, yword [rbx + 0*32]       ;  1*g[5] 
    vpaddq ymm10, ymm12, ymm12              ;  2*g[5]
    vpaddq ymm12, ymm10, ymm12              ;  3*g[5]
    vpaddq ymm10, ymm10, ymm10              ;  4*g[5]
    vpaddq ymm10, ymm10, ymm10              ;  8*g[5]
    vpaddq ymm10, ymm10, ymm10              ; 16*g[5]
    vpaddq ymm12, ymm10, ymm12              ; compute 19*g[5]
    vmovdqa yword [rcx + 0*32], ymm12       ; spill 19*g[5]

    vpmuludq ymm10, ymm14, ymm12
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm13
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm14, ymm11
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rcx + 3*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm14, yword [rcx + 4*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 1*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 2*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 3*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 4*32]
    vpaddq ymm9, ymm9, ymm10

    ; Round 7/10
    vmovdqa ymm15, yword [rsi + 6*32]       ; load f[6]
    vmovdqa ymm11, yword [rdx + 4*32]       ;  1*g[4] 
    vpaddq ymm10, ymm11, ymm11              ;  2*g[4]
    vpaddq ymm11, ymm10, ymm11              ;  3*g[4]
    vpaddq ymm10, ymm10, ymm10              ;  4*g[4]
    vpaddq ymm10, ymm10, ymm10              ;  8*g[4]
    vpaddq ymm10, ymm10, ymm10              ; 16*g[4]
    vpaddq ymm11, ymm10, ymm11              ; compute 19*g[4]
    vmovdqa yword [rsp + 4*32], ymm11       ; spill 19*g[4]

    vpmuludq ymm10, ymm15, ymm11
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm12
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm15, ymm13
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rcx + 2*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm15, yword [rcx + 3*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rcx + 4*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 1*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 2*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 3*32]
    vpaddq ymm9, ymm9, ymm10

    ; Round 8/10
    vmovdqa ymm15, yword [rsi + 7*32]       ; load f[7]
    vpaddq ymm14, ymm15, ymm15              ; compute 2*f[7]         
    vmovdqa ymm13, yword [rdx + 3*32]       ;  1*g[3] 
    vpaddq ymm10, ymm13, ymm13              ;  2*g[3]
    vpaddq ymm13, ymm10, ymm13              ;  3*g[3]
    vpaddq ymm10, ymm10, ymm10              ;  4*g[3]
    vpaddq ymm10, ymm10, ymm10              ;  8*g[3]
    vpaddq ymm10, ymm10, ymm10              ; 16*g[3]
    vpaddq ymm13, ymm10, ymm13              ; compute 19*g[3]

    vpmuludq ymm10, ymm14, ymm13
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm11
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm14, ymm12
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rcx + 1*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm14, yword [rcx + 2*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rcx + 3*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm14, yword [rcx + 4*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm14, yword [rdx + 1*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 2*32]
    vpaddq ymm9, ymm9, ymm10

    ; Round 9/10
    vmovdqa ymm15, yword [rsi + 8*32]       ; load f[8]
    vmovdqa ymm12, yword [rdx + 2*32]       ;  1*g[2]
    vpaddq ymm10, ymm12, ymm12              ;  2*g[2]
    vpaddq ymm12, ymm10, ymm12              ;  3*g[2]
    vpaddq ymm10, ymm10, ymm10              ;  4*g[2]
    vpaddq ymm10, ymm10, ymm10              ;  8*g[2]
    vpaddq ymm10, ymm10, ymm10              ; 16*g[2]
    vpaddq ymm12, ymm10, ymm12              ; compute 19*g[2]

    vpmuludq ymm10, ymm15, ymm12
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm13
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm15, ymm11
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rcx + 0*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm15, yword [rcx + 1*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rcx + 2*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm15, yword [rcx + 3*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rcx + 4*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 1*32]
    vpaddq ymm9, ymm9, ymm10

    ; Round 10/10
    vmovdqa ymm15, yword [rsi + 9*32]       ; load f[9]
    vpaddq ymm14, ymm15, ymm15              ; compute 2*f[9]         
    vmovdqa ymm11, yword [rdx + 1*32]       ;  1*g[1] 
    vpaddq ymm10, ymm11, ymm11              ;  2*g[1]
    vpaddq ymm11, ymm10, ymm11              ;  3*g[1]
    vpaddq ymm10, ymm10, ymm10              ;  4*g[1]
    vpaddq ymm10, ymm10, ymm10              ;  8*g[1]
    vpaddq ymm10, ymm10, ymm10              ; 16*g[1]
    vpaddq ymm11, ymm10, ymm11              ; compute 19*g[9]

    vpmuludq ymm10, ymm14, ymm11
    vpaddq ymm0, ymm0, ymm10
    vpmuludq ymm10, ymm15, ymm12
    vpaddq ymm1, ymm1, ymm10
    vpmuludq ymm10, ymm14, ymm13
    vpaddq ymm2, ymm2, ymm10
    vpmuludq ymm10, ymm15, yword [rsp + 4*32]
    vpaddq ymm3, ymm3, ymm10
    vpmuludq ymm10, ymm14, yword [rcx + 0*32]
    vpaddq ymm4, ymm4, ymm10
    vpmuludq ymm10, ymm15, yword [rcx + 1*32]
    vpaddq ymm5, ymm5, ymm10
    vpmuludq ymm10, ymm14, yword [rcx + 2*32]
    vpaddq ymm6, ymm6, ymm10
    vpmuludq ymm10, ymm15, yword [rcx + 3*32]
    vpaddq ymm7, ymm7, ymm10
    vpmuludq ymm10, ymm14, yword [rcx + 4*32]
    vpaddq ymm8, ymm8, ymm10
    vpmuludq ymm10, ymm15, yword [rdx + 0*32]
    vpaddq ymm9, ymm9, ymm10

    vmovdqa yword [rdi + 0*32], ymm0
    vmovdqa yword [rdi + 1*32], ymm1
    vmovdqa yword [rdi + 2*32], ymm2
    vmovdqa yword [rdi + 3*32], ymm3
    vmovdqa yword [rdi + 4*32], ymm4
    vmovdqa yword [rdi + 5*32], ymm5
    vmovdqa yword [rdi + 6*32], ymm6
    vmovdqa yword [rdi + 7*32], ymm7
    vmovdqa yword [rdi + 8*32], ymm8
    vmovdqa yword [rdi + 9*32], ymm9

    bench_epilogue
    ret
