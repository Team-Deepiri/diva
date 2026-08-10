/* Pure unlink(2): rdi = path (C string). rax = 0 ok, 1 error (ignore ENOENT).
   Inlined into caller — NO ret (fall through). */
.section .note.GNU-stack,"",@progbits
.text
.globl pure_unlink
.type pure_unlink, @function
pure_unlink:
	movq	$87, %rax		/* unlink */
	syscall
	xorl	%ecx, %ecx		/* result = 0 */
	cmpq	$0, %rax
	jge	.Lul_done
	cmpq	$-2, %rax		/* -ENOENT */
	je	.Lul_done
	movl	$1, %ecx
.Lul_done:
	movl	%ecx, %eax
	/* fall through — no ret */
.size pure_unlink, .-pure_unlink
