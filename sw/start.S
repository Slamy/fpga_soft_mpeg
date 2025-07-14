.section .init
.globl _start
.type _start,@function


.globl pass
.type pass,@function

.globl fail
.type fail,@function


_start:
#ifdef USE_GP
.option push
.option norelax
	la gp, __global_pointer$
.option pop
#endif


init:
	la sp, _sp


	call main
mainDone:
pass:
    j mainDone
    nop
fail:
    j fail
    nop


	.globl _init
_init:
    ret

