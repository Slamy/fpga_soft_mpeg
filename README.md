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
    ./configure --with-arch=rv32imc --prefix=/opt/riscv4
    make -j$(nproc)

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
    6e3e2a1a9cfc1526613649135957b604  fmv.m1v

The md5sum of the result files are expected as

    b67bb1b9852c4a398c4421da4d8a71e1  000000.bmp
    c133cca150ce192cb4c7ab84fc08e5f2  000001.bmp
    d6a6127baa36a3c76e78a8e20a673785  000002.bmp
    60c286f412d1aacec860f859845999d3  000003.bmp
    d42defd97f3309d6131c3d5f3ead4fd9  000004.bmp
    dbeb8d885aa6b30ac728fac6e77fe3c3  000005.bmp
    4bfd5f723b0839aad760f5a74424a52f  000006.bmp
    a8883c94d5243ff1e3b4e3a2906e3cbe  000007.bmp
    b11d6545a70b233706b45411d748157a  000008.bmp
    7213f070a21117a1575fb556077d3716  000009.bmp
    4fee8c20cff8d5d29f7d31d96db91337  000010.bmp
    99bc8d1437bbda60bdf2934a4af8079f  000011.bmp
    90a15172dc61e379e9434dd1f1642991  000012.bmp
    d290f5e879589467ed3dbba455bb09c5  000013.bmp
    c61b6f5b0d210f0c9b890dd1b3aa67fb  000014.bmp
    376419974f425c8f0c6a3dde00546145  000015.bmp
    5cc44b079c1f2d21af773e75bb357e88  000016.bmp
    265e26344119f0a7d134cb096888ddea  000017.bmp
    4e03ddf84d23028043de7331902d232b  000018.bmp
    59eeb6ab57b398ad37d5a446fcd14dbc  000019.bmp
    c0d46aeb006e64e948d907f12d5ef140  000020.bmp

Laptop (somehow different results? Different ffmpeg version maybe?)

    b67bb1b9852c4a398c4421da4d8a71e1  000000.bmp
    869d23413a83b63826ed53a478b5e7e7  000001.bmp
    24c5deef6a16e5b30c551886c3f19a21  000002.bmp
    a185d9be0a0d3bc0dd60b69f55bd4c73  000003.bmp
    8a5f1f2664974df8ebd45d438d045d17  000004.bmp
    416649bf88e6640f6d10025d111c054f  000005.bmp
    08c275f3b44ca5f8fec45284f6e7880a  000006.bmp

### Benchmarks

    Debug out 88888888  Waterlevel:            4 Frames decoded:         136  Frames shown:         131  Load:          96 %

Utilization of cores in cycles and percent.

    Core 1
     0            9993   0
     2           12052   0
     3            1794   0
     4            3384   0
     5           16626   0
     6         5220224   3
     7          143520   0
     8        33267405  20
     9            1932   0
    12         7230289   4
    14         1754208   1
    15            2329   0
    16         8220633   5
    17         7972858   4
    20         9714280   5
    26        20000339  12
    27          705358   0
    28            6585   0
    31        37782382  23
    32        31132159  19
    Core 2
     0             141   0
    10        42686771  26
    11        34534869  21
    33         3443164   2
    34        28060375  17
    35        53261608  32
    36         1211422   0
    Core 3
     0             141   0
    10        42540080  26
    11        34411957  21
    33         3418486   2
    34        27891979  17
    35        53729485  32
    36         1206222   0
    