/* Extra libc hooks for the compiler driver (mkdir -p semantics + atomic-ish text writes).
   Linked alongside bootstrap/runtime-linux-amd64.o — symbols must match codegen_x86.diva.
   Aliases: stdlib names host_* vs di_runtime_* (asm may call either until codegen maps all). */
.section .note.GNU-stack,"",@progbits
.text

.extern di_runtime_argc
.extern di_runtime_argv
.extern di_runtime_getenv
.extern di_runtime_system

.globl host_argc
.type host_argc, @function
host_argc:
	jmp di_runtime_argc

.globl host_argv
.type host_argv, @function
host_argv:
	jmp di_runtime_argv

.globl host_getenv
.type host_getenv, @function
host_getenv:
	jmp di_runtime_getenv

.globl host_system
.type host_system, @function
host_system:
	jmp di_runtime_system

.extern mkdir
.extern chmod
.extern __errno_location
.extern strlen
.extern open
.extern write
.extern close
.extern malloc
.extern free
.extern di_runtime_int_vec_get

.globl di_runtime_mkdir
.type di_runtime_mkdir, @function
/* int di_runtime_mkdir(const char *path); — 0 ok (incl. EEXIST), 1 error */
di_runtime_mkdir:
	movl	$493, %esi	/* 0755 */
	call	mkdir@PLT
	cmpl	$0, %eax
	je	.Lmk_ok
	call	__errno_location@PLT
	cmpl	$17, (%rax)	/* EEXIST */
	je	.Lmk_ok
	movl	$1, %eax
	ret
.Lmk_ok:
	xorl	%eax, %eax
	ret
.size	di_runtime_mkdir, .-di_runtime_mkdir

.globl di_runtime_write_text_file
.type di_runtime_write_text_file, @function
/* int di_runtime_write_text_file(const char *path, const char *data); — 0 ok, 1 error */
di_runtime_write_text_file:
	pushq	%rbx
	pushq	%r12
	pushq	%r13
	pushq	%r14
	movq	%rdi, %rbx	/* path */
	movq	%rsi, %r12	/* data */
	movq	%r12, %rdi
	call	strlen@PLT
	movq	%rax, %r13	/* len */
	movq	%rbx, %rdi
	movl	$577, %esi	/* O_WRONLY|O_CREAT|O_TRUNC */
	movl	$420, %edx	/* 0644 */
	xorl	%eax, %eax
	call	open@PLT
	cmpl	$0, %eax
	js	.Lwt_fail
	movl	%eax, %r14d	/* fd */
	movl	%r14d, %edi
	movq	%r12, %rsi
	movq	%r13, %rdx
	call	write@PLT
	cmpq	%r13, %rax
	jne	.Lwt_fail_close
	movl	%r14d, %edi
	call	close@PLT
	xorl	%eax, %eax
	jmp	.Lwt_done
.Lwt_fail_close:
	movl	%r14d, %edi
	call	close@PLT
.Lwt_fail:
	movl	$1, %eax
.Lwt_done:
	popq	%r14
	popq	%r13
	popq	%r12
	popq	%rbx
	ret
.size	di_runtime_write_text_file, .-di_runtime_write_text_file

.globl di_runtime_unlink
.globl unlink
.type unlink, @function
unlink:
	jmp	di_runtime_unlink
.type di_runtime_unlink, @function
/* int di_runtime_unlink(const char *path); — 0 ok (incl. ENOENT), 1 error
   Must not call unlink@PLT: this file also exports a global "unlink" alias,
   so PLT would resolve to ourselves and recurse forever. Use the syscall. */
di_runtime_unlink:
	movl	$87, %eax		/* __NR_unlink */
	syscall
	cmpq	$-2, %rax		/* -ENOENT → treat as success */
	je	.Lul_ok
	testq	%rax, %rax
	js	.Lul_err
.Lul_ok:
	xorl	%eax, %eax
	ret
.Lul_err:
	movl	$1, %eax
	ret
.size	di_runtime_unlink, .-di_runtime_unlink

.globl di_runtime_chmod_executable
.globl chmod_executable
.type chmod_executable, @function
chmod_executable:
	jmp	di_runtime_chmod_executable
.type di_runtime_chmod_executable, @function
/* int di_runtime_chmod_executable(const char *path); — 0 ok, 1 error; mode 0755 */
di_runtime_chmod_executable:
	movl	$493, %esi	/* 0755 */
	call	chmod@PLT
	cmpl	$0, %eax
	je	.Lch_ok
	movl	$1, %eax
	ret
.Lch_ok:
	xorl	%eax, %eax
	ret
.size	di_runtime_chmod_executable, .-di_runtime_chmod_executable

.globl write_elf_chunk
.type write_elf_chunk, @function
write_elf_chunk:
	jmp	di_runtime_write_elf_chunk

.globl di_runtime_write_elf_chunk
.type di_runtime_write_elf_chunk, @function
/* int di_runtime_write_elf_chunk(const char *path, int handle, int pos, int take, int is_first); */
di_runtime_write_elf_chunk:
	pushq	%rbx
	pushq	%rbp
	pushq	%r12
	pushq	%r13
	pushq	%r14
	pushq	%r15

	movq	%rdi, %r15		/* path */
	movq	%rsi, %rbx		/* handle (opaque pointer; must not truncate to 32-bit) */
	movslq	%edx, %r12		/* pos */
	movslq	%ecx, %r13		/* take */
	movl	%r8d, %r14d		/* is_first */

	movq	%r13, %rdi
	call	malloc@PLT
	testq	%rax, %rax
	je	.Lwec_fail
	movq	%rax, %rbp		/* buf */

	xorq	%rcx, %rcx
.Lwec_fill:
	cmpq	%r13, %rcx
	jge	.Lwec_fill_done
	movq	%rbx, %rdi
	leaq	(%r12,%rcx), %rsi
	pushq	%rcx			/* int_vec_get clobbers rcx (caller-saved) */
	call	di_runtime_int_vec_get@PLT
	popq	%rcx
	movb	%al, (%rbp,%rcx,1)
	incq	%rcx
	jmp	.Lwec_fill
.Lwec_fill_done:

	movq	%r15, %rdi
	testl	%r14d, %r14d
	jz	.Lwec_append
	movl	$577, %esi		/* O_WRONLY|O_CREAT|O_TRUNC */
	jmp	.Lwec_open
.Lwec_append:
	movl	$1089, %esi		/* O_WRONLY|O_CREAT|O_APPEND */
.Lwec_open:
	movl	$420, %edx
	xorl	%eax, %eax
	call	open@PLT
	cmpq	$0, %rax
	js	.Lwec_free_fail
	movl	%eax, %r12d		/* fd */

	movl	%r12d, %edi
	movq	%rbp, %rsi
	movq	%r13, %rdx
	call	write@PLT
	cmpq	%r13, %rax
	jne	.Lwec_close_free_fail

	movl	%r12d, %edi
	call	close@PLT

	movq	%rbp, %rdi
	call	free@PLT

	xorl	%eax, %eax
	jmp	.Lwec_done

.Lwec_close_free_fail:
	movl	%r12d, %edi
	call	close@PLT
.Lwec_free_fail:
	movq	%rbp, %rdi
	call	free@PLT
.Lwec_fail:
	movl	$1, %eax
.Lwec_done:
	popq	%r15
	popq	%r14
	popq	%r13
	popq	%r12
	popq	%rbp
	popq	%rbx
	ret
.size	di_runtime_write_elf_chunk, .-di_runtime_write_elf_chunk
