/* Pure ELF str_builder_len — handle is table index. NO ret. */
.equ HT_BASE, 0x500000000000
.equ HT_MAX, 65535

.section .note.GNU-stack,"",@progbits
.text
.globl pure_str_builder_len
.type pure_str_builder_len, @function
pure_str_builder_len:
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
.size pure_str_builder_len, .-pure_str_builder_len
