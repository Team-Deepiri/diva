/* Pure ELF int_vec_get — handle is table index. NO ret. */
.equ HT_BASE, 0x500000000000
.equ HT_MAX, 65535

.section .note.GNU-stack,"",@progbits
.text
.globl pure_int_vec_get
.type pure_int_vec_get, @function
pure_int_vec_get:
	testq	%rdi, %rdi
	je	.Lfail
	cmpq	$HT_MAX, %rdi
	ja	.Lfail
	movabs	$HT_BASE, %rax
	movq	(%rax,%rdi,8), %rdi
	testq	%rdi, %rdi
	je	.Lfail
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
