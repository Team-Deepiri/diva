/* text_slice(t, start, len): zero-copy view into t's bytes starting at `start`
   (rdi=t, rsi=start, rdx=len). Allocates a fresh 4096-byte mmap descriptor whose
   data_off points into the parent buffer and whose cap is -1 (borrowed/view).
   Returns descriptor pointer in rax, or 0 on mmap failure. Inlined — NO ret.
   Preserves callee-saved r12/r13/r14/r15. */
.section .note.GNU-stack,"",@progbits
.text
.globl pure_text_slice
.type pure_text_slice, @function
pure_text_slice:
	pushq	%r12
	pushq	%r13
	pushq	%r14
	movq	%rdi, %r12         /* desc */
	movq	%rsi, %r13         /* start */
	movq	%rdx, %r14         /* len */
	xorl	%edi, %edi
	movl	$4096, %esi
	movl	$3, %edx
	movl	$0x22, %r10d
	movq	$-1, %r8
	xorl	%r9d, %r9d
	movl	$9, %eax
	syscall
	cmpq	$-4096, %rax
	ja	.Lcs_fail
	movq	(%r12), %rcx       /* t.data_off */
	addq	%r12, %rcx         /* t.data pointer */
	addq	%r13, %rcx         /* + start */
	subq	%rax, %rcx         /* new data_off = data + start - desc */
	movq	%rcx, (%rax)
	movq	%r14, 8(%rax)
	movq	$-1, 16(%rax)      /* cap = -1: borrowed view, never freed */
	popq	%r14
	popq	%r13
	popq	%r12
	jmp	.Lcs_done
.Lcs_fail:
	xorl	%eax, %eax
	popq	%r14
	popq	%r13
	popq	%r12
.Lcs_done:
	/* fall through — no ret */
.size pure_text_slice, .-pure_text_slice
