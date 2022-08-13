`timescale 1ns / 1ps

module vga_top
    (   input        i_clk25m,
        input        i_rst_clk25m,
        
        // Output of VGA Driver to top module 
        output [9:0] o_VGA_x,
        output [9:0] o_VGA_y, 
        output       o_VGA_vsync,
        output       o_VGA_hsync, 
        output       o_VGA_video,
        output [3:0] o_VGA_red,
        output [3:0] o_VGA_green,
        output [3:0] o_VGA_blue, 
        
        // I/O from VGA top to memory (BRAM)
        input  [12:0] i_pix_mem_data, 
        output [18:0] o_VGA_pix_addr
    );
    
    VGA_controller #(.hDisp(640), .hFp(16), .hPulse(96), .hBp(48), 
                     .vDisp(480), .vFp(11), .vPulse(2),  .vBp(31))
    vga_driver
    (   .i_clk(i_clk25m            ),
        .i_rst(i_rst_clk25m        ),
        .o_x_counter(o_VGA_x       ),
        .o_y_counter(o_VGA_y       ),
        .o_video(o_VGA_video       ), 
        .o_vsync_pulse(o_VGA_vsync ),
        .o_hsync_pulse(o_VGA_hsync )
    );
    
    reg [18:0] r_VGA_pix_addr;
    reg [3:0]  r_VGA_R, r_VGA_G, r_VGA_B;
    
    
    always @(posedge i_clk25m)
      r_VGA_pix_addr <= (o_VGA_y >= 480) ? 0 : ((o_VGA_x < 640) ?  r_VGA_pix_addr + 1'b1 : r_VGA_pix_addr);
          
    always @(*)
        begin
            if(o_VGA_video)
                begin
                    r_VGA_R = i_pix_mem_data[11:8]; 
                    r_VGA_G = i_pix_mem_data[7:4];
                    r_VGA_B = i_pix_mem_data[3:0];
                end
            else begin
                    r_VGA_R = 0; 
                    r_VGA_G = 0;
                    r_VGA_B = 0;
            end
        end 
    
    assign o_VGA_red      = r_VGA_R;
    assign o_VGA_green    = r_VGA_G;
    assign o_VGA_blue     = r_VGA_B;
    assign o_VGA_pix_addr = r_VGA_pix_addr;
    
endmodule
