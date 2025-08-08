#!/bin/bash

rm *.bmp
set -e

make -C ../sw -j

verilator --top-module top_vexii --Mdir out_vexii \
     --trace --trace-fst --trace-structs --cc --assert --exe --build \
     --build-jobs 8 sim_top.cpp -I../rtl/ \
     ../rtl/top_vexii.sv -CFLAGS "-DVEXII" &&
     ./out_vexii/Vtop_vexii $*

md5sum *.bmp
