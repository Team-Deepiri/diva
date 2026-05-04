/* Pure-ELF inline host_getenv (id 26): SysV ABI, rdi=name (null-terminated).
 * r15 = initial rsp (argc at [r15], argv..., NULL, envp...).
 * Returns rax = value pointer (past '=') or pointer to empty string.
 * Preserves r15. Saves rbx,r12,r13,r14. */
.section .note.GNU-stack,"",@progbits
.text
.globl pure_host_getenv
.type pure_host_getenv, @function
pure_host_getenv:
	pushq	%rbx
	pushq	%r12
	pushq	%r13
	pushq	%r14
	movq	%rdi, %r12          /* name */
	movq	(%r15), %rbx        /* argc */
	leaq	8(%r15), %rax       /* &argv[0] */
	movq	%rbx, %rcx
1:
	testq	%rcx, %rcx
	je	2f
	addq	$8, %rax
	decq	%rcx
	jmp	1b
2:
	addq	$8, %rax            /* skip argv NULL */
3:
	movq	(%rax), %rsi        /* env line ptr or NULL */
	testq	%rsi, %rsi
	je	6f
	movq	%r12, %rdi
	call	match_key
	testq	%r13, %r13
	jne	4f
	addq	$8, %rax
	jmp	3b
4:
	movq	%r13, %rax
	jmp	9f
6:
	jmp	.Lempty_skip
.Lempty_byte:
	.byte	0
.Lempty_skip:
	leaq	.Lempty_byte(%rip), %rax
9:
	popq	%r14
	popq	%r13
	popq	%r12
	popq	%rbx
	ret
.size pure_host_getenv, .-pure_host_getenv

/* rsi = env "KEY=VAL...", rdi = name (null-term); sets r13 = ptr past '=' or 0 */
.type match_key, @function
match_key:
	xorq	%r13, %r13
	movq	%rsi, %r8           /* walk env line */
.Lmk_loop:
	movzbl	(%r8), %ecx
	cmpb	$61, %cl            /* '=' */
	je	.Lmk_eq
	movzbl	(%rdi), %edx
	testb	%dl, %dl
	je	.Lmk_fail
	cmpb	%dl, %cl
	jne	.Lmk_fail
	incq	%r8
	incq	%rdi
	jmp	.Lmk_loop
.Lmk_eq:
	movzbl	(%rdi), %edx
	testb	%dl, %dl
	jne	.Lmk_fail
	leaq	1(%r8), %r13
	ret
.Lmk_fail:
	ret
