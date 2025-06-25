sox -M \
    -r 44100 -e signed-integer -b 16 -c 1 -t raw audio_left.bin \
    -r 44100 -e signed-integer -b 16 -c 1 -t raw audio_right.bin \
    audio.wav