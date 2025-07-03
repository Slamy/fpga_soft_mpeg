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

The md5sum of the result files are expected as

    79760cffd1c68a6fdf274914e0615345  audio_left.bin
    2b3c0967edf05c3f25052cd4ed69d34c  audio_right.bin

### Benchmarks with vector math acceleration unit

After some evaluation, it turns out that VexiiRiscv with TileLink is the most efficient solution, since only 47% of the clock ticks were
required to keep up with the incoming data stream.
Picorv32 is too slow, even with hardware acceleration.

    Debug out a1a1a1a1  Waterlevel:        98008        98008 Samples decoded:      186624  Samples played:       88889  Load:          47 %   vexii
    Debug out a1a1a1a1  Waterlevel:        61851        61851 Samples decoded:      186624  Samples played:      125047  Load:          67 %   vexiiwb
    Debug out a1a1a1a1  Waterlevel:       -76603       -76603 Samples decoded:      186624  Samples played:      263501  Load:         141 %   picorv32

### Benchmarks using only the soft core

Running pl_mpeg without any modifications, shows how inefficient the RISC V implementations are when it comes to execute Multiply-Accumulate operations.
It might be possible that a RISC V with vector instructions and the correct compiler can fix this problem though.

    Debug out a1a1a1a1  Waterlevel:       -22333       -22333 Samples decoded:      186624  Samples played:      209231  Load:         112 %   vexii
    Debug out a1a1a1a1  Waterlevel:      -125639      -125639 Samples decoded:      186624  Samples played:      312537  Load:         167 %   vexiiwb
    Debug out a1a1a1a1  Waterlevel:      -444427      -444427 Samples decoded:      186624  Samples played:      631325  Load:         338 %   picorv32


