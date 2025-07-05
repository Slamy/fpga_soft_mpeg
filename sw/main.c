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


void print_chr(char ch);
void print_str(const char *p);
void stop_verilator();

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

void stop_verilator()
{
	print_str("Nope\n");

	*((volatile uint8_t *)OUTPORT_END) = 0;
}


void main(void)
{
	// test_vector_unit();
	// stop_verilator();
	//  for(;;);

	plm_buffer_t *buffer = plm_buffer_create_with_memory((uint8_t *)0x20000000, 202752 * 4, 0);
	plm_t *mpeg = plm_create_with_buffer(buffer, 0);

	int cnt = 0;

	for (;;)
	{
		plm_frame_t *frame = plm_decode_video(mpeg);

		if (frame)
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

