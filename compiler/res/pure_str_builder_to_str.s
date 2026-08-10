/* Pure ELF str_builder_to_str — handle index; returns packed C string from a
   bump arena (NOT one mmap-per-string). Kernel rounds every anon mmap up to a
   page; millions of tiny to_str results were ~28GiB RSS. NO ret.
   Arena @ 0x520000000000: [bump][end] then bytes; FIXED_NOREPLACE. */
.equ HT_BASE, 0x500000000000
.equ HT_MAX, 1048575
.equ STRA_BASE, 0x520000000000
.equ STRA_BYTES, 0x80000000
.equ MAP_PRIVATE_ANON_FIXED_NR, 0x100032
.equ PROT_RW, 3

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
	pushq	%r14
	movq	%rdi, %r12			/* builder object */
	movq	(%r12), %r13			/* len */
	/* ensure string arena */
	movabs	$STRA_BASE, %rdi
	movl	$STRA_BYTES, %esi
	movl	$PROT_RW, %edx
	movl	$MAP_PRIVATE_ANON_FIXED_NR, %r10d
	movq	$-1, %r8
	xorl	%r9d, %r9d
	movl	$9, %eax
	syscall
	cmpq	$-4096, %rax
	jbe	.Larena_ok			/* success: rax == STRA_BASE */
	jmp	.Larena_ready			/* EEXIST: already mapped */
.Larena_ok:
	movabs	$STRA_BASE, %rax
	leaq	64(%rax), %rcx			/* bump starts after header */
	movq	%rcx, (%rax)
	movl	$STRA_BYTES, %ecx
	addq	%rax, %rcx
	movq	%rcx, 8(%rax)			/* end */
.Larena_ready:
	movabs	$STRA_BASE, %r14
	movq	(%r14), %rbx			/* bump */
	movq	8(%r14), %rax			/* end */
	movq	%r13, %rcx
	addq	$1, %rcx			/* need = len+1 */
	/* align need up to 8 */
	addq	$7, %rcx
	andq	$-8, %rcx
	leaq	(%rbx,%rcx), %rdx		/* new_bump */
	cmpq	%rax, %rdx
	ja	.Lfull
	movq	%rdx, (%r14)
	/* copy len bytes + NUL */
	leaq	0x18(%r12), %rsi
	movq	%rbx, %rdi
	movq	%r13, %rcx
	rep movsb
	movb	$0, (%rdi)
	movq	%rbx, %rax			/* return string ptr */
	popq	%r14
	popq	%r13
	popq	%r12
	popq	%rbx
	jmp	.Ltail
.Lfull:
	movl	$231, %eax
	movl	$2, %edi
	syscall
.Ltail:
	nop
.size pure_str_builder_to_str, .-pure_str_builder_to_str
