	.file	"GCD.c"
	.option nopic
	.attribute arch, "rv32i2p1_m2p0"
	.attribute unaligned_access, 0
	.attribute stack_align, 16
	.text
	.globl	a
	.section	.sdata,"aw"
	.align	2
	.type	a, @object
	.size	a, 4
a:
	.word	54
	.globl	b
	.align	2
	.type	b, @object
	.size	b, 4
b:
	.word	48
	.text
	.align	2
	.globl	gcd
	.type	gcd, @function
gcd:
	addi	sp,sp,-48
	sw	ra,44(sp)
	sw	s0,40(sp)
	addi	s0,sp,48
	sw	a0,-36(s0)
	sw	a1,-40(s0)
	j	.L2
.L3:
	lw	a4,-36(s0)
	lw	a5,-40(s0)
	rem	a5,a4,a5
	sw	a5,-20(s0)
	lw	a5,-40(s0)
	sw	a5,-36(s0)
	lw	a5,-20(s0)
	sw	a5,-40(s0)
.L2:
	lw	a5,-40(s0)
	bne	a5,zero,.L3
	lw	a5,-36(s0)
	mv	a0,a5
	lw	ra,44(sp)
	lw	s0,40(sp)
	addi	sp,sp,48
	jr	ra
	.size	gcd, .-gcd
	.section	.rodata
	.align	2
.LC0:
	.string	"GCD of %d and %d is %d\n"
	.text
	.align	2
	.globl	main
	.type	main, @function
main:
	addi	sp,sp,-32
	sw	ra,28(sp)
	sw	s0,24(sp)
	addi	s0,sp,32
	lui	a5,%hi(a)
	lw	a4,%lo(a)(a5)
	lui	a5,%hi(b)
	lw	a5,%lo(b)(a5)
	mv	a1,a5
	mv	a0,a4
	call	gcd
	sw	a0,-20(s0)
	lui	a5,%hi(a)
	lw	a4,%lo(a)(a5)
	lui	a5,%hi(b)
	lw	a5,%lo(b)(a5)
	lw	a3,-20(s0)
	mv	a2,a5
	mv	a1,a4
	lui	a5,%hi(.LC0)
	addi	a0,a5,%lo(.LC0)
	call	printf
	li	a5,0
	mv	a0,a5
	lw	ra,28(sp)
	lw	s0,24(sp)
	addi	sp,sp,32
	jr	ra
	.size	main, .-main
	.ident	"GCC: (g04696df09) 14.2.0"
	.section	.note.GNU-stack,"",@progbits
