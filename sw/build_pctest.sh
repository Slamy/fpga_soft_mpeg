gcc -g -I FFmpeg -Iinclude/pctest/ \
    \
    FFmpeg/libavcodec/mpegaudio.c \
    FFmpeg/libavcodec/mpegaudiodec_common.c \
    FFmpeg/libavcodec/mpegaudiodata.c \
    \
    FFmpeg/libavcodec/mpegaudiodsp.c \
    FFmpeg/libavcodec/mpegaudiodsp_data.c \
    FFmpeg/libavcodec/mpegaudiodsp_fixed.c \
    FFmpeg/libavcodec/dct32_fixed.c \
    \
    FFmpeg/libavcodec/mpegaudiodecheader.c \
    FFmpeg/libavcodec/mpegaudiotabs.c \
    FFmpeg/libavcodec/vlc.c \
    FFmpeg/libavutil/crc.c \
    pctest.c -lm stub.c

# ./build_pctest.sh && ./a.out && ./create_wav.sh && mplayer audio.wav 
