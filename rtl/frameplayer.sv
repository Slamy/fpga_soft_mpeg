`timescale 1 ns / 1 ps
`include "bus.svh"
`include "util.svh"

module frameplayer (
    input clk,
    input clkddr,
    input reset,

    ddr_if.to_host ddrif,

    output rgb888_s vidout,
    input           hsync,
    input           vsync,
    input           hblank,
    input           vblank
);

    assign ddrif.byteenable = 8'hff;
    assign ddrif.write = 0;

    bit [28:0] address_y;
    bit [28:0] address_u;
    bit [28:0] address_v;

    enum bit [1:0] {
        IDLE,
        WAITING,
        SETTLE
    } fetchstate;

    wire y_half_empty;
    wire u_half_empty;
    wire v_half_empty;
    bit luma_fifo_strobe;
    bit chroma_fifo_strobe;

    wire y_valid;
    wire u_valid;
    wire v_valid;

    bit target_y;
    bit target_u;
    bit target_v;

    wire new_line_started = hsync && !hsync_q;

    wire reset_clkddr;
    wire vblank_clkddr;

    bit [7:0] chroma_read_addr;

    bit [10:0] pixelcnt;
    bit hsync_q;
    bit line_alternate;
    bit u_requested;
    bit v_requested;

    always_ff @(posedge clk) begin
        hsync_q <= hsync;

        if (chroma_fifo_strobe) chroma_read_addr <= chroma_read_addr + 1;

        if (hblank) begin
            pixelcnt <= 0;
            chroma_fifo_strobe <= 0;
            luma_fifo_strobe <= 0;
            chroma_read_addr <= 0;
        end else if (y_valid && !vblank && !hblank && pixelcnt < 368 * 4) begin
            pixelcnt <= pixelcnt + 1;
            luma_fifo_strobe <= pixelcnt[1:0] == 3;
            chroma_fifo_strobe <= pixelcnt[2:0] == 7;
        end else begin
            chroma_fifo_strobe <= 0;
            luma_fifo_strobe   <= 0;
        end

        /*
        if (fifo_strobe) pixeldebugcnt <= pixeldebugcnt + 1;
        if (hblank && pixeldebugcnt > 0) begin
            $display("Pixels %d", pixeldebugcnt);
            pixeldebugcnt <= 0;
        end
        */
    end

    bit [4:0] data_burst_cnt;

    // 0011 like the N64 core to force a base of 0x30000000
    localparam bit [3:0] DDR_CORE_BASE = 4'b0011;

    bit [8:0] fake_new_line_start_cnt;
    bit new_line_started_clkddr;

    always_ff @(posedge clkddr) begin
        new_line_started_clkddr <= 0;

        fake_new_line_start_cnt <= fake_new_line_start_cnt + 1;
        if (fake_new_line_start_cnt == 30) new_line_started_clkddr <= 1;

    end
    always_ff @(posedge clkddr) begin



        if (!ddrif.busy) begin
            ddrif.read <= 0;
        end

        if (reset_clkddr || vblank_clkddr) begin
            fetchstate <= IDLE;
            address_y <= 29'h0;
            address_v <= 29'h15900;  // 368*240 = 88320
            address_u <= 29'h1af40;  // 368*240 + 88320/4
            target_y <= 0;
            target_u <= 0;
            target_v <= 0;
            line_alternate <= 0;
            u_requested <= 0;
            v_requested <= 0;
        end else begin
            if (new_line_started_clkddr) begin
                line_alternate <= !line_alternate;

                if (!line_alternate) begin
                    u_requested <= 0;
                    v_requested <= 0;
                end
            end

            case (fetchstate)
                IDLE: begin
                    if (!u_requested) begin
                        u_requested <= 1;
                        ddrif.addr <= {DDR_CORE_BASE, address_u[27:3]};
                        ddrif.read <= 1;
                        ddrif.acquire <= 1;
                        address_u <= address_u + 8 * 184 / 8;
                        ddrif.burstcnt <= 25;
                        data_burst_cnt <= 25;
                        fetchstate <= WAITING;
                        target_u <= 1;
                    end else if (!v_requested) begin
                        v_requested <= 1;
                        ddrif.addr <= {DDR_CORE_BASE, address_v[27:3]};
                        ddrif.read <= 1;
                        ddrif.acquire <= 1;
                        address_v <= address_v + 8 * 184 / 8;
                        ddrif.burstcnt <= 25;
                        data_burst_cnt <= 25;
                        fetchstate <= WAITING;
                        target_v <= 1;
                    end else if (y_half_empty) begin
                        ddrif.addr <= {DDR_CORE_BASE, address_y[27:3]};
                        ddrif.read <= 1;
                        ddrif.acquire <= 1;
                        ddrif.burstcnt <= 2;
                        data_burst_cnt <= 2;
                        address_y <= address_y + 8 * 2;
                        fetchstate <= WAITING;
                        target_y <= 1;
                    end
                end
                WAITING: begin
                    if (ddrif.rdata_ready) begin
                        data_burst_cnt <= data_burst_cnt - 1;
                    end
                    if (data_burst_cnt == 0) begin
                        fetchstate <= IDLE;
                        target_y <= 0;
                        target_u <= 0;
                        target_v <= 0;
                        ddrif.acquire <= 0;
                    end
                end
                default: begin

                end
            endcase

        end
    end


endmodule
