/* Pure ELF int_vec_push — handle is table index. Grows with mremap(MAYMOVE). NO ret. */
.equ HT_BASE, 0x500000000000
.equ HT_MAX, 65535
.equ MREMAP_MAYMOVE, 1

.section .note.GNU-stack,"",@progbits
.text
.globl pure_int_vec_push
.type pure_int_vec_push, @function
pure_int_vec_push:
	pushq	%rbx
	pushq	%r12
	pushq	%r13
	pushq	%r14
	movq	%rdi, %r12			/* handle */
	movq	%rsi, %r13			/* value */
	testq	%r12, %r12
	je	.Lfail
	cmpq	$HT_MAX, %r12
	ja	.Lfail
	movabs	$HT_BASE, %rax
	movq	(%rax,%r12,8), %rbx		/* object */
	testq	%rbx, %rbx
	je	.Lfail
.Ltry:
	movq	(%rbx), %rax			/* len */
	movq	8(%rbx), %rcx			/* cap */
	cmpq	%rcx, %rax
	jge	.Lgrow
	movq	%r13, 0x18(%rbx,%rax,8)
	incq	%rax
	movq	%rax, (%rbx)
	jmp	.Lok
.Lgrow:
	movq	16(%rbx), %rsi			/* old_bytes */
	leaq	(%rsi,%rsi), %r14		/* new_bytes = old*2 */
	movq	%rbx, %rdi
	movq	%r14, %rdx
	movl	$MREMAP_MAYMOVE, %r10d
	movl	$25, %eax
	syscall
	cmpq	$-4096, %rax
	ja	.Lfull
	movq	%rax, %rbx
	movabs	$HT_BASE, %rcx
	movq	%rbx, (%rcx,%r12,8)
	movq	%r14, 16(%rbx)			/* map_bytes */
	/* cap = (map_bytes - 24) / 8 */
	leaq	-24(%r14), %rax
	shrq	$3, %rax
	movq	%rax, 8(%rbx)
	jmp	.Ltry
.Lfull:
	movl	$231, %eax
	movl	$2, %edi
	syscall
.Lfail:
	xorl	%eax, %eax
.Lok:
	popq	%r14
	popq	%r13
	popq	%r12
	popq	%rbx
	nop
.size pure_int_vec_push, .-pure_int_vec_push
