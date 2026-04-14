`default_nettype none

module i4004_demo_rom (
    input  wire [11:0] addr,
    input  wire        mode_sel,
    output reg  [7:0]  data
);
    always @* begin
        data = 8'h00;
        if (!mode_sel) begin
            // Program 0: mirror input nibble to output nibble forever.
            //   000: RDR
            //   001: WRR
            //   002: JUN 000h
            //   003: 00h
            case (addr[7:0])
                8'h00: data = 8'hEA; // RDR
                8'h01: data = 8'hE2; // WRR
                8'h02: data = 8'h40; // JUN 0x000
                8'h03: data = 8'h00;
                default: data = 8'h00;
            endcase
        end else begin
            // Program 1: free-running counter on the output port.
            //   000: CLB
            //   001: WRR
            //   002: IAC
            //   003: WRR
            //   004: JUN 002h
            //   005: 02h
            case (addr[7:0])
                8'h00: data = 8'hF0; // CLB
                8'h01: data = 8'hE2; // WRR
                8'h02: data = 8'hF2; // IAC
                8'h03: data = 8'hE2; // WRR
                8'h04: data = 8'h40; // JUN 0x002
                8'h05: data = 8'h02;
                default: data = 8'h00;
            endcase
        end
    end
endmodule

module tt_um_replace_me_i4004_demo (
    input  wire [7:0] ui_in,   // ui_in[3:0] = 4-bit input port, ui_in[4] = TEST, ui_in[5] = mode select
    output wire [7:0] uo_out,  // uo_out[3:0] = port_out, uo_out[7:4] = accumulator
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);
    wire [11:0] rom_addr;
    wire [7:0]  rom_data;
    wire [3:0]  acc;
    wire        carry;
    wire        zero;
    wire [11:0] pc_dbg;
    wire [7:0]  instr_dbg;
    wire        phase_dbg;
    wire        heartbeat_dbg;
    wire [3:0]  port_out_core;

    i4004_demo_rom rom_i (
        .addr     (rom_addr),
        .mode_sel (ui_in[5]),
        .data     (rom_data)
    );

    i4004_edu_core core_i (
        .clk           (clk),
        .rst_n         (rst_n),
        .en            (1'b1),
        .test_i        (ui_in[4]),
        .port_in       (ui_in[3:0]),
        .port_out      (port_out_core),
        .rom_addr      (rom_addr),
        .rom_data      (rom_data),
        .acc           (acc),
        .carry         (carry),
        .zero          (zero),
        .pc_dbg        (pc_dbg),
        .instr_dbg     (instr_dbg),
        .phase_dbg     (phase_dbg),
        .heartbeat_dbg (heartbeat_dbg)
    );

    assign uo_out[3:0] = port_out_core;
    assign uo_out[7:4] = acc;

    // Debug on bidirectional pins:
    //   uio[3:0] = PC low nibble
    //   uio[4]   = ZERO
    //   uio[5]   = CARRY
    //   uio[6]   = phase (0 opcode / 1 immediate)
    //   uio[7]   = heartbeat
    assign uio_out = {heartbeat_dbg, phase_dbg, carry, zero, pc_dbg[3:0]};
    assign uio_oe  = 8'hFF;

    wire _unused = &{ena, uio_in, ui_in[7:6], instr_dbg[7:0], pc_dbg[11:4], 1'b0};

endmodule

`default_nettype wire
