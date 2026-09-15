/* mem_free(user_ptr): munmap base=ptr-8 with size from [base]. Inlined — NO ret. */
.section .note.GNU-stack,"",@progbits
.text
.globl pure_mem_free
.type pure_mem_free, @function
pure_mem_free:
	testq	%rdi, %rdi
	jz	.Lmf_done
	subq	$8, %rdi
	movq	(%rdi), %rsi
	movl	$11, %eax
	syscall
	xorl	%eax, %eax
.Lmf_done:
	/* fall through — no ret */
.size pure_mem_free, .-pure_mem_free
