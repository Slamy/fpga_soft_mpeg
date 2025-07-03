// This is free and unencumbered software released into the public domain.
//
// Anyone is free to copy, modify, publish, use, compile, sell, or
// distribute this software, either in source code form or as a compiled
// binary, for any purpose, commercial or non-commercial, and by any
// means.

#include <stdint.h>
#include <stddef.h>

#include <sys/types.h>
#include <sys/stat.h>
#include <errno.h>

struct synth_window_mac
{
	uint32_t *addr;
	uint32_t index;
	uint32_t result;
	uint32_t busy;
};

volatile struct synth_window_mac *synth_window_mac = (volatile struct synth_window_mac *)0x30000000;

#define OUTPORT 0x10000000
#define OUTPORT_L 0x10000004
#define OUTPORT_R 0x10000008
#define OUTPORT_END 0x1000000c

#define OUT_L 0x10000010
#define OUT_R 0x10000020
#define OUT_DEBUG *(volatile uint32_t *)0x10000030

extern caddr_t _end; /* _end is set in the linker command file */
/* just in case, most boards have at least some memory */
#ifndef RAMSIZE
#define RAMSIZE (caddr_t)0x100000
#endif

void print_chr(char ch);
void print_str(const char *p);

// #define SOFT_CONVOLVE
#define PL_MPEG_IMPLEMENTATION
#define PLM_NO_STDIO
#include "pl_mpeg.h"

void print_chr(char ch)
{
	*((volatile uint8_t *)OUTPORT) = ch;
}

void print_str(const char *p)
{
	while (*p != 0)
		*((volatile uint8_t *)OUTPORT) = *(p++);
}

void test_vector_unit()
{
	synth_window_mac->result = 0;
	synth_window_mac->addr = 0;
	synth_window_mac->index = 1;
	// while (synth_window_mac->busy);

	synth_window_mac->result = 0;
	synth_window_mac->addr = 0;
	synth_window_mac->index = 1;
	// while (synth_window_mac->busy);

	*((volatile intsample_t *)OUTPORT) = synth_window_mac->result;
}

void main(void)
{
	// test_vector_unit();
	//*((volatile uint8_t *)OUTPORT_END) = 0;
	// for(;;);
	print_str("Hello world\n");

	plm_buffer_t *buffer = plm_buffer_create_with_memory((uint8_t *)0x20000000, 87552, 0);
	plm_t *mpeg = plm_create_with_buffer(buffer, 0);

	int cnt = 0;

	for (;;)
	{
		plm_samples_t *samples = plm_decode_audio(mpeg);

		if (samples)
		{
			// Give some feedback to the user that we are running
			*((volatile uint8_t *)OUTPORT) = cnt;
			cnt++;
		}
		else
		{
			// End simulation since the MPEG stream has ended
			*((volatile uint8_t *)OUTPORT_END) = 0;
		}
	}
}

uint32_t *irq(uint32_t *regs, uint32_t irqs)
{
}

/*
 * sbrk -- changes heap size size. Get nbytes more
 *         RAM. We just increment a pointer in what's
 *         left of memory on the board.
 */
caddr_t _sbrk(int nbytes)
{
	static caddr_t heap_ptr = NULL;
	caddr_t base;

	if (heap_ptr == NULL)
	{
		heap_ptr = (caddr_t)&_end;
	}

	if ((RAMSIZE - heap_ptr) >= 0)
	{
		base = heap_ptr;
		heap_ptr += nbytes;
		return (base);
	}
	else
	{
		errno = ENOMEM;
		return ((caddr_t)-1);
	}
}
