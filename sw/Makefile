FIRMWARE_OBJS = FFmpeg/libavcodec/mpegaudio.o \
	FFmpeg/libavcodec/mpegaudiodec_common.o \
    FFmpeg/libavcodec/mpegaudiodata.o \
    \
    FFmpeg/libavcodec/mpegaudiodsp.o \
    FFmpeg/libavcodec/mpegaudiodsp_data.o \
    FFmpeg/libavcodec/mpegaudiodsp_fixed.o \
    FFmpeg/libavcodec/dct32_fixed.o \
    \
    FFmpeg/libavcodec/mpegaudiodecheader.o \
    FFmpeg/libavcodec/mpegaudiotabs.o \
    FFmpeg/libavcodec/vlc.o \
	main.o start.o stub2.o

#TOOLCHAIN_PREFIX = /opt/riscv3/bin/riscv32-unknown-elf-
TOOLCHAIN_PREFIX = /opt/riscv/bin/riscv32-unknown-elf-
COMPRESSED_ISA = C
CFLAGS = -Os -mabi=ilp32 -march=rv32im$(subst C,c,$(COMPRESSED_ISA)) \
	-ffreestanding -fdata-sections -ffunction-sections --std=c99 \
	-I FFmpeg -Iinclude/pctest

all: firmware.mem firmware.lst

analyze: firmware.elf
	nm  --print-size --size-sort  firmware.elf 

firmware.mem: firmware.bin
	xxd -p -c4 firmware.bin firmware.mem
	wc firmware.mem

firmware.bin: firmware.elf
	$(TOOLCHAIN_PREFIX)objcopy -O binary $< $@

firmware.elf: $(FIRMWARE_OBJS) sections.lds
	$(TOOLCHAIN_PREFIX)gcc $(CFLAGS) -o $@ \
		-Wl,--gc-sections,--build-id=none,-Bstatic,-T,sections.lds,-Map,firmware.map,--strip-debug \
		$(FIRMWARE_OBJS) $(TEST_OBJS) -lgcc -lm

firmware.lst: firmware.elf
	$(TOOLCHAIN_PREFIX)objdump --disassemble-all firmware.elf > firmware.lst

start.o: start.S
	$(TOOLCHAIN_PREFIX)gcc -c $(CFLAGS) -o $@ $<

%.o: %.c
	$(TOOLCHAIN_PREFIX)gcc -c $(CFLAGS) -o $@ $<

clean:
	rm -f *.o */*.o */*/*.o *.mem *.bin *.map *.elf *.lst
