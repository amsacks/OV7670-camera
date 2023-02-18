`timescale 1ns / 1ps

/*
 * A very simple self-check testbench to 
 * verify that a glitchy input is filtered 
 * after the delay in order to produce a
 * debounced button output.
 */

module debouncer_tb();
    
    // For a 100 MHz clock, set up debounce time as 10 ms 
    // Debounce Time = DELAY_TB/f_CLK
    
    localparam DELAY_TB = 1_000_000;  
    localparam T_CLK    = 10;   // in ns
    
    reg   i_clk;
    reg   i_btn_in;
    wire  o_btn_db; 
    
    
    // UUT Instantiation
    debouncer
    #(.DELAY(DELAY_TB))
    uut
    (
        .i_clk(i_clk        ),
        .i_btn_in(i_btn_in  ), 
        .o_btn_db(o_btn_db  )
    ); 
    
    initial 
        begin
            i_clk = 0;
            i_btn_in = 0; 
        end 
    
    always 
        begin
            #(T_CLK/2) 
            i_clk = ~i_clk;
        end
   
    initial
        begin: TB
            integer i;
            
            // Set up $time in units of ms with precision up to 6 decimals 
            $timeformat(-3, 6, " ms" );
            
            $display("Starting testbench. \n");
            #(2*T_CLK);
            
            $display("Simulating glitchy button input.\n");
            for(i = 0; i < 20; i = i + 1)                     
                begin
                    $display("Time: %0t\n", $time);
                    $display("Button State: %b\t Debounced Output: %b\n\n", i_btn_in, o_btn_db); 
                    #(($urandom % DELAY_TB)*T_CLK)            
                    i_btn_in = ~i_btn_in; 
                end
                
            // Create a long enough delay to have a debounced output
            for(i = 0; i < 3; i = i + 1)
                begin
                    $display("Time: %t\n", $time);
                    $display("Button State: %b\t Debounced Output: %b\n\n", i_btn_in, o_btn_db);
                    #((DELAY_TB+1)*T_CLK)
                    i_btn_in = ~i_btn_in; 
                end

            $finish(); 
        end 

endmodule
