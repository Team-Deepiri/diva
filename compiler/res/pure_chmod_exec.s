/* Pure chmod(2): rdi = path. Sets mode 0755. rax = 0 ok, 1 err. */
.section .note.GNU-stack,"",@progbits
.text
.globl pure_chmod_exec
.type pure_chmod_exec, @function
pure_chmod_exec:
	movq	$90, %rax           /* chmod */
	movq	$493, %rsi          /* 0755 */
	syscall
	cmpq	$0, %rax
	jl	1f
	xorl	%eax, %eax
	ret
1:
	movl	$1, %eax
	ret
.size pure_chmod_exec, .-pure_chmod_exec
