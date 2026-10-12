/* text_concat(a, b): allocate a fresh mmap text descriptor containing a's bytes
   followed by b's bytes (rdi=a, rsi=b). Sets len=cap=lenA+lenB, data_off=24.
   Returns descriptor pointer in rax, or 0 on mmap failure. Inlined — NO ret.
   Preserves callee-saved r12/r13/r14/r15. */
.section .note.GNU-stack,"",@progbits
.text
.globl pure_text_concat
.type pure_text_concat, @function
pure_text_concat:
	pushq	%r12
	pushq	%r13
	pushq	%r14
	movq	%rdi, %r12         /* descA */
	movq	%rsi, %r13         /* descB */
	movq	8(%r12), %r14      /* lenA */
	movq	8(%r13), %rcx      /* lenB */
	addq	%rcx, %r14         /* total */
	leaq	25(%r14), %rsi
	addq	$4095, %rsi
	andq	$-4096, %rsi       /* size = round_up(total + 25, 4096) */
	xorl	%edi, %edi
	movl	$3, %edx
	movl	$0x22, %r10d
	movq	$-1, %r8
	xorl	%r9d, %r9d
	movl	$9, %eax
	syscall
	cmpq	$-4096, %rax
	ja	.Lcc_fail
	movq	%rax, %r11         /* desc */
	leaq	24(%rax), %rdi     /* dst = desc + 24 */
	movq	$24, (%rax)
	movq	%r14, 8(%rax)
	movq	%r14, 16(%rax)
	movq	(%r12), %rax
	addq	%r12, %rax         /* dataA */
	movq	8(%r12), %rcx      /* lenA */
.Lcc_a:
	testq	%rcx, %rcx
	je	.Lcc_b0
	movb	(%rax), %dl
	movb	%dl, (%rdi)
	incq	%rax
	incq	%rdi
	decq	%rcx
	jmp	.Lcc_a
.Lcc_b0:
	movq	(%r13), %rax
	addq	%r13, %rax         /* dataB */
	movq	8(%r13), %rcx      /* lenB */
.Lcc_b:
	testq	%rcx, %rcx
	je	.Lcc_fin
	movb	(%rax), %dl
	movb	%dl, (%rdi)
	incq	%rax
	incq	%rdi
	decq	%rcx
	jmp	.Lcc_b
.Lcc_fin:
	movb	$0, (%rdi)
	movq	%r11, %rax
	popq	%r14
	popq	%r13
	popq	%r12
	jmp	.Lcc_done
.Lcc_fail:
	xorl	%eax, %eax
	popq	%r14
	popq	%r13
	popq	%r12
.Lcc_done:
	/* fall through — no ret */
.size pure_text_concat, .-pure_text_concat
