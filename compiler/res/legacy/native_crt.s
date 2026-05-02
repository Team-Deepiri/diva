/* Minimal _start for -nostartfiles links with bootstrap/runtime-linux-amd64.o.
   With no libc rt0, the kernel leaves argc at (%rsp) and argv at 8(%rsp). */
.section .note.GNU-stack,"",@progbits
.text
.globl _start
.type _start, @function
_start:
    movq (%rsp), %rdi
    leaq 8(%rsp), %rsi
    call main
    movq %rax, %rdi
    call di_runtime_exit
.size _start, .-_start
