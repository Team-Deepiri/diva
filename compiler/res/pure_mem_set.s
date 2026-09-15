/* mem_set(ptr, index, value): store rdx at ptr+index*8. rax=0. Inlined — NO ret. */
.section .note.GNU-stack,"",@progbits
.text
.globl pure_mem_set
.type pure_mem_set, @function
pure_mem_set:
	movq	%rdx, (%rdi,%rsi,8)
	xorl	%eax, %eax
	/* fall through — no ret */
.size pure_mem_set, .-pure_mem_set
