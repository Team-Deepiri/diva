/* Pure ELF str_slice(s, start, len) — copy into packed string arena. NO ret.
   Args: rdi=s, rsi=start, rdx=len. */
.equ STRA_BASE, 0x520000000000
.equ STRA_BYTES, 0x80000000
.equ MAP_PRIVATE_ANON_FIXED_NR, 0x100032
.equ PROT_RW, 3

.section .note.GNU-stack,"",@progbits
.text
.globl pure_str_slice
.type pure_str_slice, @function
pure_str_slice:
	pushq	%rbx
	pushq	%r12
	pushq	%r13
	pushq	%r14
	movq	%rdi, %r14			/* s */
	movq	%rsi, %r12			/* start */
	movq	%rdx, %r13			/* len */
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
	cmpq	$0, %r13
	jg	.Lcopy
	/* empty string: need 1 byte */
	movl	$1, %r13d
	xorl	%r12d, %r12d
	xorl	%r14d, %r14d			/* no source; just NUL */
	jmp	.Lalloc
.Lcopy:
	/* fallthrough with real s/start/len */
.Lalloc:
	movabs	$STRA_BASE, %rax
	movq	(%rax), %rbx
	movq	8(%rax), %rdx
	movq	%r13, %rcx
	addq	$1, %rcx
	addq	$7, %rcx
	andq	$-8, %rcx
	leaq	(%rbx,%rcx), %rsi
	cmpq	%rdx, %rsi
	ja	.Lfull
	movq	%rsi, (%rax)
	testq	%r14, %r14
	je	.Lempty
	leaq	(%r14,%r12), %rsi
	movq	%rbx, %rdi
	movq	%r13, %rcx
	rep movsb
	movb	$0, (%rdi)
	movq	%rbx, %rax
	jmp	.Lpop
.Lempty:
	movb	$0, (%rbx)
	movq	%rbx, %rax
	jmp	.Lpop
.Lfull:
	movl	$231, %eax
	movl	$2, %edi
	syscall
.Lpop:
	popq	%r14
	popq	%r13
	popq	%r12
	popq	%rbx
	nop
.size pure_str_slice, .-pure_str_slice
