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
.extern __errno_location
.extern strlen
.extern open
.extern write
.extern close

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
