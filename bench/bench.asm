; Macros for constructing benchmarks

%ifndef BENCH_ASM_
%define BENCH_ASM_

section .text

global _bench_blank, _bench_fns, _bench_names, _bench_fns_n

%macro bench_prologue 0
    push rbx
    push r12
    push r13
    push r14
    push r15
    vzeroupper
    rdtsc
    push rax
    push rbp
    mov rbp, rsp
    and rsp, -32
    mfence
%endmacro

%macro bench_epilogue 0
    mfence
    rdtsc
    mov rsp, rbp
    pop rbp
    pop rdx
    sub rax, rdx
    vzeroupper
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
%endmacro

_bench_blank:
    bench_prologue
    bench_epilogue
    ret

%endif
