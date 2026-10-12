/* text_from_str(s): build a text descriptor {data_off=24, len=strlen(s), cap=strlen(s)}
   with the string bytes copied to desc+24, all inside a fresh mmap block of 4096 bytes.
   Descriptor layout matches text literals (PIE-safe: field 0 is an offset, not an
   absolute address). Return descriptor pointer (rax), or 0 on mmap failure.
   Inlined — NO ret. Preserves callee-saved r12/r13 and r15 (untouched). */
.section .note.GNU-stack,"",@progbits
.text
.globl pure_text_from_str
.type pure_text_from_str, @function
pure_text_from_str:
	pushq	%r12
	pushq	%r13
	movq	%rdi, %r12
	movq	%rdi, %rsi
	xorl	%r13d, %r13d
.Ltfs_scan:
	cmpb	$0, (%rsi)
	je	.Ltfs_len_done
	incq	%rsi
	incq	%r13
	jmp	.Ltfs_scan
.Ltfs_len_done:
	xorl	%edi, %edi
	movl	$4096, %esi
	movl	$3, %edx
	movl	$0x22, %r10d
	movq	$-1, %r8
	xorl	%r9d, %r9d
	movl	$9, %eax
	syscall
	cmpq	$-4096, %rax
	ja	.Ltfs_fail
	leaq	24(%rax), %rdi
	movq	%r12, %rsi
	movq	%r13, %rcx
.Ltfs_copy:
	testq	%rcx, %rcx
	je	.Ltfs_copied
	movb	(%rsi), %dl
	movb	%dl, (%rdi)
	incq	%rsi
	incq	%rdi
	decq	%rcx
	jmp	.Ltfs_copy
.Ltfs_copied:
	movq	$24, (%rax)
	movq	%r13, 8(%rax)
	movq	%r13, 16(%rax)
	popq	%r13
	popq	%r12
	jmp	.Ltfs_end
.Ltfs_fail:
	xorl	%eax, %eax
	popq	%r13
	popq	%r12
.Ltfs_end:
	/* fall through — no ret */
.size pure_text_from_str, .-pure_text_from_str