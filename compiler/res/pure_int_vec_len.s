/* Inlined: rdi=handle -> rax=len or -1; reject null / non-pointer handles (host uses small ids). */
.section .note.GNU-stack,"",@progbits
.text
.globl pure_int_vec_len
.type pure_int_vec_len, @function
pure_int_vec_len:
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
.size pure_int_vec_len, .-pure_int_vec_len
