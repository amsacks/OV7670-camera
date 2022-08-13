`timescale 1ns / 1ps

module vga_controller_tb();

    // Input to VGA controller
    reg clk;
    reg rst;
    
    // Output of VGA controller
    wire [9:0] x;
    wire [9:0] y;
    wire video;
    wire vsync; 
    wire hsync; 
    
    // Assuming 25 MHz Pixel Clock and 640x480 res
    VGA_controller
    uut
    (
        .i_clk(clk           ),
        .i_rst(rst           ), 
        .o_x_counter(x       ), 
        .o_y_counter(y       ), 
        .o_video(video       ), 
        .o_hsync_pulse(vsync ), 
        .o_vsync_pulse(hsync )
    );

    initial
        begin
            clk = 0; 
            rst = 0;
            #1
            rst = 1;
            #1
            rst = 0; 
        end
        
    always #20 clk = ~clk; 
    
    /* For 640x480 25MHz Pixel Clock
     *
     * Video = 0: when         x >  640    and     y > 480
     * Video = 1: when         x >  0      and     y > 0
     * hSync = 0: when  656 <  x <  752 
     * vSync = 0: when                      491 <= y <= 493
     *
     */
    initial
        begin
              #500
              wait(video == 1'b0)     
              $display("When Video = 0: x = %d, y = %d, hsync = %d, vsync = %d \n",x,y,hsync,vsync);
              wait(video == 1'b1)     
              $display("When Video = 1: x = %d, y = %d, hsync = %d, vsync = %d \n",x,y,hsync,vsync);
              wait(hsync == 1'b0)
              $display("When hsync = 0: x = %d, y = %d, video = %b \n", x,y,video);
              wait(hsync == 1'b1)
              $display("When hsync = 1: x = %d, y = %d, video = %b \n", x,y,video);
              wait(vsync == 1'b0)
              $display("When vsync = 0: x = %d, y = %d, video = %b \n", x,y,video);
              wait(vsync == 1'b1)  
              $display("When vsync = 1: x = %d,  y = %d, video = %b\n", x,y,video); 
       end   
endmodule
