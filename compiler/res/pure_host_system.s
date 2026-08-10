/* Pure-ELF host_system (id 27): rdi = command (null-terminated).
 * vfork, child execve /bin/sh -c cmd; parent wait4. rax = wait status or -1.
 * Strings built on stack (no .rodata relocs) for flat binary extraction. */
.section .note.GNU-stack,"",@progbits
.text
.globl pure_host_system
.type pure_host_system, @function
pure_host_system:
	pushq	%rbx
	pushq	%r12
	pushq	%r13
	pushq	%r14
	movq	%rdi, %rbx
	movq	$58, %rax           /* vfork */
	syscall
	cmpq	$0, %rax
	jl	err_fork
	je	child
	movq	%rax, %r12
	subq	$16, %rsp
wait_loop:
	movq	%r12, %rdi
	movq	%rsp, %rsi
	xorq	%rdx, %rdx
	xorq	%r10, %r10
	movq	$61, %rax           /* wait4 */
	syscall
	cmpq	$0, %rax
	jg	wait_ok
	cmpq	$-4, %rax           /* -EINTR */
	je	wait_loop
	movl	$-1, %eax
	addq	$16, %rsp
	jmp	done_parent
wait_ok:
	movl	(%rsp), %eax
	addq	$16, %rsp
done_parent:
	popq	%r14
	popq	%r13
	popq	%r12
	popq	%rbx
	jmp	pure_host_system_exit

child:
	subq	$128, %rsp
	/* "/bin/sh\0" at (%rsp) */
	movl	$0x6e69622f, (%rsp)
	movl	$0x0068732f, 4(%rsp)
	/* "-c\0" at 16(%rsp) */
	movw	$0x632d, 16(%rsp)
	movb	$0, 18(%rsp)
	/* argv: ptrs at 32(%rsp) */
	leaq	(%rsp), %rax
	movq	%rax, 32(%rsp)
	leaq	16(%rsp), %rax
	movq	%rax, 40(%rsp)
	movq	%rbx, 48(%rsp)
	movq	$0, 56(%rsp)
	leaq	(%rsp), %rdi
	leaq	32(%rsp), %rsi
	xorq	%rdx, %rdx
	movq	$59, %rax
	syscall
	movq	$127, %rdi
	movq	$60, %rax
	syscall

err_fork:
	movl	$-1, %eax
	popq	%r14
	popq	%r13
	popq	%r12
	popq	%rbx
	jmp	pure_host_system_exit

/* Fall-through target for inline emission (no ret — avoids bogus stack pop). */
pure_host_system_exit:

.size pure_host_system, .-pure_host_system
