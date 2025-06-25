sox -M \
    -r 44100 -e signed-integer -b 16 -c 1 -t raw samples_l.bin \
    -r 44100 -e signed-integer -b 16 -c 1 -t raw samples_r.bin \
    audio.wav
