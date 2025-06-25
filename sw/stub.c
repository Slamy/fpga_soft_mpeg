#include <stdint.h>
#include <stdio.h>
#include <stddef.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <errno.h>
#include <assert.h>
#include <unistd.h>


void av_log() { exit(1); }
void av_mallocz() { exit(1); }
void av_realloc_f() { exit(1); }
void av_malloc_array() { exit(1); }
void av_malloc() { exit(1); }
void av_free() { exit(1); }
void av_freep() { exit(1); }
void ff_reverse() { exit(1); }
void avpriv_request_sample() { exit(1); }
void ff_get_buffer() { exit(1); }
void av_channel_layout_uninit() { exit(1); }
void avpriv_mpeg4audio_get_config2() { exit(1); }
void av_channel_layout_from_mask() { exit(1); }