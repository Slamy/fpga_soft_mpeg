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

The md5sum of the Big Buck Bunny result files are expected as

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

The md5sum of Dragon's Lair the result files are expected as

    ad796437682f2c6a832864c239e10cff  000000.bmp
    2b06aca876c6938a99062cdeb7fe0754  000001.bmp
    fd7519cbd2cd5bb4e1a9cc54d55ea1ad  000002.bmp
    ce5c7d5ce0aac4be0e421f7d6b092543  000003.bmp
    0cf0e3158a156bb2594a09daa6e46f1f  000004.bmp
    8c75029d65d7d2e5b7c64364521cf891  000005.bmp
    0e7d85ecec54eb50d9dde2f7e4273f22  000006.bmp
    d4762cd875dbf69994a8883226498028  000007.bmp
    cc1b8d8c9a605bfe209affddce13d668  000008.bmp
    ce868ca5f124ebebe3fc5966544abdc9  000009.bmp
    36fe04bc437bedc1ce56cf3c9fb57364  000010.bmp
    627241548783b9a9b93d55389c43e94e  000011.bmp
    ed0ac3608f25c629bfbfce4d804c8d97  000012.bmp
    9e68a5e0a3ba06e9a52b703ca4250bb6  000013.bmp
    e42f44a6fc57991315dca8e6686b25f7  000014.bmp
    54e1e0ae2abac5ce07f37f691151dc44  000015.bmp
    4d3e74cd58b7138d1a5ce1ec16017468  000016.bmp
    7ebe40031898d76d2a349fb1a5131e71  000017.bmp
    b62d0c9edeefa0d3fa53c8fde4c9b1a4  000018.bmp
    76293c56b8731da67bf2d3ecd92d9033  000019.bmp
    272f1f72c6fceda3c4f949f2ed957506  000020.bmp
    77b118f1ce7b7ac96470c48adb607190  000021.bmp
    c474bb85669ba8cbc91843ab7427a527  000022.bmp
    548d0257df625360eb648767395b004b  000023.bmp
    a16b194a91cb11ce10850ab9a25fc7bd  000024.bmp
    092188ad4537565f5f2259c9dce40d8b  000025.bmp
    5ecaa29430fa7ebba656d59e96d327a4  000026.bmp
    e2d994b2b751eae7f3ee7393b352ac5c  000027.bmp
    e6c3383304899a3c97b180f6b59152e0  000028.bmp
    71a26e16397b2475c8e0f2b91b8089a0  000029.bmp
    76949801d9403c55f38d00e90f46851d  000030.bmp
    40e3320ba1314cd9fab1298b091bd22c  000031.bmp
    d0d34e4ff8a1c519bfb6556e47ec105d  000032.bmp
    06e83b0dbf07bb15a61fa18cf05c8f78  000033.bmp
    ed6c39ff0b17d352ddc9b88c96c922e9  000034.bmp
    80247ee649f0be7cefbd05b7a90e0873  000035.bmp
    9bd94c3a825a88254f7599380b6e6927  000036.bmp
    0a84440b95e0e9d48be315d1cbd5d8d2  000037.bmp
    801cb9a1f521dfa4f2c195a60af4fb95  000038.bmp
    fde2de8645d53e33a1fa45e5fd3f398a  000039.bmp
    2cb91796c4749b49b5688969f763000f  000040.bmp
    2788c439a29aaa3ee01e538b3019162b  000041.bmp
    876ee9674fc82e6047e1dacf3a5c875f  000042.bmp
    ea030aeb4d74bf99d694f814a0032e7e  000043.bmp
    9a5eba60e2c3f819f891a9e0a3823e77  000044.bmp
    97fcf28a1de7d42aa1e5a297df4c521e  000045.bmp
    7c3734d33f9b521672bb3ad10dcb6936  000046.bmp
    c8b010cea5c5e4e3a194fde46d5211e2  000047.bmp
    0f8b77dc26ecb40e0b38912c34963656  000048.bmp
    1eef2689d75c8c33a1a6431f25c3e586  000049.bmp
    040ce7b106071aa150d203fae6c26a8d  000050.bmp
    aa2fa1d383224e96204d99563ccee662  000051.bmp
    33adc7bd0d9478b406e09cddf71e138b  000052.bmp
    cf761d3f819b4b159094b539670d61cd  000053.bmp

### Benchmarks

    Debug out 88888888  Waterlevel:           17 Frames decoded:         136  Frames shown:         118  Load:          86 %

Utilization of cores in cycles and percent.

    Core 1
     0            6099   0
     2           15103   0
     3            1932   0
     4            3478   0
     5           19458   0
     6         6282584   4
     7            4002   0
     8        15644282  10
     9             690   0
    12         4550726   3
    14         1505665   1
    15            2192   0
    16         7721652   5
    17         7558723   5
    20         9863411   6
    26        19424015  13
    27         2358046   1
    28            3709   0
    31        42157547  28
    32        29531584  20
    Core 2
     0             125   0
    10        43728538  29
    11        35609904  24
    33         3485816   2
    34        28971450  19
    35        33412579  22
    36         1446486   0
    Core 3
     0             125   0
    10        43654324  29
    11        35527229  24
    33         3522167   2
    34        28627359  19
    35        33883209  23
    36         1440485   0