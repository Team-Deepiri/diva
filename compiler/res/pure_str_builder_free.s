/* Pure ELF str_builder_free — handle index; clear slot + munmap. NO ret. */
.equ HT_BASE, 0x500000000000
.equ HT_MAX, 65535

.section .note.GNU-stack,"",@progbits
.text
.globl pure_str_builder_free
.type pure_str_builder_free, @function
pure_str_builder_free:
	testq	%rdi, %rdi
	je	.Ldone
	cmpq	$HT_MAX, %rdi
	ja	.Ldone
	movabs	$HT_BASE, %rax
	movq	(%rax,%rdi,8), %rcx
	testq	%rcx, %rcx
	je	.Ldone
	movq	$0, (%rax,%rdi,8)
	movq	16(%rcx), %rsi
	movq	%rcx, %rdi
	movl	$11, %eax
	syscall
.Ldone:
	nop
.size pure_str_builder_free, .-pure_str_builder_free
