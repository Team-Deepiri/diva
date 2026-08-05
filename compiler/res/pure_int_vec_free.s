/* Inlined: munmap handle; guard rejects bogus small "handles". */
.section .note.GNU-stack,"",@progbits
.text
.globl pure_int_vec_free
.type pure_int_vec_free, @function
pure_int_vec_free:
	testq	%rdi, %rdi
	je	.Ldone
	cmpq	$4096, %rdi
	jb	.Ldone
	movq	0x10(%rdi), %rsi
	movl	$11, %eax
	syscall
.Ldone:
	nop
.size pure_int_vec_free, .-pure_int_vec_free
