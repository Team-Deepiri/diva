/* Pure chmod(2): rdi = path. Sets mode 0755. rax = 0 ok, 1 err.
   Inlined into caller — NO ret (fall through). */
.section .note.GNU-stack,"",@progbits
.text
.globl pure_chmod_exec
.type pure_chmod_exec, @function
pure_chmod_exec:
	movq	$90, %rax		/* chmod */
	movq	$493, %rsi		/* 0755 */
	syscall
	xorl	%ecx, %ecx
	cmpq	$0, %rax
	jge	.Lch_done
	movl	$1, %ecx
.Lch_done:
	movl	%ecx, %eax
	/* fall through — no ret */
.size pure_chmod_exec, .-pure_chmod_exec
