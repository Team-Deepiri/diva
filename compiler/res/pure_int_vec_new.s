/* Pure ELF int_vec_new — carves a fixed-capacity slot from the AST bump arena (NOT one
   mmap per object). Kernel rounds every anon mmap up to a page; ~135k tiny AST nodes
   were ~0.5 GiB of page tax. map_bytes=0 marks an arena slot (free skips munmap; push
   promotes to a real mmap when the slot fills). Falls back to a 4KiB mmap if the arena
   is exhausted. Handle = table index. Inlined at ir_call sites: NO ret. */
.equ HT_BASE, 0x500000000000
.equ HT_BYTES, 0x800000
.equ HT_MAX, 1048575
.equ ASTA_BASE, 0x540000000000
.equ ASTA_BYTES, 0x80000000
.equ SLOT_BYTES, 0x80
.equ INIT_BYTES, 0x1000
.equ MAP_PRIVATE_ANON_FIXED_NR, 0x100032
.equ MAP_PRIVATE_ANON, 0x22
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
	jbe	.Ltab_ok
	jmp	.Ltab_ready
.Ltab_ok:
	movq	$1, (%rax)			/* next handle id = 1 */
.Ltab_ready:
	/* ensure AST arena */
	movabs	$ASTA_BASE, %rdi
	movl	$ASTA_BYTES, %esi
	movl	$PROT_RW, %edx
	movl	$MAP_PRIVATE_ANON_FIXED_NR, %r10d
	movq	$-1, %r8
	xorl	%r9d, %r9d
	movl	$9, %eax
	syscall
	cmpq	$-4096, %rax
	jbe	.Lasta_ok
	jmp	.Lasta_ready
.Lasta_ok:
	movabs	$ASTA_BASE, %rax
	leaq	64(%rax), %rcx			/* bump starts after header */
	movq	%rcx, (%rax)
	movl	$ASTA_BYTES, %ecx
	addq	%rax, %rcx
	movq	%rcx, 8(%rax)			/* end */
.Lasta_ready:
	/* carve slot */
	movabs	$ASTA_BASE, %r12
	movq	(%r12), %rbx			/* bump */
	movq	8(%r12), %rax			/* end */
	leaq	SLOT_BYTES(%rbx), %rcx		/* new_bump */
	cmpq	%rax, %rcx
	ja	.Luse_mmap			/* arena full: fall back */
	movq	%rcx, (%r12)
	movq	$0, (%rbx)			/* len */
	movl	$((SLOT_BYTES - 24) / 8), %ecx
	movq	%rcx, 8(%rbx)			/* cap */
	movq	$0, 16(%rbx)			/* map_bytes = 0 => arena slot */
	jmp	.Lregister
.Luse_mmap:
	/* fallback: plain 4KiB object mmap (not arena) */
	xorl	%edi, %edi
	movl	$INIT_BYTES, %esi
	movl	$PROT_RW, %edx
	movl	$MAP_PRIVATE_ANON, %r10d
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
.Lregister:
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
	cmpq	$0, 16(%rbx)
	je	.Lfail				/* arena slot: nothing to unmap */
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
