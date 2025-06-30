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
#include "pl_mpeg/pl_mpeg.h"

int main(void)
{
	const char *path = "../sim/fma.bin";
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
	//plm_audio_t *mpeg_audio = plm_audio_create_with_buffer(buffer, 0);
	//assert(mpeg_audio);
#else
	plm_t *mpeg = plm_create_with_filename(path);

#endif
	FILE *outfile = fopen("samples.bin", "wb");

	for (;;)
	{

#if 0
		plm_samples_t *samples = plm_audio_decode(mpeg_audio);
#else
		plm_samples_t *samples = plm_decode_audio(mpeg);
#endif
		if (samples)
		{
			fwrite(samples->interleaved, sizeof(int16_t), samples->count * 2, outfile);
			// printf("Samples %d\n", samples->count);
		}
		else
		{
			printf("Underflow!\n");
			break;
		}
	}
	// aplay -f float_le samples.bin  -r 44100 -c2
	// g++ -g pctest.cpp  && ./a.out
	// g++ -g pctest.cpp  && ./a.out && aplay -f cd samples.bin
	fclose(outfile);

	return 0;
}
