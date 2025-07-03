# fpga_soft_mpeg

## Project Goal

This projects intends to create a MPEG1 capable decoder for video and audio for FPGAs.
Compared to other solutions, a hybrid of soft core and hardware acceleration is used.

Multiple soft cores, based on the RISC V architecture, are available for evaluation:
* PicoRV32
* VexiiRiscv (with TileLink and Wishbone bus)

This project also tried to use FFmpeg but eventually, [pl_mpeg](https://github.com/phoboslab/pl_mpeg) was chosen instead, because of its clean code base.

This project aims to decode MPEG1 audio with a 30 MHz clock rate, to make it working with the MiSTer CD-i core and no clock domain crossing. The original MPEG1 audio decoder of this machine also only had this clock rate available.

## Simulation

After some evaluation, it turns out that VexiiRiscv with TileLink is the most efficient solution.

    cd sim
    ./prepare_memory.sh
    ./sim_top vexii

Watch the simulation run and play the music back by doing this

    ./create_wav.sh && mplayer audio.wav

## How to access the waveform view

Uncomment this line in [sim_top.cpp](sim/sim_top.cpp)

    //#define TRACE

## How to verify the results of the hardware vector unit

Uncomment this line in [main.c](sw/main.c). It will make the calculations slower, since vector multiplications are performed in software and in hardware and then compared with each other.

    //#define SOFT_CONVOLVE


