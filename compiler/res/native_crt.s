/* Hosted entry for Diva native builds when linking with bootstrap/runtime-linux-amd64.o.
   Linux passes argc in %rdi and argv in %rsi at process entry. */
.section .note.GNU-stack,"",@progbits
.text
.globl _start
.type _start, @function
_start:
    call di_runtime_set_argv
    call main
    movq %rax, %rdi
    call di_runtime_exit
.size _start, .-_start
