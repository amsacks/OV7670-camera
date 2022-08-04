`timescale 1ns / 1ps

/* Debounce time calculation: 
    
    Count_size * (1/f_clk) = Debounce Time
    Count_size = Debounce Time * f_clk
*/

module debounce
    #(  parameter DELAY = 240_000)
     (  input      i_clk,  
        input      i_in,      
        output     o_out
     );
     
    localparam cnt_size = $clog2(DELAY); 
    reg [cnt_size-1:0] count; 
    reg                r_sample;
       
    always @(posedge i_clk)
        begin
            if(i_in !== r_sample && count < (DELAY-1))
                count <= count + 1'b1;
            else if(count == (DELAY-1))
                begin
                    count    <= 0; 
                    r_sample <= i_in;
                end 
            else
                count <= 0;  
        end 
   
   assign o_out = r_sample; 
endmodule
