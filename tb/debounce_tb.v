`timescale 1ns / 1ps

module debounce_tb #(T_CLK = 10);    // 100 MHz tb clock
 
    // Input to Debounce
    reg  clk;
    reg  in;
    
    // Output of Debounce 
    wire out;
    
    debounce 
    #( .DELAY(100000))               // 1 ms debounced pulse 
    uut
    (
        .i_clk(clk ), 
        .i_in(in   ),
        .o_out(out )
    ); 
    
    initial                        
        begin
            clk = 0; 
        end 
    
    always                          // 100 MHz clock 
        begin   
            #(T_CLK/2)
            clk = ~clk; 
        end 
 
    localparam eighth = 100000/8;
    localparam fourth = 100000/4;
    localparam half   = 100000/2; 
    localparam total  = 100000;
    localparam double = 2*(100000);
    
    // Simulate a glitchy input
    initial
        begin
            in = 0;
            #(5*double)
            in = 1; 
            #(eighth/32)
            in = 0;
            #(fourth/32) 
            in = 1; 
            #(eighth/16)
            in = 0;
            #(half/32)
            in = 1; 
            #(2*total)
            in = 0;
            #(total/256)
            in = 1;
            #(half/512)
            in = 0; 
            #(fourth/32)
            in = 1;
            #(eighth)
            in = 0; 
            #(eighth/4)
            $finish();
        end 
        
endmodule
