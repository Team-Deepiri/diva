/* Pure ELF int_vec_push — handle is table index. If the object is an arena slot
   (map_bytes == 0) and full, promote it to a fresh 4KiB mmap (copy header + data,
   update handle table), then continue. Real mmaps grow via mremap(MAYMOVE). NO ret. */
.equ HT_BASE, 0x500000000000
.equ HT_MAX, 1048575
.equ INIT_BYTES, 0x1000
.equ MAP_PRIVATE_ANON, 0x22
.equ PROT_RW, 3
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
	movq	16(%rbx), %rsi			/* map_bytes */
	testq	%rsi, %rsi
	jne	.Lgrow_mmap			/* real mmap: mremap */
	/* arena slot full: promote to a fresh 4KiB mmap */
	xorl	%edi, %edi
	movl	$INIT_BYTES, %esi
	movl	$PROT_RW, %edx
	movl	$MAP_PRIVATE_ANON, %r10d
	movq	$-1, %r8
	xorl	%r9d, %r9d
	movl	$9, %eax
	syscall
	cmpq	$-4096, %rax
	ja	.Lfull
	movq	%rax, %r14			/* new object */
	movq	(%rbx), %rcx			/* len (cap == len here) */
	movq	%rcx, (%r14)
	movl	$((INIT_BYTES - 24) / 8), %ecx
	movq	%rcx, 8(%r14)			/* cap */
	movl	$INIT_BYTES, %ecx
	movq	%rcx, 16(%r14)			/* map_bytes */
	/* copy existing payload: SLOT_BYTES - 24 qwords max; copy len qwords */
	movq	(%rbx), %rcx			/* len */
	testq	%rcx, %rcx
	je	.Lcopied
	leaq	0x18(%rbx), %rsi		/* src payload */
	leaq	0x18(%r14), %rdi		/* dst payload */
	shlq	$3, %rcx
	rep movsb
.Lcopied:
	movabs	$HT_BASE, %rcx
	movq	%r14, (%rcx,%r12,8)		/* update table */
	movq	%r14, %rbx
	jmp	.Ltry
.Lgrow_mmap:
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
