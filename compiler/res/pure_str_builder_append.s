/* Pure ELF str_builder_append — handle index; grow via mremap(MAYMOVE). NO ret.
   rsi remains a raw C string pointer (not a handle). */
.equ HT_BASE, 0x500000000000
.equ HT_MAX, 1048575
.equ MREMAP_MAYMOVE, 1

.section .note.GNU-stack,"",@progbits
.text
.globl pure_str_builder_append
.type pure_str_builder_append, @function
pure_str_builder_append:
	testq	%rdi, %rdi
	je	.Lbad
	cmpq	$HT_MAX, %rdi
	ja	.Lbad
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
	pushq	%r15
	movq	%rdi, %r15			/* handle */
	movq	%rsi, %r12			/* text */
	movabs	$HT_BASE, %rax
	movq	(%rax,%r15,8), %rbx
	testq	%rbx, %rbx
	je	.Lfail_pop
	xorl	%ecx, %ecx
0:
	cmpb	$0, (%r12,%rcx,1)
	je	1f
	incq	%rcx
	jmp	0b
1:
	testq	%rcx, %rcx
	je	.Lempty
	movq	%rcx, %r13			/* nbytes */
.Ltry:
	movq	(%rbx), %rax			/* len */
	movq	8(%rbx), %r8			/* cap */
	leaq	(%rax,%r13), %r14		/* newlen */
	cmpq	%r8, %r14
	ja	.Lgrow
	leaq	0x18(%rbx,%rax,1), %rdi
	movq	%r12, %rsi
	movq	%r13, %rcx
	rep movsb
	movq	%r14, (%rbx)
	xorl	%eax, %eax
	jmp	.Lpop
.Lgrow:
	movq	16(%rbx), %rsi
	leaq	(%rsi,%rsi), %r14		/* new_bytes — reuse r14 temporarily */
	movq	%rbx, %rdi
	movq	%r14, %rdx
	movl	$MREMAP_MAYMOVE, %r10d
	movl	$25, %eax
	syscall
	cmpq	$-4096, %rax
	ja	.Lfull
	movq	%rax, %rbx
	movabs	$HT_BASE, %rcx
	movq	%rbx, (%rcx,%r15,8)
	movq	%r14, 16(%rbx)
	leaq	-24(%r14), %rax
	movq	%rax, 8(%rbx)			/* byte cap */
	jmp	.Ltry
.Lfull:
	movl	$231, %eax
	movl	$2, %edi
	syscall
.Lempty:
	xorl	%eax, %eax
	jmp	.Lpop
.Lfail_pop:
	xorl	%eax, %eax
.Lpop:
	popq	%r15
	popq	%r14
	popq	%r13
	popq	%r12
	popq	%rbx
.Ltail:
	nop
.size pure_str_builder_append, .-pure_str_builder_append
