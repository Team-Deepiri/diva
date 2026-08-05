/* Pure ELF str_builder_to_str — handle index; returns fresh mmap C string. NO ret. */
.equ HT_BASE, 0x500000000000
.equ HT_MAX, 1048575

.section .note.GNU-stack,"",@progbits
.text
.globl pure_str_builder_to_str
.type pure_str_builder_to_str, @function
pure_str_builder_to_str:
	testq	%rdi, %rdi
	je	.Lbad
	cmpq	$HT_MAX, %rdi
	ja	.Lbad
	movabs	$HT_BASE, %rax
	movq	(%rax,%rdi,8), %rdi
	testq	%rdi, %rdi
	je	.Lbad
	jmp	.Lgo
.Lbad:
	xorl	%eax, %eax
	jmp	.Ltail
.Lgo:
	pushq	%rbx
	pushq	%r12
	pushq	%r13
	movq	%rdi, %r12
	movq	(%r12), %r13
	xorl	%edi, %edi
	movq	%r13, %rsi
	addq	$1, %rsi
	movl	$3, %edx
	movl	$0x22, %r10d
	movq	$-1, %r8
	xorq	%r9, %r9
	movl	$9, %eax
	syscall
	movq	%rax, %rbx
	leaq	0x18(%r12), %rsi
	movq	%rbx, %rdi
	movq	%r13, %rcx
	rep movsb
	movb	$0, (%rdi)
	movq	%rbx, %rax
	popq	%r13
	popq	%r12
	popq	%rbx
.Ltail:
	nop
.size pure_str_builder_to_str, .-pure_str_builder_to_str
