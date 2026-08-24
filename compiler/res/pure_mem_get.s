/* mem_get(ptr, index): rax = qword at ptr+index*8. Inlined — NO ret. */
.section .note.GNU-stack,"",@progbits
.text
.globl pure_mem_get
.type pure_mem_get, @function
pure_mem_get:
	movq	(%rdi,%rsi,8), %rax
	/* fall through — no ret */
.size pure_mem_get, .-pure_mem_get
