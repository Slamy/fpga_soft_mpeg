set -e

make -C ../sw

verilator --top-module testbench  \
     --trace --trace-fst --trace-structs --cc --assert --exe --build \
    --build-jobs 8 sim_top.cpp -I../rtl/ -I../rtl/picorv32/  \
    ../rtl/*.sv ../rtl/picorv32/picorv32.v \
    && ./obj_dir/Vtestbench $*

