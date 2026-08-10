/* Pure ELF int_vec_new — returns stable handle (table index), not raw mmap ptr.
   Inlined at ir_call sites: NO ret.
   Layout at object: [len][cap][map_bytes][data...]; map starts at INIT_BYTES, grows via push. */
.equ HT_BASE, 0x500000000000
.equ HT_BYTES, 0x800000
.equ HT_MAX, 1048575
.equ INIT_BYTES, 0x1000
.equ MAP_FIXED_NOREPLACE, 0x100000
.equ MAP_PRIVATE_ANON_FIXED_NR, 0x100032
.equ PROT_RW, 3

.section .note.GNU-stack,"",@progbits
.text
.globl pure_int_vec_new
.type pure_int_vec_new, @function
pure_int_vec_new:
	pushq	%rbx
	pushq	%r12
	/* ensure handle table */
	movabs	$HT_BASE, %rdi
	movl	$HT_BYTES, %esi
	movl	$PROT_RW, %edx
	movl	$MAP_PRIVATE_ANON_FIXED_NR, %r10d
	movq	$-1, %r8
	xorl	%r9d, %r9d
	movl	$9, %eax
	syscall
	cmpq	$-4096, %rax
	jbe	.Ltab_ok			/* success: rax == HT_BASE */
	/* FIXED_NOREPLACE failed (EEXIST etc.) — table already mapped. */
	jmp	.Ltab_ready
.Ltab_ok:
	movq	$1, (%rax)			/* next handle id = 1 */
.Ltab_ready:
	/* mmap object */
	xorl	%edi, %edi
	movl	$INIT_BYTES, %esi
	movl	$PROT_RW, %edx
	movl	$0x22, %r10d			/* PRIVATE|ANON */
	movq	$-1, %r8
	xorl	%r9d, %r9d
	movl	$9, %eax
	syscall
	cmpq	$-4096, %rax
	ja	.Lfail
	movq	%rax, %rbx			/* object ptr */
	movq	$0, (%rbx)			/* len */
	movl	$((INIT_BYTES - 24) / 8), %ecx
	movq	%rcx, 8(%rbx)			/* cap */
	movl	$INIT_BYTES, %ecx
	movq	%rcx, 16(%rbx)			/* map_bytes */
	/* register in table */
	movabs	$HT_BASE, %r12
	movq	(%r12), %rdx			/* next */
	cmpq	$HT_MAX, %rdx
	ja	.Lfail_unmap
	movq	%rbx, (%r12,%rdx,8)
	leaq	1(%rdx), %rcx
	movq	%rcx, (%r12)
	movq	%rdx, %rax			/* return handle */
	popq	%r12
	popq	%rbx
	jmp	.Lend
.Lfail_unmap:
	movq	%rbx, %rdi
	movl	$INIT_BYTES, %esi
	movl	$11, %eax
	syscall
.Lfail:
	xorl	%eax, %eax
	popq	%r12
	popq	%rbx
.Lend:
	nop
.size pure_int_vec_new, .-pure_int_vec_new
