`default_nettype none

// -----------------------------------------------------------------------------
// i4004_edu_core
// -----------------------------------------------------------------------------
// A compact, synthesizable *educational* Intel 4004-style core.
//
// What it is:
//   - 4-bit accumulator + carry
//   - 16 x 4-bit index registers
//   - small internal scratch RAM and 4 status nibbles
//   - 12-bit program counter
//   - 3-level call/return stack (PC + 3 return entries total behavior)
//   - subset of the original 4004 ISA, enough to build demos on Tiny Tapeout
//
// What it is NOT:
//   - not cycle-accurate
//   - not pad/pin compatible with the original 4004 package
//   - not a fully validated implementation of every last MCS-4 corner case
//
// Implemented instructions:
//   NOP, JCN, FIM, SRC, JIN, JUN, JMS, INC, ISZ,
//   ADD, SUB, LD, XCH, BBL, LDM,
//   WRM, WMP, WRR, WR0..WR3, SBM, RDM, RDR, ADM, RD0..RD3,
//   CLB, CLC, IAC, CMC, CMA, RAL, RAR, TCC, DAC, TCS, STC, DAA, KBP, DCL
//
// FIN is treated as NOP in this starter core.
// -----------------------------------------------------------------------------
module i4004_edu_core (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        en,
    input  wire        test_i,
    input  wire [3:0]  port_in,
    output reg  [3:0]  port_out,
    output wire [11:0] rom_addr,
    input  wire [7:0]  rom_data,
    output reg  [3:0]  acc,
    output reg         carry,
    output wire        zero,
    output reg  [11:0] pc_dbg,
    output reg  [7:0]  instr_dbg,
    output reg         phase_dbg,
    output reg         heartbeat_dbg
);

    reg [11:0] pc;
    reg [7:0]  op_latch;
    reg        phase;        // 0 = opcode fetch, 1 = immediate-byte fetch

    reg [11:0] ret_stack [0:2];
    reg [1:0]  sp;           // number of valid return entries: 0..3

    reg [3:0] regfile [0:15];
    reg [3:0] scratch [0:15];
    reg [3:0] status  [0:3];
    reg [3:0] ram_ptr;
    reg [1:0] port_sel;

    reg [4:0] tmp5;
    reg [3:0] tmp4;
    reg [3:0] even_idx;
    reg       cond_or;
    reg       cond_hit;

    integer i;

    assign rom_addr = pc;
    assign zero     = (acc == 4'h0);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc            <= 12'h000;
            pc_dbg        <= 12'h000;
            instr_dbg     <= 8'h00;
            phase         <= 1'b0;
            phase_dbg     <= 1'b0;
            op_latch      <= 8'h00;
            acc           <= 4'h0;
            carry         <= 1'b0;
            port_out      <= 4'h0;
            sp            <= 2'd0;
            ram_ptr       <= 4'h0;
            port_sel      <= 2'd0;
            heartbeat_dbg <= 1'b0;
            for (i = 0; i < 16; i = i + 1) begin
                regfile[i] <= 4'h0;
                scratch[i] <= 4'h0;
            end
            for (i = 0; i < 4; i = i + 1) begin
                status[i]  <= 4'h0;
            end
            for (i = 0; i < 3; i = i + 1) begin
                ret_stack[i] <= 12'h000;
            end
        end else if (en) begin
            pc_dbg        <= pc;
            instr_dbg     <= rom_data;
            phase_dbg     <= phase;
            heartbeat_dbg <= ~heartbeat_dbg;

            if (!phase) begin
                // -----------------------------
                // First byte / opcode fetch
                // -----------------------------
                case (rom_data[7:4])
                    4'h0: begin
                        // Only 0x00 is real NOP. The rest are reserved here.
                        pc <= pc + 12'd1;
                    end

                    4'h1,
                    4'h4,
                    4'h5,
                    4'h7: begin
                        // Two-byte ops: JCN, JUN, JMS, ISZ
                        op_latch <= rom_data;
                        pc       <= pc + 12'd1;
                        phase    <= 1'b1;
                    end

                    4'h2: begin
                        // FIM / SRC
                        if (!rom_data[0]) begin
                            op_latch <= rom_data;
                            pc       <= pc + 12'd1;
                            phase    <= 1'b1;
                        end else begin
                            even_idx = {rom_data[3:1], 1'b0};
                            ram_ptr  <= {regfile[even_idx][1:0], regfile[even_idx + 4'd1][1:0]};
                            pc       <= pc + 12'd1;
                        end
                    end

                    4'h3: begin
                        // FIN / JIN
                        even_idx = {rom_data[3:1], 1'b0};
                        if (!rom_data[0]) begin
                            // FIN not implemented in this starter core.
                            pc <= pc + 12'd1;
                        end else begin
                            pc <= {pc[11:8], regfile[even_idx], regfile[even_idx + 4'd1]};
                        end
                    end

                    4'h6: begin
                        regfile[rom_data[3:0]] <= regfile[rom_data[3:0]] + 4'd1;
                        pc <= pc + 12'd1;
                    end

                    4'h8: begin
                        tmp5  = {1'b0, acc} + {1'b0, regfile[rom_data[3:0]]} + {4'b0000, carry};
                        acc   <= tmp5[3:0];
                        carry <= tmp5[4];
                        pc    <= pc + 12'd1;
                    end

                    4'h9: begin
                        // Approximate 4004 subtract-with-borrow behavior:
                        // acc <= acc + (~R) + carry
                        tmp5  = {1'b0, acc} + {1'b0, ~regfile[rom_data[3:0]]} + {4'b0000, carry};
                        acc   <= tmp5[3:0];
                        carry <= tmp5[4];
                        pc    <= pc + 12'd1;
                    end

                    4'hA: begin
                        acc <= regfile[rom_data[3:0]];
                        pc  <= pc + 12'd1;
                    end

                    4'hB: begin
                        tmp4                    = acc;
                        acc                    <= regfile[rom_data[3:0]];
                        regfile[rom_data[3:0]] <= tmp4;
                        pc                     <= pc + 12'd1;
                    end

                    4'hC: begin
                        acc <= rom_data[3:0];
                        if (sp != 2'd0) begin
                            sp <= sp - 2'd1;
                            pc <= ret_stack[sp - 2'd1];
                        end else begin
                            pc <= pc + 12'd1;
                        end
                    end

                    4'hD: begin
                        acc <= rom_data[3:0];
                        pc  <= pc + 12'd1;
                    end

                    4'hE: begin
                        case (rom_data[3:0])
                            4'h0: scratch[ram_ptr] <= acc;          // WRM
                            4'h1: port_out         <= acc;          // WMP
                            4'h2: port_out         <= acc;          // WRR
                            4'h4: status[0]        <= acc;          // WR0
                            4'h5: status[1]        <= acc;          // WR1
                            4'h6: status[2]        <= acc;          // WR2
                            4'h7: status[3]        <= acc;          // WR3
                            4'h8: begin                              // SBM
                                tmp5  = {1'b0, acc} + {1'b0, ~scratch[ram_ptr]} + {4'b0000, carry};
                                acc   <= tmp5[3:0];
                                carry <= tmp5[4];
                            end
                            4'h9: acc <= scratch[ram_ptr];          // RDM
                            4'hA: acc <= port_in;                   // RDR
                            4'hB: begin                              // ADM
                                tmp5  = {1'b0, acc} + {1'b0, scratch[ram_ptr]} + {4'b0000, carry};
                                acc   <= tmp5[3:0];
                                carry <= tmp5[4];
                            end
                            4'hC: acc <= status[0];                // RD0
                            4'hD: acc <= status[1];                // RD1
                            4'hE: acc <= status[2];                // RD2
                            4'hF: acc <= status[3];                // RD3
                            default: ;
                        endcase
                        pc <= pc + 12'd1;
                    end

                    4'hF: begin
                        case (rom_data[3:0])
                            4'h0: begin // CLB
                                acc   <= 4'h0;
                                carry <= 1'b0;
                            end
                            4'h1: begin // CLC
                                carry <= 1'b0;
                            end
                            4'h2: begin // IAC
                                tmp5  = {1'b0, acc} + 5'd1;
                                acc   <= tmp5[3:0];
                                carry <= tmp5[4];
                            end
                            4'h3: begin // CMC
                                carry <= ~carry;
                            end
                            4'h4: begin // CMA
                                acc <= ~acc;
                            end
                            4'h5: begin // RAL
                                acc   <= {acc[2:0], carry};
                                carry <= acc[3];
                            end
                            4'h6: begin // RAR
                                acc   <= {carry, acc[3:1]};
                                carry <= acc[0];
                            end
                            4'h7: begin // TCC
                                acc   <= {3'b000, carry};
                                carry <= 1'b0;
                            end
                            4'h8: begin // DAC
                                tmp5  = {1'b0, acc} + 5'h1F; // acc - 1 mod 16
                                acc   <= tmp5[3:0];
                                carry <= tmp5[4];
                            end
                            4'h9: begin // TCS (starter approximation)
                                acc   <= carry ? 4'hA : 4'h9;
                                carry <= 1'b0;
                            end
                            4'hA: begin // STC
                                carry <= 1'b1;
                            end
                            4'hB: begin // DAA
                                if (carry || (acc > 4'd9)) begin
                                    tmp5  = {1'b0, acc} + 5'd6;
                                    acc   <= tmp5[3:0];
                                    carry <= tmp5[4] | carry;
                                end
                            end
                            4'hC: begin // KBP
                                case (acc)
                                    4'b0000: acc <= 4'd0;
                                    4'b0001: acc <= 4'd0;
                                    4'b0010: acc <= 4'd1;
                                    4'b0100: acc <= 4'd2;
                                    4'b1000: acc <= 4'd3;
                                    default: acc <= 4'hF;
                                endcase
                            end
                            4'hD: begin // DCL
                                port_sel <= acc[1:0];
                            end
                            default: ;
                        endcase
                        pc <= pc + 12'd1;
                    end

                    default: begin
                        pc <= pc + 12'd1;
                    end
                endcase
            end else begin
                // -----------------------------
                // Second byte / immediate fetch
                // -----------------------------
                phase <= 1'b0;
                case (op_latch[7:4])
                    4'h1: begin
                        // JCN - starter mapping: [3]=invert, [2]=test, [1]=carry, [0]=zero
                        cond_or = 1'b0;
                        if (op_latch[2] && test_i)      cond_or = 1'b1;
                        if (op_latch[1] && carry)       cond_or = 1'b1;
                        if (op_latch[0] && (acc == 4'h0)) cond_or = 1'b1;
                        if (op_latch[3]) begin
                            cond_hit = ~cond_or;
                        end else begin
                            cond_hit = cond_or;
                        end
                        if (cond_hit) begin
                            pc <= {pc[11:8], rom_data};
                        end else begin
                            pc <= pc + 12'd1;
                        end
                    end

                    4'h2: begin
                        // FIM
                        even_idx                  = {op_latch[3:1], 1'b0};
                        regfile[even_idx]         <= rom_data[7:4];
                        regfile[even_idx + 4'd1]  <= rom_data[3:0];
                        pc                        <= pc + 12'd1;
                    end

                    4'h4: begin
                        // JUN
                        pc <= {op_latch[3:0], rom_data};
                    end

                    4'h5: begin
                        // JMS
                        if (sp < 2'd3) begin
                            ret_stack[sp] <= pc + 12'd1;
                            sp            <= sp + 2'd1;
                        end
                        pc <= {op_latch[3:0], rom_data};
                    end

                    4'h7: begin
                        // ISZ
                        tmp4 = regfile[op_latch[3:0]] + 4'd1;
                        regfile[op_latch[3:0]] <= tmp4;
                        if (tmp4 != 4'h0) begin
                            pc <= {pc[11:8], rom_data};
                        end else begin
                            pc <= pc + 12'd1;
                        end
                    end

                    default: begin
                        pc <= pc + 12'd1;
                    end
                endcase
            end
        end
    end

endmodule

`default_nettype wire
