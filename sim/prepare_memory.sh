set -e

# Download if not yet existing
wget -nc https://download.blender.org/peach/bigbuckbunny_movies/big_buck_bunny_1080p_h264.mov

# Cut a small piece from the video and apply typical green book encoding
ffmpeg -y -i "big_buck_bunny_1080p_h264.mov" -bitexact -threads 1 -r 25 -vf "scale=384:256" \
    -ss 00:04:30.33 -t 5.5 -b:v 1150k -minrate 1150k -maxrate 1150k -bufsize 224k -an fmv.m1v

# Convert to Verilog hex format
md5sum fmv.m1v
xxd -p -c4 fmv.m1v fmv.mem
