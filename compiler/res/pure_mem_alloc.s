/* mem_alloc(nbytes): mmap page-rounded (nbytes+8), store map size at [base],
   return user pointer base+8 (or 0 on failure). Inlined — NO ret. Preserves r15. */
.section .note.GNU-stack,"",@progbits
.text
.globl pure_mem_alloc
.type pure_mem_alloc, @function
pure_mem_alloc:
	pushq	%r12
	movq	%rdi, %rsi
	addq	$8, %rsi
	addq	$4095, %rsi
	andq	$-4096, %rsi
	jne	1f
	movq	$4096, %rsi
1:
	movq	%rsi, %r12
	xorl	%edi, %edi
	movl	$3, %edx
	movl	$0x22, %r10d
	movq	$-1, %r8
	xorl	%r9d, %r9d
	movl	$9, %eax
	syscall
	cmpq	$-4096, %rax
	ja	.Lma_fail
	movq	%r12, (%rax)
	addq	$8, %rax
	popq	%r12
	jmp	.Lma_done
.Lma_fail:
	xorl	%eax, %eax
	popq	%r12
.Lma_done:
	/* fall through — no ret */
.size pure_mem_alloc, .-pure_mem_alloc
