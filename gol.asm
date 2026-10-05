bits 64
default rel
global main

%define WANT_W 1920
%define WANT_H 1080
%define DENSITY 72

section .text

main:
    push rbx
    push rbp
    push rsi
    push rdi
    push r12
    push r13
    push r14
    push r15
    sub rsp, 0x58

    mov [SystemTable], rdx
    mov rax, [rdx + 0x30]
    mov [ConIn], rax
    mov rax, [rdx + 0x40]
    mov [ConOut], rax
    mov rax, [rdx + 0x60]
    mov [BootServices], rax

    mov rax, [BootServices]
    xor ecx, ecx
    xor edx, edx
    xor r8d, r8d
    xor r9d, r9d
    call [rax + 0x100]

    mov rcx, [ConOut]
    xor edx, edx
    call [rcx + 0x40]

    mov rax, [BootServices]
    lea rcx, [GopGuid]
    xor edx, edx
    lea r8, [Gop]
    call [rax + 0x140]
    test rax, rax
    jnz .fail

    mov rax, [Gop]
    mov rax, [rax + 0x18]
    mov eax, [rax]
    mov [MaxMode], eax
    xor ebx, ebx
.mode:
    cmp ebx, [MaxMode]
    jae .modedone
    mov rcx, [Gop]
    mov edx, ebx
    lea r8, [InfoSize]
    lea r9, [Info]
    call [rcx]
    test rax, rax
    jnz .nextmode
    mov rcx, [Info]
    mov r12d, [rcx + 4]
    mov r13d, [rcx + 8]
    mov rax, [BootServices]
    call [rax + 0x48]
    cmp r12d, WANT_W
    jne .nextmode
    cmp r13d, WANT_H
    jne .nextmode
    mov rcx, [Gop]
    mov edx, ebx
    call [rcx + 8]
    jmp .modedone
.nextmode:
    inc ebx
    jmp .mode
.modedone:

    mov rax, [Gop]
    mov rax, [rax + 0x18]
    mov rax, [rax + 8]
    mov ecx, [rax + 4]
    mov [ScrW], ecx
    mov ecx, [rax + 8]
    mov [ScrH], ecx

    mov eax, [ScrW]
    shl eax, 2
    mov [Pitch], eax
    imul eax, [ScrH]
    mov [BufSize], rax
    mov eax, [ScrW]
    add eax, 2
    mov [Stride], rax
    mov ecx, [ScrH]
    add ecx, 2
    imul rax, rcx
    mov [GridSize], rax

    mov rax, [BootServices]
    mov ecx, 2
    mov rdx, [BufSize]
    lea r8, [Buf]
    call [rax + 0x40]
    test rax, rax
    jnz .fail
    mov rax, [BootServices]
    mov ecx, 2
    mov rdx, [GridSize]
    lea r8, [Cur]
    call [rax + 0x40]
    test rax, rax
    jnz .fail
    mov rax, [BootServices]
    mov ecx, 2
    mov rdx, [GridSize]
    lea r8, [Nxt]
    call [rax + 0x40]
    test rax, rax
    jnz .fail

    call entropy
    or rax, 1
    mov [Seed], rax
    call randomize

.frame:
    call step

    mov rcx, [Gop]
    mov rdx, [Buf]
    mov r8d, 2
    xor r9d, r9d
    mov qword [rsp + 0x20], 0
    mov qword [rsp + 0x28], 0
    mov qword [rsp + 0x30], 0
    mov eax, [ScrW]
    mov [rsp + 0x38], rax
    mov eax, [ScrH]
    mov [rsp + 0x40], rax
    mov eax, [Pitch]
    mov [rsp + 0x48], rax
    call [rcx + 0x10]

    mov rcx, [ConIn]
    lea rdx, [Key]
    call [rcx + 8]
    test rax, rax
    jnz .wait
    cmp word [Key], 0x17
    je .exit
    call entropy
    xor [Seed], rax
    or qword [Seed], 1
    call randomize

.wait:
    mov rax, [BootServices]
    mov ecx, 10000
    call [rax + 0xF8]
    jmp .frame

.fail:
    mov rbx, rax
    mov rcx, [ConOut]
    lea rdx, [ErrMsg]
    call [rcx + 8]
    mov rax, [BootServices]
    mov ecx, 5000000
    call [rax + 0xF8]
    mov rax, rbx
    jmp .ret

