/* Pure ELF int_vec_len — handle is table index. NO ret. */
.equ HT_BASE, 0x500000000000
.equ HT_MAX, 65535

.section .note.GNU-stack,"",@progbits
.text
.globl pure_int_vec_len
.type pure_int_vec_len, @function
pure_int_vec_len:
	testq	%rdi, %rdi
	je	.Lbad
	cmpq	$HT_MAX, %rdi
	ja	.Lbad
	movabs	$HT_BASE, %rax
	movq	(%rax,%rdi,8), %rdi
	testq	%rdi, %rdi
	je	.Lbad
	movq	(%rdi), %rax
	jmp	.Lend
.Lbad:
	movq	$-1, %rax
.Lend:
	nop
.size pure_int_vec_len, .-pure_int_vec_len
