#include <stdint.h>
#include <stdio.h>
#include <stddef.h>
#include <stdlib.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <errno.h>
#include <assert.h>
#include <unistd.h>

int number_samples_bytes = 0;
int number_samples = 0;

void print_str(const char *p)
{
	
}

#include "FFmpeg/libavcodec/mpegaudio.h"
#include "FFmpeg/libavcodec/mpegaudiodec_fixed.c"

char fma_bin[87552];
char cd_sector[2304];

int data_size;

MPADecodeContext s;
AVCodecContext avctx;

OUT_INT samples_l[4000];
OUT_INT samples_r[4000];

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
		printf("Invalid1!\n");
		return AVERROR_INVALIDDATA;
	}
	else if (ret == 1)
	{
		/* free format: prepare to compute frame size */
		printf("Invalid2!\n");
		s.frame_size = -1;
		return AVERROR_INVALIDDATA;
	}
	/* update codec info */
	if (s.frame_size <= 0)
	{
		printf("Invalid3!\n");
		return AVERROR_INVALIDDATA;
	}
	else if (s.frame_size < buf_size)
	{
		buf_size = s.frame_size;
	}

#if 1
	if (s.layer != 2)
	{
		printf("Unexpected!\n");
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

int ASSERT(int v)
{
	if (!v)
	{
		fprintf(stderr, "Error!\n");
		exit(1);
	}
}
int main(void)
{
	const char *path = "../sim/fma.bin";
	memset(&s, 0, sizeof(s));
	memset(&avctx, 0, sizeof(avctx));

	avctx.priv_data = &s;
	decode_init(&avctx);

	FILE *file = fopen(path, "rb");
	assert(file);

	// Search for next MPEG Audio header
	uint32_t state = 0;

	FILE *outfile_l = fopen("samples_l.bin", "wb");
	assert(outfile_l);
	FILE *outfile_r = fopen("samples_r.bin", "wb");
	assert(outfile_r);
	FILE *outfile_elem = fopen("../sim/fma_elem.bin", "wb");
	assert(outfile_elem);

	// filter out the pack headers

	// whole cd sector for audio is 2304 or 0x900
	// Every sector starts with a pack header of 12 bytes?

	int read_size;
	data_size = 0;
	while ((read_size = fread(cd_sector, 1, sizeof(cd_sector), file)) == sizeof(cd_sector))
	{
		// const int pack_header_size = 12;
		// const int pes_header_size = 6;

		// dump_buffer(12 + 6, cd_sector);
		const uint8_t *buf = cd_sector;

		int pes_packet_length = 0;

		for (int i = 0; i < 2000; i++)
		{
			state = (state << 8) + *buf;
			buf++;

			if (state == 0x000001c0)
			{
				state = 0;
				state = (state << 8) + *buf;
				buf++;
				state = (state << 8) + *buf;
				buf++;

				pes_packet_length = state;
				//printf("Got %d bytes following at %d!\n", pes_packet_length, i);
				break;
			}
		}

		if (pes_packet_length > 0)
		{

			// Detect stuffing bytes
			while (*buf == 0xff)
			{
				pes_packet_length--;
				buf++;
			}

			// Check for 01xx
			if ((*buf & 0xC0) == 0x40)
			{
				// STD buffer size
				printf("STD!\n");
				pes_packet_length--;
				buf++;
			}

			if ((*buf & 0xf0) == 0x20)
			{
				// PTS or DTS
				pes_packet_length-=5;
				buf+=5;
			}
			else if (*buf == 0x0F)
			{
				// STD buffer size
				pes_packet_length--;
				buf++;
			}
			else
			{
				printf("Unexpected %x!\n",*buf);
				exit(1);
			}

			// printf("Got %d bytes\n", read_size);
			memcpy(&fma_bin[data_size], buf, pes_packet_length);
			fwrite(buf, 1, pes_packet_length, outfile_elem);

			// dump_buffer(pes_packet_length, buf);
			data_size += pes_packet_length;
		}
	}

	const uint8_t *buf = fma_bin;
	int buf_size = data_size;

	while (buf_size > 100)
	{
		state = (state << 8) + *buf;

		buf++;
		buf_size--;
		// printf("State %x\n", state);

		if (ff_mpa_check_header(state) == 0)
		{
			//printf("Found potentional header %x\n", state);

			number_samples_bytes = 0;
			try_parse(buf - 4, buf_size + 4);

			if (number_samples_bytes > 0)
			{
				buf += 100;
				buf_size -= 100;
			}
			//printf("samples %d\n",number_samples);

			fwrite(samples_l, 1, number_samples_bytes, outfile_l);
			fwrite(samples_r, 1, number_samples_bytes, outfile_r);
		}
	}

	fclose(outfile_l);
	fclose(outfile_r);
	fclose(outfile_elem);

	return 0;
}

// ./build_pctest.sh  && ./a.out  && ./create_wav.sh && mplayer audio.wav

/*
./build_pctest.sh  && ./a.out  && md5sum samples_*
0c1a71fcb5cac537587395af96e2ee09  samples_l.bin
2d47ebd4f5177fe566a9b609511f29d5  samples_r.bin
*/