.exit:
    mov rcx, [ConOut]
    call [rcx + 0x30]
    xor eax, eax

.ret:
    add rsp, 0x58
    pop r15
    pop r14
    pop r13
    pop r12
    pop rdi
    pop rsi
    pop rbp
    pop rbx
    ret

entropy:
    rdtsc
    shl rdx, 32
    or rax, rdx
    mov r8, rax
    mov eax, 1
    cpuid
    bt ecx, 30
    jnc .done
    mov r9d, 16
.try:
    rdrand rax
    jc .got
    dec r9d
    jnz .try
    jmp .done
.got:
    xor r8, rax
.done:
    mov rax, r8
    ret

randomize:
    mov rdi, [Cur]
    mov rcx, [GridSize]
    mov rax, [Seed]
    mov r8, 0x2545F4914F6CDD1D
.l:
    mov rdx, rax
    shr rdx, 12
    xor rax, rdx
    mov rdx, rax
    shl rdx, 25
    xor rax, rdx
    mov rdx, rax
    shr rdx, 27
    xor rax, rdx
    mov rdx, rax
    imul rdx, r8
    shr rdx, 56
    cmp edx, DENSITY
    setb dl
    mov [rdi], dl
    inc rdi
    dec rcx
    jnz .l
    mov [Seed], rax
    ret

wrap:
    mov r9, [Cur]
    mov r8, [Stride]
    mov edx, [ScrW]
    mov ecx, [ScrH]
    lea rdi, [r9 + r8]
.r:
    mov al, [rdi + rdx]
    mov [rdi], al
    mov al, [rdi + 1]
    mov [rdi + rdx + 1], al
    add rdi, r8
    dec ecx
    jnz .r
    mov eax, [ScrH]
    imul rax, r8
    lea rsi, [r9 + rax]
    mov rdi, r9
    mov rcx, r8
    rep movsb
    lea rsi, [r9 + r8]
    lea rdi, [r9 + rax]
    add rdi, r8
    mov rcx, r8
    rep movsb
    ret

step:
    call wrap
    mov rsi, [Cur]
    mov rdi, [Nxt]
    mov rbp, [Buf]
    mov r8, [Stride]
    lea r12, [Colors]
    lea rsi, [rsi + r8 + 1]
    lea rdi, [rdi + r8 + 1]
    mov r9, rsi
    sub r9, r8
    lea r10, [rsi + r8]
    mov r11d, [ScrH]
.y:
    mov ebx, [ScrW]
.x:
    movzx eax, byte [r9 - 1]
    add al, [r9]
    add al, [r9 + 1]
    add al, [rsi - 1]
    add al, [rsi + 1]
    add al, [r10 - 1]
    add al, [r10]
    add al, [r10 + 1]
    movzx edx, byte [rsi]
    or eax, edx
    cmp eax, 3
    sete cl
    mov [rdi], cl
    movzx ecx, cl
    lea ecx, [rdx + rcx * 2]
    mov ecx, [r12 + rcx * 4]
    mov [rbp], ecx
    add rbp, 4
    inc rsi
    inc rdi
    inc r9
    inc r10
    dec ebx
    jnz .x
    add rsi, 2
    add rdi, 2
    add r9, 2
    add r10, 2
    dec r11d
    jnz .y
    mov rax, [Cur]
    mov rdx, [Nxt]
    mov [Cur], rdx
    mov [Nxt], rax
    ret

section .data
align 8
GopGuid:
    dd 0x9042a9de
    dw 0x23dc, 0x4a38
    db 0x96, 0xfb, 0x7a, 0xde, 0xd0, 0x80, 0x51, 0x6a
Colors:
    dd 0x00000000
    dd 0x00000000
    dd 0x00adecbe
    dd 0x00adecbe
ErrMsg:
    dw __utf16__("Game of Life: GOP non disponibile"), 13, 10, 0

section .bss
alignb 8
SystemTable:  resq 1
ConIn:        resq 1
ConOut:       resq 1
BootServices: resq 1
Gop:          resq 1
Info:         resq 1
InfoSize:     resq 1
Buf:          resq 1
BufSize:      resq 1
Cur:          resq 1
Nxt:          resq 1
Stride:       resq 1
GridSize:     resq 1
Seed:         resq 1
MaxMode:      resd 1
ScrW:         resd 1
ScrH:         resd 1
Pitch:        resd 1
Key:          resd 1
