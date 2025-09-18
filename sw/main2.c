// This is free and unencumbered software released into the public domain.
//
// Anyone is free to copy, modify, publish, use, compile, sell, or
// distribute this software, either in source code form or as a compiled
// binary, for any purpose, commercial or non-commercial, and by any
// means.

#include <stddef.h>
#include <stdint.h>

#include <errno.h>
#include <sys/stat.h>
#include <sys/types.h>

struct io_fifo_control
{
  uint32_t write_byte_index;
  uint32_t read_bit_index;
  uint32_t hw_read_count;
  uint32_t hw_huffman_read_dct_coeff;
};

struct io_fifo_control *const fifo_ctrl = (struct io_fifo_control *)0x10002000;

#define OUTPORT 0x10000000
#define OUTPORT_END 0x1000000c
#define OUTPORT_FRAME 0x10000010
#define OUTPORT_HANDLE_SHARED 0x10000014
#define OUT_DEBUG *(volatile uint32_t *)0x10000030

#include "memtest.h"
#include "shared.h"

extern caddr_t _end; /* _end is set in the linker command file */
extern caddr_t _sp;  /* _end is set in the linker command file */
/* just in case, most boards have at least some memory */
#ifndef RAMSIZE
#define RAMSIZE (caddr_t)(1024 * 1024 * 4)
#endif

void print_chr(char ch);
void print_str(const char *p);
void stop_verilator();

// #define SOFT_CONVOLVE

#define PL_MPEG_IMPLEMENTATION
#define PLM_NO_STDIO
#include "pl_mpeg.h"

void print_chr(char ch) { *((volatile uint8_t *)OUTPORT) = ch; }

void print_str(const char *p)
{
  while (*p != 0)
    *((volatile uint8_t *)OUTPORT) = *(p++);
}

void stop_verilator()
{
  print_str("Nope\n");
  *((volatile uint8_t *)OUTPORT_END) = 4;
}

void main(void)
{
#if 0
  static uint32_t testword;
  switch (OUT_DEBUG)
  {
  case 0x4218:
    *((volatile uint32_t *)0x50000010) = 0x01000010;
    *((volatile uint32_t *)0x50000014) = 0x01000014;
    *((volatile uint32_t *)0x50000018) = 0x01000018;
    *((volatile uint32_t *)0x5000001c) = 0x0100001c;
    *((volatile uint32_t *)0x50000020) = 0x01000020;
    *((volatile uint32_t *)0x50000024) = 0x01000024;
    *((volatile uint32_t *)0x50000028) = 0x01000028;
    *((volatile uint32_t *)0x5000002c) = 0x0100002c;

    *((volatile uint32_t *)0x50000030) = 0x01000030;
    *((volatile uint32_t *)0x50000034) = 0x01000034;

    *((volatile uint32_t *)0x50000050) = 0x01000050;
    *((volatile uint32_t *)0x50000054) = 0x01000054;

    // Fetch and read two from the same cache address
    // This should be cache entry 0
    *((volatile uint32_t *)OUTPORT) = *((volatile uint32_t *)0x50000010) + *((volatile uint32_t *)0x50000014);
    *((volatile uint32_t *)OUTPORT) = *((volatile uint32_t *)0x50000010) + *((volatile uint32_t *)0x50000014);

    *((volatile uint32_t *)OUTPORT) = *((volatile uint32_t *)0x50000030) + *((volatile uint32_t *)0x50000050);
    *((volatile uint32_t *)OUTPORT) = *((volatile uint32_t *)0x50000030) + *((volatile uint32_t *)0x50000050);

#if 0
    // Fetch and read two from the same cache address
    // This should be cache entry 1
    *((volatile uint32_t *)OUTPORT) = *((volatile uint32_t *)0x50000030) + *((volatile uint32_t *)0x50000034);
    *((volatile uint32_t *)OUTPORT) = *((volatile uint32_t *)0x50000030) + *((volatile uint32_t *)0x50000034);


    *((volatile uint32_t *)OUTPORT) = *((volatile uint32_t *)0x50000050) + *((volatile uint32_t *)0x50000054);
    *((volatile uint32_t *)OUTPORT) = *((volatile uint32_t *)0x50000050) + *((volatile uint32_t *)0x50000054);
#endif

/*
    *((volatile uint32_t *)OUTPORT) = *((volatile uint32_t *)0x50000014);
    *((volatile uint32_t *)OUTPORT) = *((volatile uint32_t *)0x50000018);
    *((volatile uint32_t *)OUTPORT) = *((volatile uint32_t *)0x5000001c);
    *((volatile uint32_t *)OUTPORT) = *((volatile uint32_t *)0x50000020);
    *((volatile uint32_t *)OUTPORT) = *((volatile uint32_t *)0x50000024);
    *((volatile uint32_t *)OUTPORT) = *((volatile uint32_t *)0x50000028);
    *((volatile uint32_t *)OUTPORT) = *((volatile uint32_t *)0x5000002c);
    */
    *((volatile uint32_t *)OUTPORT_END) = *((volatile uint32_t *)0x50000030);

    break;
  case 0x4212:
    for (;;)
      ;
    break;
  default:
    *((volatile uint8_t *)OUTPORT_END) = 4;
  }
#endif

  for (;;)
  {
    struct image_synthesis_descriptor *desc = get_next_ready_synthesis_desc();

    if (desc->ready == 1)
    {
      uint8_t *d = (uint8_t *)(((uint32_t)desc->cwp.d) + 0x50000000);
      OUT_DEBUG = 33;

      write_pixels(desc->cwp.macroblock_intra, desc->cwp.n,
                   desc->cwp.block_data, desc->cwp.di, d, desc->cwp.dw,
                   desc->cwp.si);
    }
    else if (desc->ready == 2)
    {
      uint8_t *s = (uint8_t *)(((uint32_t)desc->cpm.s) + 0x50000000);
      uint8_t *d = (uint8_t *)(((uint32_t)desc->cpm.d) + 0x50000000);
      OUT_DEBUG = 34;

      macroblock_worker(s, d, desc->cpm.odd_h, desc->cpm.odd_v,
                        desc->cpm.interpolate, desc->cpm.dw, desc->cpm.di,
                        desc->cpm.si, desc->cpm.block_size);
    }
    else if (desc->ready == 3)
    {
      // Do nothing. Just for syncing CPUs

      // force cache invalidation by reading some areas
      *((volatile uint32_t *)OUTPORT) = *((volatile uint32_t *)0x50000000);
      *((volatile uint32_t *)OUTPORT) = *((volatile uint32_t *)0x50000010);
      *((volatile uint32_t *)OUTPORT) = *((volatile uint32_t *)0x50000020);
    }

    __asm volatile("" : : : "memory");
    desc->ready = 0; // give the buffer back
    *((int *)OUTPORT_HANDLE_SHARED) = 1;
    __asm volatile("" : : : "memory");
  }
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
    heap_ptr = (caddr_t)&_sp;
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
