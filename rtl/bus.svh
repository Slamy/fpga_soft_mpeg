`ifndef BUS_SVH
`define BUS_SVH

interface ddr_if;
    bit        acquire;

    bit [28:0] addr;
    bit [63:0] wdata;
    bit [63:0] rdata;
    bit        read;
    bit        write;
    bit [ 7:0] burstcnt;
    bit [ 7:0] byteenable;
    bit        busy;
    bit        rdata_ready;

    modport to_host(
        output addr, wdata, read, write, burstcnt, byteenable, acquire,
        input rdata, busy, rdata_ready
    );

    modport from_host(
        output rdata, busy, rdata_ready,
        input addr, wdata, read, write, burstcnt, byteenable, acquire
    );
endinterface

typedef struct {
    bit [7:0] r;
    bit [7:0] g;
    bit [7:0] b;
} rgb888_s;

`endif
