/* Pure ELF inline blob: print_int(n), n >= 0. Uses the 128-byte stack red zone below %rsp (no %rsp change). */
.section .note.GNU-stack,"",@progbits
.text
.globl pure_print_int_impl
.type pure_print_int_impl, @function
pure_print_int_impl:
	movq	%rdi, %rax
	leaq	-8(%rsp), %r8
	xorq	%r9, %r9
	movabs	$10, %r11
.Lpd:
	xorl	%edx, %edx
	divq	%r11
	addb	$48, %dl
	movb	%dl, (%r8)
	decq	%r8
	incq	%r9
	testq	%rax, %rax
	jne	.Lpd
	incq	%r8
	movq	%r8, %rsi
	movq	%r9, %rdx
	movl	$1, %edi
	movl	$1, %eax
	syscall
	/* Match hosted di_runtime_print_int: newline after digits. */
	movb	$10, -1(%rsp)
	leaq	-1(%rsp), %rsi
	movl	$1, %edx
	movl	$1, %edi
	movl	$1, %eax
	syscall
	/* no RET: inlined into caller */
.size	pure_print_int_impl, .-pure_print_int_impl
