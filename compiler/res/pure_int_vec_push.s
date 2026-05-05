/* Inlined: rdi=handle, rsi=value; guard rejects host-style small handle ids. */
.section .note.GNU-stack,"",@progbits
.text
.globl pure_int_vec_push
.type pure_int_vec_push, @function
pure_int_vec_push:
	testq	%rdi, %rdi
	je	.Lfail
	cmpq	$4096, %rdi
	jb	.Lfail
	movq	(%rdi), %rax
	movq	0x8(%rdi), %rcx
	cmpq	%rcx, %rax
	jge	.Lfail
	movq	%rsi, 0x18(%rdi,%rax,8)
	incq	%rax
	movq	%rax, (%rdi)
	jmp	.Lok
.Lfail:
	xorl	%eax, %eax
.Lok:
	nop
.size pure_int_vec_push, .-pure_int_vec_push
