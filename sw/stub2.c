
#include <stdint.h>

#define OUTPORT 0x10000000

static void abortit(int val)
{
    for (;;)
        *((volatile uint8_t *)OUTPORT) = 0x42;
}

void av_log() {}

void av_mallocz() { abortit(1); }
void av_realloc_f() { abortit(1); }
void av_malloc_array() { abortit(1); }
void av_malloc() { abortit(1); }
void av_free() { abortit(1); }
void av_freep() { abortit(1); }
void ff_reverse() { abortit(1); }
void avpriv_request_sample() { abortit(1); }
void ff_get_buffer() { abortit(1); }
void av_channel_layout_uninit() { abortit(1); }
void avpriv_mpeg4audio_get_config2() { abortit(1); }
void av_channel_layout_from_mask() { abortit(1); }
