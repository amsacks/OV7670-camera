`timescale 1ns / 1ps
`default_nettype none

/*
 *  Filters glitchy inputs by ignoring state changes
 *  that occur within less than DELAY clock ticks 
 *
 *  Registers state change, debounced output, after 
 *  DELAY number of clock ticks of an unchanged input
 *  
 *  NOTE:
 *  DELAY = (Debounce Time [s]) * (i_clk [Hz])
 * 
 */

module debouncer 
#(parameter DELAY = 1_000_000)
(
    input wire  i_clk,
    input wire  i_btn_in,
    output wire o_btn_db         
);

    localparam MAX_COUNT = $clog2(DELAY); 
    reg [MAX_COUNT-1:0] counter;
    reg                 r_sample;
    
    initial { counter, r_sample } = 0; 
    
    always @(posedge i_clk)
        begin
            if(i_btn_in !== r_sample && counter < DELAY)
                counter <= counter + 1'b1; 
            else if(counter == DELAY)
                begin
                    counter <= 0;
                    r_sample <= i_btn_in;
                end
            else
                counter <= 0;  
        end 

assign o_btn_db = r_sample; 

endmodule

