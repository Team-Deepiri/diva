/* Pure ELF int_vec_free — handle is table index; clears slot + munmap. NO ret. */
.equ HT_BASE, 0x500000000000
.equ HT_MAX, 65535

.section .note.GNU-stack,"",@progbits
.text
.globl pure_int_vec_free
.type pure_int_vec_free, @function
pure_int_vec_free:
	testq	%rdi, %rdi
	je	.Ldone
	cmpq	$HT_MAX, %rdi
	ja	.Ldone
	movabs	$HT_BASE, %rax
	movq	(%rax,%rdi,8), %rcx		/* object */
	testq	%rcx, %rcx
	je	.Ldone
	movq	$0, (%rax,%rdi,8)		/* clear slot */
	movq	16(%rcx), %rsi			/* map_bytes */
	movq	%rcx, %rdi
	movl	$11, %eax
	syscall
.Ldone:
	nop
.size pure_int_vec_free, .-pure_int_vec_free
