`timescale 1ns / 1ps

module mem_bram
    #(  parameter DATA_WIDTH = 12, 
        parameter DEPTH      = 640*480 )
     (  input                      w_clk,
        input                      w_en, 
        input [DATA_WIDTH-1:0]     w_din,
        input [$clog2(DEPTH)-1:0]  w_addr,
        
        input                      r_clk,
        input                      r_en,
        input  [$clog2(DEPTH)-1:0] r_addr, 
        output [DATA_WIDTH-1:0]    r_dout   
    );
    
    // Infer Simple-Dual Port BRAM with dual clocks
    // https://docs.xilinx.com/v/u/2019.2-English/ug901-vivado-synthesis (page 113)
    reg [DATA_WIDTH-1:0] bram [DEPTH-1:0];
    reg [DATA_WIDTH-1:0] reg_dout; 
    
    always @(posedge w_clk)
        begin   
            if(w_en)
                bram[w_addr] <= w_din;
        end 
    
    always @(posedge r_clk)
        begin
            if(r_en)
                reg_dout <= bram[r_addr]; 
        end 
    
    assign r_dout = reg_dout; 
    
endmodule
