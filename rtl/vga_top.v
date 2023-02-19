`timescale 1ns / 1ps
`default_nettype none 

/*
 *  Uses X,Y pixel counters from VGA driver
 *  to form an address generator to read from BRAM; output
 *  RGB pixel data from BRAM during active video region;  
 *  wraps VGA sync pulses 
 *
 *  NOTE:  
 *  
 *  - Address generator only increments when
 *      1. Two complete VGA frames passed since reset
 *      2. Current posedge of VGA clock is a valid video pixel position
 *      3. Next posedge of VGA clock is a valid video pixel position
 *  
 *  - Address generator set to 0 in either circumstance
 *      1. Address to BRAM reaches 307199 (x = 640, y = 479)
 *      2. Next posedge of VGA clock is NOT valid video  
 *
 */

module vga_top
    (   input wire          i_clk25m,
        input wire          i_rstn_clk25m,
        
        // VGA driver signals
        output wire [9:0]   o_VGA_x,
        output wire [9:0]   o_VGA_y, 
        output wire         o_VGA_vsync,
        output wire         o_VGA_hsync, 
        output wire         o_VGA_video,
        output wire [3:0]   o_VGA_red,
        output wire [3:0]   o_VGA_green,
        output wire [3:0]   o_VGA_blue, 
        
        // VGA read from BRAM 
        input  wire [11:0] i_pix_data, 
        output reg  [18:0] o_pix_addr
    );
    
    vga_driver
    #(  .hDisp(640), 
        .hFp(16), 
        .hPulse(96), 
        .hBp(48), 
        .vDisp(480), 
        .vFp(10), 
        .vPulse(2),
        .vBp(33)                )
    vga_timing_signals
    (   .i_clk(i_clk25m         ),
        .i_rstn(i_rstn_clk25m   ),
        
        // VGA timing signals
        .o_x_counter(o_VGA_x    ),
        .o_y_counter(o_VGA_y    ),
        .o_video(o_VGA_video    ), 
        .o_vsync(o_VGA_vsync    ),
        .o_hsync(o_VGA_hsync    )
    );
    
    reg [3:0]   r_VGA_R;
    reg [3:0]   r_VGA_G; 
    reg [3:0]   r_VGA_B;
    reg [1:0]   r_SM_state;
    localparam [1:0]    WAIT_1  = 0,
                        WAIT_2  = 'd1,  
                        READ    = 'd2;
                          
    always @(posedge i_clk25m or negedge i_rstn_clk25m)
    if(!i_rstn_clk25m)
    begin
        r_SM_state <= WAIT_1;
        o_pix_addr <= 0; 
    end
    else
        case(r_SM_state)
        // Skip two frames
        WAIT_1: r_SM_state <= (o_VGA_x == 640 && o_VGA_y == 480) ? WAIT_2 : WAIT_1;
        WAIT_2: r_SM_state <= (o_VGA_x == 640 && o_VGA_y == 480) ? READ : WAIT_2; 
        READ: begin
            // Currently active video 
            if((o_VGA_y < 480) && (o_VGA_x < 639))
                o_pix_addr <= (o_pix_addr == 307199) ? 0 : o_pix_addr + 1'b1;
            else begin           
            // Next clock is active video 
            if( (o_VGA_x == 799) && ( (o_VGA_y == 524) || (o_VGA_y < 480) ) )
                o_pix_addr <= o_pix_addr + 1'b1;
            // Next clock not active video 
            else if(o_VGA_y >= 480)
                o_pix_addr <= 0;
            end
        end 
        endcase
    
    // Valid Video selects between a black RGB Pixel and BRAM pixel data 
    always @(*)
        begin
            if(o_VGA_video)
                begin
                    r_VGA_R = i_pix_data[11:8]; 
                    r_VGA_G = i_pix_data[7:4];
                    r_VGA_B = i_pix_data[3:0];
                end
            else begin
                    r_VGA_R = 0; 
                    r_VGA_G = 0;
                    r_VGA_B = 0;
            end
        end 
    
    assign o_VGA_red    = r_VGA_R;
    assign o_VGA_green  = r_VGA_G;
    assign o_VGA_blue   = r_VGA_B;
    
endmodule
