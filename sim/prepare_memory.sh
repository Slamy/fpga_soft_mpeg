set -e

# Download if not yet existing
wget -nc https://download.blender.org/peach/bigbuckbunny_movies/big_buck_bunny_1080p_h264.mov

# Cut a small piece from the video
ffmpeg -y -i "big_buck_bunny_1080p_h264.mov" -r 25 -vf "scale=384:256" \
    -ss 00:04:30.33 -t 5.5 -b:v 1150k -minrate 1150k -maxrate 1150k -bufsize 224k -an fmv.mpg

# Convert to Verilog hex format
xxd -p -c4 fmv.mpg fmv.mem
