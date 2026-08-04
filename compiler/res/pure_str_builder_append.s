/* Inlined at ir_call (no ret). Reject host-style small “handles” on rdi (builder) and rsi (append text). */
.section .note.GNU-stack,"",@progbits
.text
.globl pure_str_builder_append
.type pure_str_builder_append, @function
pure_str_builder_append:
	testq	%rdi, %rdi
	je	.Lbad
	cmpq	$4096, %rdi
	jb	.Lbad
	testq	%rsi, %rsi
	je	.Lbad
	cmpq	$4096, %rsi
	jb	.Lbad
	jmp	.Lgo
.Lbad:
	xorl	%eax, %eax
	jmp	.Ltail
.Lgo:
	pushq	%rbx
	pushq	%r12
	pushq	%r13
	pushq	%r14
	movq	%rdi, %rbx
	movq	%rsi, %r12
	xorl	%ecx, %ecx
0:
	cmpb	$0, (%r12,%rcx,1)
	je	1f
	incq	%rcx
	jmp	0b
1:
	testq	%rcx, %rcx
	je	3f
	movq	(%rbx), %rax
	movq	0x8(%rbx), %r8
	movq	%rax, %r13
	addq	%rcx, %r13
	cmpq	%r8, %r13
	ja	.Lfull
	leaq	0x18(%rbx,%rax,1), %r14
	movq	%r14, %rdi
	movq	%r12, %rsi
	movq	%rcx, %r9
	rep movsb
	movq	%r13, (%rbx)
	jmp	4f
.Lfull:
	/* capacity full — exit_group(2); silent skip is unsafe */
	movl	$231, %eax
	movl	$2, %edi
	syscall
3:
	xorl	%eax, %eax
4:
	popq	%r14
	popq	%r13
	popq	%r12
	popq	%rbx
.Ltail:
	nop
	/* fall through — no ret */
.size pure_str_builder_append, .-pure_str_builder_append
