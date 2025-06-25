# SoftMPEG

An experiment about decoding MPEG Audio on a FPGA using a RISC V soft core by using a reduced version of the FFmpeg avcodec library.

It makes use of the picorv32 RISC V soft core and would require about 100 MHz to decode an MPEG1 stream in realtime.

    cd sim
    ./prepare_memory.sh
    ./sim_top

Watch the simulation run and play the music back by doing this

    ./create_wav.sh && mplayer audio.wav

## Testing on PC

The algorithm can also be executed on PC like so

    cd sw
    ./build_pctest.sh && ./a.out && ./create_wav.sh && mplayer audio.wav
