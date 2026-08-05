/* Inlined at pure ELF ir_call sites (no ret): rdi=handle, rsi=index -> rax; fall through
 * to the following mov-to-stack. Matches host OOB/null: rax = -1. */
.section .note.GNU-stack,"",@progbits
.text
.globl pure_int_vec_get
.type pure_int_vec_get, @function
pure_int_vec_get:
	testq	%rdi, %rdi
	je	.Lfail
	cmpq	$4096, %rdi
	jb	.Lfail
	movq	(%rdi), %rax
	cmpq	%rax, %rsi
	jae	.Lfail
	movq	0x18(%rdi,%rsi,8), %rax
	jmp	.Lend
.Lfail:
	movq	$-1, %rax
.Lend:
	nop
.size pure_int_vec_get, .-pure_int_vec_get
