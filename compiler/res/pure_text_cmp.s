/* text_cmp(a, b): lexicographic compare of two text descriptors (rdi=a, rsi=b).
   Returns rax = -1, 0, 1. Compares the min-length prefix byte by byte, then length.
   Inlined — NO ret. Only caller-saved r11/rdi are clobbered. */
.section .note.GNU-stack,"",@progbits
.text
.globl pure_text_cmp
.type pure_text_cmp, @function
pure_text_cmp:
	movq	(%rdi), %rax       /* dataA offset */
	addq	%rdi, %rax         /* dataA */
	movq	(%rsi), %rcx       /* dataB offset */
	addq	%rsi, %rcx         /* dataB */
	movq	8(%rdi), %rdx      /* lenA */
	movq	8(%rsi), %r8       /* lenB */
	movq	%rdx, %r10         /* n = lenA */
	cmpq	%r8, %r10
	jle	.Lc_n
	movq	%r8, %r10          /* n = lenB */
.Lc_n:
	xorl	%r9d, %r9d         /* i = 0 */
.Lc_loop:
	cmpq	%r10, %r9
	jge	.Lc_end
	movzbl	(%rax,%r9,1), %r11d
	movzbl	(%rcx,%r9,1), %edi
	cmpl	%edi, %r11d
	jne	.Lc_diff
	incq	%r9
	jmp	.Lc_loop
.Lc_diff:
	cmpl	%edi, %r11d
	jl	.Lc_neg
	movl	$1, %eax
	jmp	.Lc_end2
.Lc_neg:
	movq	$-1, %rax
	jmp	.Lc_end2
.Lc_end:
	cmpq	%r8, %rdx
	jl	.Lc_neg
	jg	.Lc_pos
	xorl	%eax, %eax
	jmp	.Lc_end2
.Lc_pos:
	movl	$1, %eax
.Lc_end2:
	/* fall through — no ret */
.size pure_text_cmp, .-pure_text_cmp
