#include <stdint.h>
#include <stddef.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <errno.h>
#include <assert.h>
#include <iostream>
#include <fstream>
#include <filesystem>

#define PL_MPEG_IMPLEMENTATION
#include "pl_mpeg.h"

int write_bmp(const char *path, int width, int height, uint8_t *pixels)
{
	FILE *fh = fopen(path, "wb");
	if (!fh)
	{
		return 0;
	}

	int padded_width = (width * 3 + 3) & (~3);
	int padding = padded_width - (width * 3);
	int data_size = padded_width * height;
	int file_size = 54 + data_size;

	fwrite("BM", 1, 2, fh);
	fwrite(&file_size, 1, 4, fh);
	fwrite("\x00\x00\x00\x00\x36\x00\x00\x00\x28\x00\x00\x00", 1, 12, fh);
	fwrite(&width, 1, 4, fh);
	fwrite(&height, 1, 4, fh);
	fwrite("\x01\x00\x18\x00\x00\x00\x00\x00", 1, 8, fh); // planes, bpp, compression
	fwrite(&data_size, 1, 4, fh);
	fwrite("\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00", 1, 16, fh);

	for (int y = height - 1; y >= 0; y--)
	{
		fwrite(pixels + y * width * 3, 3, width, fh);
		fwrite("\x00\x00\x00\x00", 1, padding, fh);
	}
	fclose(fh);
	return file_size;
}

int main(void)
{
	const char *path = "../sim/fmv.mpg";
	// const char *path = "/home/andre/GIT/MPEG1_Handbook/bunny.mp2";

#if 1
	std::uintmax_t filesize = std::filesystem::file_size(path);
	// Allocate buffer to hold file
	uint8_t *buf = new uint8_t[filesize];
	// Read file
	std::ifstream fin(path, std::ios::binary);
	fin.read(reinterpret_cast<char *>(buf), filesize);
	if (!fin)
	{
		std::cerr << "Error reading file, could only read " << fin.gcount() << " bytes" << std::endl;
		return 1;
	}

	plm_buffer_t *buffer = plm_buffer_create_with_memory(buf, filesize, 0);
	assert(buffer);
	plm_t *mpeg = plm_create_with_buffer(buffer, 0);
	assert(mpeg);
	// plm_audio_t *mpeg_audio = plm_audio_create_with_buffer(buffer, 0);
	// assert(mpeg_audio);
	plm_set_audio_enabled(mpeg, FALSE);

	int w = plm_get_width(mpeg);
	int h = plm_get_height(mpeg);
	uint8_t *pixels = (uint8_t *)malloc(w * h * 3);

#else
	plm_t *mpeg = plm_create_with_filename(path);

#endif
	FILE *outfile = fopen("samples.bin", "wb");
	char bmp_name[16];
	int cnt = 0;

	for (;;)
	{

		plm_frame_t *frame = plm_decode_video(mpeg);

		if (frame)
		{
			// Give some feedback to the user that we are running
			plm_frame_to_bgr(frame, pixels, w * 3); // BMP expects BGR ordering

			sprintf(bmp_name, "%06d.bmp", cnt);
			printf("Writing %s\n", bmp_name);
			write_bmp(bmp_name, w, h, pixels);
			cnt++;
		}
		else
		{
			// End simulation since the MPEG stream has ended
			break;
		}
	}
	// g++ -g pctest.cpp  && ./a.out
	fclose(outfile);

	return 0;
}
