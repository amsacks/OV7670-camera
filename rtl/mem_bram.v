`timescale 1ns / 1ps
`default_nettype none

/*
 *  Infers a dual-port BRAM with variable width and depth 
 *  
 *  NOTE: 
 *  - One clock delay with read/write
 *
 */

module mem_bram
#(parameter WIDTH = 11,
    parameter DEPTH = 640*480)
    (   input wire                      i_wclk,
        input wire                      i_wr,
        input wire [$clog2(DEPTH)-1:0]  i_wr_addr,
        
        input wire                      i_rclk,
        input wire                      i_rd,
        input wire [$clog2(DEPTH)-1:0]  i_rd_addr,
        
        input wire                      i_bram_en,
        input wire [WIDTH-1:0]          i_bram_data,
        output reg [WIDTH-1:0]          o_bram_data      
    );
    
    // Infer dual-port BRAM with dual clocks
    // https://docs.xilinx.com/v/u/2019.2-English/ug901-vivado-synthesis (page 126)
    reg [WIDTH-1:0] ram [0:DEPTH-1]; 
    
    always @(posedge i_wclk)
    if(i_bram_en)
        if(i_wr)
            ram[i_wr_addr] <= i_bram_data;
    
    always @(posedge i_rclk)
    if(i_rd)
        o_bram_data <= ram[i_rd_addr]; 

endmodule

