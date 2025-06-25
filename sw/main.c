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

#define OUTPORT 0x10000000
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

void print_chr(char ch)
{
	*((volatile uint8_t *)OUTPORT) = ch;
}

void print_str(const char *p)
{
	while (*p != 0)
		*((volatile uint8_t *)OUTPORT) = *(p++);
}

int number_samples_bytes = 0;
int number_samples = 0;

#include "FFmpeg/libavcodec/mpegaudio.h"
#include "FFmpeg/libavcodec/mpegaudiodec_fixed.c"

int data_size;

MPADecodeContext s;
AVCodecContext avctx;

OUT_INT samples_l[1152];
OUT_INT samples_r[1152];

OUT_INT *samples[] = {samples_l, samples_r};

int mp_decode_frame(MPADecodeContext *s, OUT_INT **samples,
					const uint8_t *buf, int buf_size);

int try_parse(const uint8_t *buf, int buf_size)
{

	uint32_t header;
	int ret;

	int skipped = 0;

	if (buf_size < HEADER_SIZE)
		return AVERROR_INVALIDDATA;

	header = AV_RB32(buf);
	if (header >> 8 == AV_RB32("TAG") >> 8)
	{
		return buf_size + skipped;
	}
	ret = avpriv_mpegaudio_decode_header((MPADecodeHeader *)&s, header);
	if (ret < 0)
	{
		print_str("Invalid1!\n");
		return AVERROR_INVALIDDATA;
	}
	else if (ret == 1)
	{
		/* free format: prepare to compute frame size */
		print_str("Invalid2!\n");
		s.frame_size = -1;
		return AVERROR_INVALIDDATA;
	}
	/* update codec info */
	if (s.frame_size <= 0)
	{
		print_str("Invalid3!\n");
		return AVERROR_INVALIDDATA;
	}
	else if (s.frame_size < buf_size)
	{
		buf_size = s.frame_size;
	}

#if 1
	if (s.layer != 2)
	{
		print_str("Unexpected!\n");
		return AVERROR_INVALIDDATA;
	}
#endif

	ret = mp_decode_frame(&s, samples, buf, buf_size);
	if (ret >= 0)
	{
		avctx.sample_rate = s.sample_rate;
		// FIXME maybe move the other codec info stuff from above here too
	}
	else
	{
	}
	s.frame_size = 0;
	return buf_size + skipped;
}

void main(void)
{
	const uint8_t *buf = (uint8_t *)0x20000000;
	int buf_size = 84324;

	avctx.priv_data = &s;
	print_str("Howdy\n");
	decode_init(&avctx);
	print_str("Ho\n");

	uint32_t state = 0;

	while (buf_size > 100)
	{
		state = (state << 8) + *buf;

		buf++;
		buf_size--;

		if (ff_mpa_check_header(state) == 0)
		{
			//print_str("Found potentional header\n");

			number_samples_bytes = 0;
			number_samples = 0;
			try_parse(buf - 4, buf_size + 4);

			buf += 100;
			buf_size -= 100;

			for (int i = 0; i < number_samples; i++)
			{
				*(volatile uint32_t *)OUT_L = samples_l[i];
				*(volatile uint32_t *)OUT_R = samples_r[i];
			}
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

	print_str("Heap!\n");

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
