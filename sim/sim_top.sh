#!/bin/bash

# Check if a parameter was provided
if [ -z "$1" ]; then
     echo "Usage: $0 {vexii|vexiiwb|picorv32}"
     exit 1
fi

set -e

make -C ../sw -j

# Perform action based on the first argument
case "$1" in
vexii)
     verilator --top-module top_vexii --Mdir out_vexii \
          --trace --trace-fst --trace-structs --cc --assert --exe --build \
          --build-jobs 8 sim_top.cpp -I../rtl/ \
          ../rtl/top_vexii.sv -CFLAGS "-DVEXII" &&
          ./out_vexii/Vtop_vexii $*

     ;;
vexiiwb)
     verilator --top-module top_vexii_wb --Mdir out_vexiiwb \
          --trace --trace-fst --trace-structs --cc --assert --exe --build \
          --build-jobs 8 sim_top.cpp -I../rtl/ \
          ../rtl/top_vexii_wb.sv -CFLAGS "-DVEXII_WB" &&
          ./out_vexiiwb/Vtop_vexii_wb $*
     ;;
picorv32)
     verilator --top-module top_picorv32 --Mdir out_picorv32 \
          --trace --trace-fst --trace-structs --cc --assert --exe --build \
          --build-jobs 8 sim_top.cpp -I../rtl/ ../rtl/picorv32/picorv32.v \
          ../rtl/top_picorv32.sv -CFLAGS "-DPICORV32"  &&
          ./out_picorv32/Vtop_picorv32 $*
     ;;
*)
     echo "Invalid option: $1"
     echo "Usage: $0 {vexii|vexiiwb|picorv32}"
     exit 1
     ;;
esac

md5sum audio_*.bin
