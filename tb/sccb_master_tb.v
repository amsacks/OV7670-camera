`timescale 1ns / 1ps


module sccb_master_tb();

    reg clk; 
    reg rst;
    reg start; 
    reg [7:0]  addr; 
    reg [7:0]  din; 
    
    wire [7:0] dout; 
    wire ready; 
    wire done; 
    wire sda; 
    wire scl;
    
    sccb_master
    uut
    (
        .i_clk(clk),
        .i_rst(rst),
        
        .i_read(1'b0),       
        .i_write(1'b1),
        .i_start(start),
        .i_restart(1'b0),
        .i_stop(1'b0),
        
        .i_din(din),
        .i_addr(addr), 
        
        .o_dout(dout),
        .o_ready(ready),      
        .o_done(done),      
        .o_ack(),                   
        
        .io_sda(sda),      
        .o_scl(scl)
    );
    
initial
    begin
        start = 0; 
        din   = 8'h73;
        addr  = 8'h5F;
        clk   = 0;
        rst   = 0; 
        #1;
        rst = 1;
        #1
        start = 1;  
        rst   = 0; 
    end 

always #5 clk = (~clk);

initial
    begin
        wait(ready == 1'b0) start = 0; 
        repeat (100) @(posedge clk) 
        wait(ready == 1'b1) start = 1; 
        din  <= 8'h0A;
        addr <= 8'hFF; 
        $finish;
    end 
    
endmodule
