/* Pure ELF inline blob: write one ELF byte chunk via mmap + open + write.
   SysV: rdi=path, rsi=vec ptr, rdx=pos, rcx=take, r8=is_first (nonzero => O_TRUNC).
   Preserves r15 (push/pop). No RET — inlined into caller.
   CRITICAL: save is_first before mmap (mmap sets r8=-1); else every chunk O_TRUNC
   and only the last chunk (~n%64000 bytes) survives. */
.section .note.GNU-stack,"",@progbits
.text
.globl pure_write_elf_chunk_impl
.type pure_write_elf_chunk_impl, @function
pure_write_elf_chunk_impl:
	pushq	%rbx
	pushq	%rbp
	pushq	%r12
	pushq	%r13
	pushq	%r14
	pushq	%r15
	pushq	%r8			/* is_first — mmap clobbers r8 */

	movq	%rdi, %r15		/* path */
	/* rsi = int_vec handle (table index) — resolve to object pointer */
	testq	%rsi, %rsi
	je	.Lpw_fail
	cmpq	$65535, %rsi
	ja	.Lpw_fail
	movabs	$0x500000000000, %rax
	movq	(%rax,%rsi,8), %rbx	/* vec object */
	testq	%rbx, %rbx
	je	.Lpw_fail
	movq	%rdx, %r12		/* pos */
	movq	%rcx, %r13		/* take */

	/* mmap(NULL, take, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) */
	xorl	%edi, %edi
	movq	%r13, %rsi
	movl	$3, %edx
	movl	$0x22, %r10d
	movq	$-1, %r8
	xorq	%r9, %r9
	movl	$9, %eax
	syscall
	cmpq	$0, %rax
	js	.Lpw_fail
	movq	%rax, %rbp		/* mmap ptr */

	xorq	%r14, %r14
.Lpw_fill:
	cmpq	%r13, %r14
	jge	.Lpw_fill_done
	movq	%r12, %rsi
	addq	%r14, %rsi
	movq	24(%rbx,%rsi,8), %rax
	movb	%al, (%rbp,%r14,1)
	incq	%r14
	jmp	.Lpw_fill
.Lpw_fill_done:

	movq	%r15, %rdi
	movq	(%rsp), %r8		/* restore is_first */
	testq	%r8, %r8
	jz	.Lpw_append
	movl	$577, %esi		/* O_CREAT|O_TRUNC|O_WRONLY */
	jmp	.Lpw_open
.Lpw_append:
	movl	$1089, %esi		/* O_CREAT|O_APPEND|O_WRONLY */
.Lpw_open:
	movl	$420, %edx
	movl	$2, %eax
	syscall
	cmpq	$0, %rax
	js	.Lpw_unmap_fail
	movl	%eax, %r12d		/* fd */

	movl	%r12d, %edi
	movq	%rbp, %rsi
	movq	%r13, %rdx
	movl	$1, %eax
	syscall
	cmpq	%r13, %rax
	jne	.Lpw_close_unmap_fail

	movl	%r12d, %edi
	movl	$3, %eax
	syscall

	movq	%rbp, %rdi
	movq	%r13, %rsi
	movl	$11, %eax
	syscall

	xorl	%eax, %eax
	jmp	.Lpw_done

.Lpw_close_unmap_fail:
	movl	%r12d, %edi
	movl	$3, %eax
	syscall
.Lpw_unmap_fail:
	movq	%rbp, %rdi
	movq	%r13, %rsi
	movl	$11, %eax
	syscall
.Lpw_fail:
	movl	$1, %eax
.Lpw_done:
	addq	$8, %rsp		/* drop saved is_first */
	popq	%r15
	popq	%r14
	popq	%r13
	popq	%r12
	popq	%rbp
	popq	%rbx
	/* no RET */
.size	pure_write_elf_chunk_impl, .-pure_write_elf_chunk_impl
