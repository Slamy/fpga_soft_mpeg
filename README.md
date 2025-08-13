# fpga_soft_mpeg

## Project Goal

This project intends to create a MPEG1 capable decoder for video and audio for FPGAs.
A hybrid of software, running on a soft core, and hardware acceleration of math intensive tasks is used.

Multiple soft cores, based on the RISC V architecture, are available for evaluation:
* PicoRV32
* VexiiRiscv (with TileLink and Wishbone bus)

Both cores are configured to implemented the rv32imc instruction set.
A FPU is absent, but the multiply unit and the compressed instruction set are utilized.

This project has tried to use FFmpeg but eventually, [pl_mpeg](https://github.com/phoboslab/pl_mpeg)
was chosen instead, because of its clean code base.

This project aims to decode MPEG1 audio with a 30 MHz clock rate, to make it
usable with the MiSTer CD-i core without clock domain crossing.
Note: The original MPEG1 audio decoder of the CD-i also had only this clock rate available.

## Status

Currently, only audio is supported.

## Prerequisites

It might be required to compile a GNU toolchain with a suitable architecture

    git clone https://github.com/riscv/riscv-gnu-toolchain
    cd riscv-gnu-toolchain
    ./configure --with-arch=rv32imc --prefix=/opt/riscv
    make -j$(nproc)

The revision b8ca156d2ab0038c6af4569c52f9ec30d95342f0 was tested and confirmed working with this project.

## Simulation

Verilator is used as simulation tool.

But first, we need some example data to work with. To avoid any legal issues, public domain files are used.
Execute this to generate the test data:

    cd sim
    ./prepare_memory.sh

Now execute one of these commands to simulate the model using one of the available soft cores:

    ./sim_top.sh vexii
    ./sim_top.sh vexiiwb
    ./sim_top.sh picorv32

The simulation will run until the MPEG stream has ended. You can hear the result by doing this.

    ./create_wav.sh && mplayer audio.wav

## How to enable tracing using gtkwave?

For performance reasons, the trace is not created per default.
Uncomment this line in [sim_top.cpp](sim/sim_top.cpp)

    //#define TRACE

## How to verify the results of the hardware vector unit

Uncomment this line in [main.c](sw/main.c). It will make the calculations slower,
since vector multiplications are performed in software and in hardware and then compared with each other
to ensure that the hardware calculated results are correct.

    //#define SOFT_CONVOLVE

## Results

To ensure the correctly decoded result, we need to be sure about the input data too.
Please use this [ffmpeg version](https://github.com/BtbN/FFmpeg-Builds/releases/tag/autobuild-2025-08-12-14-12),
in case `fmv.m1v` is not as expected.

    c23ab2ff12023c684f46fcc02c57b585  big_buck_bunny_1080p_h264.mov
    e715e20b9e12f6be1f28c1ad71043243  fmv.m1v

The md5sum of the result files are expected as

    b67bb1b9852c4a398c4421da4d8a71e1  000000.bmp
    561299ffd4fb6366772390860f1e892e  000001.bmp
    eaebbd50bdb6f6fe8914f2d7891f4f31  000002.bmp
    3c52b42a3d0f94518db8594b7dce94da  000003.bmp
    207ac20bf6553c3759a82a8b98d5501e  000004.bmp
    24a263500fbf12dcab595e22fd9c3c2e  000005.bmp
    65922aab80ce4aeb99488884cd493ee1  000006.bmp
    96da9d17172fdf1e6ed2eced532e9549  000007.bmp
    dd5a1ad976a87cf9a1fd8f4cd7f9ffbe  000008.bmp
    0b0210f05a2783e25fe5f173dd808c96  000009.bmp
    f2a58c9f321d4dabf1136997fef50bc7  000010.bmp
    4d09800b9fdbafcb7ec0343d729e3a0b  000011.bmp
    778968d140b981ff7df63b8c661bace0  000012.bmp
    b70cb9fce5001e18b889eca17bac9dd7  000013.bmp
    739fd300937f3dbafe3f832f5fbddbf1  000014.bmp
    40900c362a57494fc285c1954114d61e  000015.bmp
    cee3216cb56e8f54d7f9cc3255ba1e3d  000016.bmp
    8e2ea2f2ef514cbfa857e08bd07d7bd4  000017.bmp
    0a876d4612f4889eac1d0879c63658ff  000018.bmp
    e3fc311735a3b37fdd1e7e78352cd5d4  000019.bmp
    f6602ed56abca594888b95d6d0127e03  000020.bmp

### Benchmarks

    Debug out 88888888  Waterlevel:            2 Frames decoded:         136  Frames shown:         133  Load:          97 %

Utilization of cores in cycles and percent.

    Core 1
     0            6184   0
     2           12689   0
     3            1794   0
     4            3376   0
     5           16638   0
     6         5460684   3
     7            9108   0
     8        34319032  20
     9            2070   0
    12         7403438   4
    14         1753252   1
    15            2329   0
    16         8007822   4
    17         8273834   4
    20         9863411   5
    26        20151393  12
    27          860310   0
    28            6997   0
    31        38435690  23
    32        31082876  18
    Core 2
     0             136   0
    10        43728538  26
    11        35968211  21
    33         3331118   2
    34        29428666  17
    35        52067609  31
    36         1148649   0
    Core 3
     0             136   0
    10        43654324  26
    11        35885924  21
    33         3366237   2
    34        29078883  17
    35        52543374  31
    36         1144049   0

