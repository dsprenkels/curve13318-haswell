/*
   This file is the result of merging
   amd64-51/fe25519_pack.c and amd64-51/fe25519_freeze.s.
*/

.p2align 5
.global crypto_scalarmult_curve13318_avx2_fe51_pack
crypto_scalarmult_curve13318_avx2_fe51_pack:
    mov %rsp,%r11
    and $31,%r11
    add $32,%r11
    sub %r11,%rsp
    movq %r11,0(%rsp)
    movq %r12,8(%rsp)
    movq   0(%rsi),%rdx
    movq   8(%rsi),%rcx
    movq   16(%rsi),%r8
    movq   24(%rsi),%r9
    movq   32(%rsi),%rsi

    # reduce mod 2^255
    movq .REDMASK51(%rip),%rax
    lea  -18(%rax),%r10
    mov  $3,%r11
._reduceloop:
    mov  %rdx,%r12
    shr  $51,%r12
    and  %rax,%rdx
    add  %r12,%rcx
    mov  %rcx,%r12
    shr  $51,%r12
    and  %rax,%rcx
    add  %r12,%r8
    mov  %r8,%r12
    shr  $51,%r12
    and  %rax,%r8
    add  %r12,%r9
    mov  %r9,%r12
    shr  $51,%r12
    and  %rax,%r9
    add  %r12,%rsi
    mov  %rsi,%r12
    shr  $51,%r12
    and  %rax,%rsi
    imulq  $19, %r12,%r12
    add  %r12,%rdx
    sub  $1,%r11
    ja ._reduceloop

    # %r10: 2^51 - 19
    # %r11: 0
    # %r12: 1 or 0
    # %rax: lowest 51 bitmask

    # If any (%rax != limb) for limb in limbs then
    #     %12 := 0
    # Else
    #     %12 := 1
    # Endif
    mov  $1,%r12
    cmp  %r10,%rdx
    cmovl %r11,%r12
    cmp  %rax,%rcx
    cmovne %r11,%r12
    cmp  %rax,%r8
    cmovne %r11,%r12
    cmp  %rax,%r9
    cmovne %r11,%r12
    cmp  %rax,%rsi
    cmovne %r11,%r12
    neg  %r12
    and  %r12,%rax # mask w/ (z > 2^255 - 19)-mask
    and  %r12,%r10
    sub  %r10,%rdx # sub 2^51 - 19 or 0
    sub  %rax,%rcx # sub 2^51 - 1 or 0
    sub  %rax,%r8
    sub  %rax,%r9
    sub  %rax,%rsi

    # store into RAM
    mov  %rdx,%rax
    and  $0xFF,%eax
    movb   %al,0(%rdi)
    mov  %rdx,%rax
    shr  $8,%rax
    and  $0xFF,%eax
    movb   %al,1(%rdi)
    mov  %rdx,%rax
    shr  $16,%rax
    and  $0xFF,%eax
    movb   %al,2(%rdi)
    mov  %rdx,%rax
    shr  $24,%rax
    and  $0xFF,%eax
    movb   %al,3(%rdi)
    mov  %rdx,%rax
    shr  $32,%rax
    and  $0xFF,%eax
    movb   %al,4(%rdi)
    mov  %rdx,%rax
    shr  $40,%rax
    and  $0xFF,%eax
    movb   %al,5(%rdi)
    mov  %rdx,%rdx
    shr  $48,%rdx
    mov  %rcx,%rax
    shl  $3,%rax
    and  $0xF8,%eax
    xor  %rdx,%rax
    movb   %al,6(%rdi)
    mov  %rcx,%rdx
    shr  $5,%rdx
    and  $0xFF,%edx
    movb   %dl,7(%rdi)


    mov  %rcx,%rdx
    shr  $13,%rdx
    and  $0xFF,%edx
    movb   %dl,8(%rdi)

    mov  %rcx,%rdx
    shr  $21,%rdx
    and  $0xFF,%edx
    movb   %dl,9(%rdi)

    # Instead do following?
    # mov %rcx,%rdx
    # shr $13,$rdx
    # movb %dl,8(%rdi)

    # shr $8,$rdx
    # movb %dl,9(%rdi)






    mov  %rcx,%rdx
    shr  $29,%rdx
    and  $0xFF,%edx
    movb   %dl,10(%rdi)
    mov  %rcx,%rdx
    shr  $37,%rdx
    and  $0xFF,%edx
    movb   %dl,11(%rdi)
    mov  %rcx,%rdx
    shr  $45,%rdx
    mov  %r8,%rcx
    shl  $6,%rcx
    and  $0xC0,%ecx
    xor  %rdx,%rcx
    movb   %cl,12(%rdi)
    mov  %r8,%rdx
    shr  $2,%rdx
    and  $0xFF,%edx
    movb   %dl,13(%rdi)
    mov  %r8,%rdx
    shr  $10,%rdx
    and  $0xFF,%edx
    movb   %dl,14(%rdi)
    mov  %r8,%rdx
    shr  $18,%rdx
    and  $0xFF,%edx
    movb   %dl,15(%rdi)
    mov  %r8,%rdx
    shr  $26,%rdx
    and  $0xFF,%edx
    movb   %dl,16(%rdi)
    mov  %r8,%rdx
    shr  $34,%rdx
    and  $0xFF,%edx
    movb   %dl,17(%rdi)
    mov  %r8,%rdx
    shr  $42,%rdx
    movb   %dl,18(%rdi)
    mov  %r8,%rdx
    shr  $50,%rdx
    mov  %r9,%rcx
    shl  $1,%rcx
    and  $0xFE,%ecx
    xor  %rdx,%rcx
    movb   %cl,19(%rdi)
    mov  %r9,%rdx
    shr  $7,%rdx
    and  $0xFF,%edx
    movb   %dl,20(%rdi)
    mov  %r9,%rdx
    shr  $15,%rdx
    and  $0xFF,%edx
    movb   %dl,21(%rdi)
    mov  %r9,%rdx
    shr  $23,%rdx
    and  $0xFF,%edx
    movb   %dl,22(%rdi)
    mov  %r9,%rdx
    shr  $31,%rdx
    and  $0xFF,%edx
    movb   %dl,23(%rdi)
    mov  %r9,%rdx
    shr  $39,%rdx
    and  $0xFF,%edx
    movb   %dl,24(%rdi)
    mov  %r9,%rdx
    shr  $47,%rdx
    mov  %rsi,%rcx
    shl  $4,%rcx
    and  $0xF0,%ecx
    xor  %rdx,%rcx
    movb   %cl,25(%rdi)
    mov  %rsi,%rdx
    shr  $4,%rdx
    and  $0xFF,%edx
    movb   %dl,26(%rdi)
    mov  %rsi,%rdx
    shr  $12,%rdx
    and  $0xFF,%edx
    movb   %dl,27(%rdi)
    mov  %rsi,%rdx
    shr  $20,%rdx
    and  $0xFF,%edx
    movb   %dl,28(%rdi)
    mov  %rsi,%rdx
    shr  $28,%rdx
    and  $0xFF,%edx
    movb   %dl,29(%rdi)
    mov  %rsi,%rdx
    shr  $36,%rdx
    and  $0xFF,%edx
    movb   %dl,30(%rdi)
    mov  %rsi,%rsi
    shr  $44,%rsi
    movb   %sil,31(%rdi)
    movq 0(%rsp),%r11
    movq 8(%rsp),%r12
    add %r11,%rsp
    ret

.rodata:
.REDMASK51:   .quad 0x0007FFFFFFFFFFFF
