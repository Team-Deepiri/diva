.section .note.GNU-stack,"",@progbits
.text
.globl pure_str_builder_len
.type pure_str_builder_len, @function
pure_str_builder_len:
	testq	%rdi, %rdi
	je	.Lbad
	cmpq	$4096, %rdi
	jb	.Lbad
	movq	(%rdi), %rax
	jmp	.Lend
.Lbad:
	movq	$-1, %rax
.Lend:
	nop
.size pure_str_builder_len, .-pure_str_builder_len
