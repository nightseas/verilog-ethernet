/*

Copyright (c) 2014-2017 Alex Forencich

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/

// Language: Verilog 2001

`timescale 1ns / 1ps

/*
 * AXI4-Stream SRL-based FIFO register
 */
module axis_srl_register #
(
    parameter DATA_WIDTH = 8,
    parameter KEEP_ENABLE = (DATA_WIDTH>8),
    parameter KEEP_WIDTH = (DATA_WIDTH/8),
    parameter LAST_ENABLE = 1,
    parameter ID_ENABLE = 0,
    parameter ID_WIDTH = 8,
    parameter DEST_ENABLE = 0,
    parameter DEST_WIDTH = 8,
    parameter USER_ENABLE = 1,
    parameter USER_WIDTH = 1
)
(
    input  wire                       clk,
    input  wire                       rst,

    /*
     * AXI input
     */
    input  wire [DATA_WIDTH-1:0]  input_axis_tdata,
    input  wire [KEEP_WIDTH-1:0]  input_axis_tkeep,
    input  wire                   input_axis_tvalid,
    output wire                   input_axis_tready,
    input  wire                   input_axis_tlast,
    input  wire [ID_WIDTH-1:0]    input_axis_tid,
    input  wire [DEST_WIDTH-1:0]  input_axis_tdest,
    input  wire [USER_WIDTH-1:0]  input_axis_tuser,

    /*
     * AXI output
     */
    output wire [DATA_WIDTH-1:0]  output_axis_tdata,
    output wire [KEEP_WIDTH-1:0]  output_axis_tkeep,
    output wire                   output_axis_tvalid,
    input  wire                   output_axis_tready,
    output wire                   output_axis_tlast,
    output wire [ID_WIDTH-1:0]    output_axis_tid,
    output wire [DEST_WIDTH-1:0]  output_axis_tdest,
    output wire [USER_WIDTH-1:0]  output_axis_tuser
);

localparam KEEP_OFFSET = DATA_WIDTH;
localparam LAST_OFFSET = KEEP_OFFSET + (KEEP_ENABLE ? KEEP_WIDTH : 0);
localparam ID_OFFSET   = LAST_OFFSET + (LAST_ENABLE ? 1          : 0);
localparam DEST_OFFSET = ID_OFFSET   + (ID_ENABLE   ? ID_WIDTH   : 0);
localparam USER_OFFSET = DEST_OFFSET + (DEST_ENABLE ? DEST_WIDTH : 0);
localparam WIDTH       = USER_OFFSET + (USER_ENABLE ? USER_WIDTH : 0);

reg [WIDTH-1:0] data_reg[1:0];
reg valid_reg[1:0];
reg ptr_reg = 0;
reg full_reg = 0;

wire [WIDTH-1:0] input_axis;

wire [WIDTH-1:0] output_axis = data_reg[ptr_reg];

assign input_axis_tready = ~full_reg;

generate
    assign input_axis[DATA_WIDTH-1:0] = input_axis_tdata;
    if (KEEP_ENABLE) assign input_axis[KEEP_OFFSET +: KEEP_WIDTH] = input_axis_tkeep;
    if (LAST_ENABLE) assign input_axis[LAST_OFFSET]               = input_axis_tlast;
    if (ID_ENABLE)   assign input_axis[ID_OFFSET   +: ID_WIDTH]   = input_axis_tid;
    if (DEST_ENABLE) assign input_axis[DEST_OFFSET +: DEST_WIDTH] = input_axis_tdest;
    if (USER_ENABLE) assign input_axis[USER_OFFSET +: USER_WIDTH] = input_axis_tuser;
endgenerate

assign output_axis_tvalid = valid_reg[ptr_reg];

assign output_axis_tdata = output_axis[DATA_WIDTH-1:0];
assign output_axis_tkeep = KEEP_ENABLE ? output_axis[KEEP_OFFSET +: KEEP_WIDTH] : {KEEP_WIDTH{1'b1}};
assign output_axis_tlast = LAST_ENABLE ? output_axis[LAST_OFFSET]               : 1'b1;
assign output_axis_tid   = ID_ENABLE   ? output_axis[ID_OFFSET   +: ID_WIDTH]   : {ID_WIDTH{1'b0}};
assign output_axis_tdest = DEST_ENABLE ? output_axis[DEST_OFFSET +: DEST_WIDTH] : {DEST_WIDTH{1'b0}};
assign output_axis_tuser = USER_ENABLE ? output_axis[USER_OFFSET +: USER_WIDTH] : {USER_WIDTH{1'b0}};

integer i;

initial begin
    for (i = 0; i < 2; i = i + 1) begin
        data_reg[i] <= 0;
        valid_reg[i] <= 0;
    end
end

always @(posedge clk) begin
    if (rst) begin
        ptr_reg <= 0;
        full_reg <= 0;
    end else begin
        // transfer empty to full
        full_reg <= ~output_axis_tready & output_axis_tvalid;

        // transfer in if not full
        if (input_axis_tready) begin
            data_reg[0] <= input_axis;
            valid_reg[0] <= input_axis_tvalid;
            for (i = 0; i < 1; i = i + 1) begin
                data_reg[i+1] <= data_reg[i];
                valid_reg[i+1] <= valid_reg[i];
            end
            ptr_reg <= valid_reg[0];
        end

        if (output_axis_tready) begin
            ptr_reg <= 0;
        end
    end
end

endmodule
