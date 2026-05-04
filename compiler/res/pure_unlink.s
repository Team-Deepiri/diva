/* Pure unlink(2): rdi = path (C string). rax = 0 ok, 1 error (ignore ENOENT). */
.section .note.GNU-stack,"",@progbits
.text
.globl pure_unlink
.type pure_unlink, @function
pure_unlink:
	movq	$87, %rax           /* unlink */
	syscall
	cmpq	$0, %rax
	jl	1f
	xorl	%eax, %eax
	ret
1:
	cmpq	$-2, %rax           /* -ENOENT */
	je	2f
	movl	$1, %eax
	ret
2:
	xorl	%eax, %eax
	ret
.size pure_unlink, .-pure_unlink
