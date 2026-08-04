/* Inlined into caller — NO ret.
   rdi=handle, rsi=value. Rejects null / host-style small handles.
   Capacity full: exit_group(2). Silent skip caused bogus codegen.
   Moving realloc is unsafe while handles are raw mmap pointers
   (needs a stable handle table first). */
.section .note.GNU-stack,"",@progbits
.text
.globl pure_int_vec_push
.type pure_int_vec_push, @function
pure_int_vec_push:
	testq	%rdi, %rdi
	je	.Lfail
	cmpq	$4096, %rdi
	jb	.Lfail
	movq	(%rdi), %rax		/* len */
	movq	0x8(%rdi), %rcx		/* cap */
	cmpq	%rcx, %rax
	jge	.Lfull
	movq	%rsi, 0x18(%rdi,%rax,8)
	incq	%rax
	movq	%rax, (%rdi)
	jmp	.Lok
.Lfull:
	movl	$231, %eax		/* exit_group */
	movl	$2, %edi
	syscall
.Lfail:
	xorl	%eax, %eax
.Lok:
	nop
	/* fall through — no ret */
.size pure_int_vec_push, .-pure_int_vec_push
