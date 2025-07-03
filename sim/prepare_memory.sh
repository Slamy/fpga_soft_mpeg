set -e

# Download if not yet existing
wget -nc https://freepd.com/music/Arpent.mp3

# Cut out some interesting sounding parts and apply typical green book encoding
ffmpeg -y -i "Arpent.mp3" -ss 00:00:31.80 -t 4.22 -ar 44100 fma.mpg

# Convert to Verilog hex format
xxd -p -c4 fma.mpg fma.mem
