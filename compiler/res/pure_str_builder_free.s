.section .note.GNU-stack,"",@progbits
.text
.globl pure_str_builder_free
.type pure_str_builder_free, @function
pure_str_builder_free:
	testq	%rdi, %rdi
	je	.Ldone
	cmpq	$4096, %rdi
	jb	.Ldone
	movq	0x10(%rdi), %rsi
	movl	$11, %eax
	syscall
.Ldone:
	nop
.size pure_str_builder_free, .-pure_str_builder_free
