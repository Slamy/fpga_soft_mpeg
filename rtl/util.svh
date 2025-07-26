
function [31:0] reverse_endian_32;
    input [31:0] data_in;
    begin
        reverse_endian_32 = {data_in[7:0], data_in[15:8], data_in[23:16], data_in[31:24]};
    end
endfunction

interface wordstream ();
    bit write;
    bit [15:0] data;

    modport source(output write, data);
    modport sink(input write, data);
endinterface

interface audiostream ();
    bit write;
    bit strobe;
    bit signed [15:0] sample;

    modport source(output write, sample, input strobe);
    modport sink(input write, sample, output strobe);
endinterface

