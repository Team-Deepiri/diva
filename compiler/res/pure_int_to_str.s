/* Pure ELF int_to_str — format into stack scratch, copy into packed string arena.
   Avoids mmap(len+1) per call (page-rounded RSS blowup). NO ret. */
.equ STRA_BASE, 0x520000000000
.equ STRA_BYTES, 0x80000000
.equ MAP_PRIVATE_ANON_FIXED_NR, 0x100032
.equ PROT_RW, 3

.section .note.GNU-stack,"",@progbits
.text
.globl pure_int_to_str
.type pure_int_to_str, @function
pure_int_to_str:
	pushq	%rbx
	pushq	%r12
	pushq	%r13
	pushq	%r14
	movq	%rdi, %r12
	xorl	%r13d, %r13d
	movq	%r12, %rdi
	testq	%rdi, %rdi
	jns	.Labs
	movl	$1, %r13d
	negq	%rdi
.Labs:
	leaq	-128(%rsp), %rbx
	leaq	127(%rbx), %rcx
.Ldig:
	xorl	%edx, %edx
	movq	%rdi, %rax
	movl	$10, %esi
	divq	%rsi
	movq	%rax, %rdi
	addb	$0x30, %dl
	movb	%dl, (%rcx)
	decq	%rcx
	testq	%rax, %rax
	jnz	.Ldig
	cmpl	$0, %r13d
	je	.Lnosign
	movb	$0x2d, (%rcx)
	decq	%rcx
.Lnosign:
	incq	%rcx
	movq	%rcx, %r14			/* start of digits */
	leaq	-128(%rsp), %rax
	addq	$128, %rax
	subq	%r14, %rax
	movq	%rax, %r12			/* len */
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
	jbe	.Larena_ok
	jmp	.Larena_ready
.Larena_ok:
	movabs	$STRA_BASE, %rax
	leaq	64(%rax), %rcx
	movq	%rcx, (%rax)
	movl	$STRA_BYTES, %ecx
	addq	%rax, %rcx
	movq	%rcx, 8(%rax)
.Larena_ready:
	movabs	$STRA_BASE, %rax
	movq	(%rax), %rbx			/* bump */
	movq	8(%rax), %rdx			/* end */
	movq	%r12, %rcx
	addq	$1, %rcx
	addq	$7, %rcx
	andq	$-8, %rcx			/* aligned need */
	leaq	(%rbx,%rcx), %rsi
	cmpq	%rdx, %rsi
	ja	.Lfull
	movq	%rsi, (%rax)
	movq	%rbx, %rdi
	movq	%r14, %rsi
	movq	%r12, %rcx
	rep movsb
	movb	$0, (%rdi)
	movq	%rbx, %rax
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
.size pure_int_to_str, .-pure_int_to_str
