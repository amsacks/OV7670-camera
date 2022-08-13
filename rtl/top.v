`timescale 1ns / 1ps

module top
    (   input clk,
        input rst,

        input  cam_start,
        output cam_done,
        
        // I/O for FPGA to camera
        input        pclk,
        input [7:0]  pix_byte, 
        input        vsync,
        input        href,
        output       RESET, 
        output       PWDN,
        output       xclk,
        output       siod,
        output       sioc,
        
        // I/O for FPGA to VGA
        output [3:0] VGA_R,
        output [3:0] VGA_G,
        output [3:0] VGA_B,
        output       VGA_vsync, 
        output       VGA_hsync
    );
    
    // clk to vga_top
    wire clk25m;
    
    // connect cam_top/vga_top to memory (BRAM)
    wire [11:0] i_bram_pix_data,  o_bram_pix_data;
    wire [18:0] i_bram_pix_addr,  o_bram_pix_addr; 
    wire        i_bram_pix_wren;
    
    /*  Double FF for Multi-clock reset using a common reset (rst in top module)
     *  http://www.sunburst-design.com/papers/CummingsSNUG2003Boston_Resets.pdf  [page 33]
     */
    reg r1_rst_clk,    r2_rst_clk;
    reg r1_rst_pclk,   r2_rst_pclk; 
    reg r1_rst_clk25m, r2_rst_clk25m;
         
    always @(posedge clk or posedge rst)
        begin
            if(rst) {r2_rst_clk, r1_rst_clk} <= 2'b11;
            else    {r2_rst_clk, r1_rst_clk} <= {r1_rst_clk, 1'b0};
        end  
    always @(posedge pclk or posedge rst)
        begin
            if(rst) {r2_rst_pclk, r1_rst_pclk} <= 2'b11;
            else    {r2_rst_pclk, r1_rst_pclk} <= {r1_rst_pclk, 1'b0};
        end 
    always @(posedge clk25m or posedge rst)
        begin
            if(rst) {r2_rst_clk25m, r1_rst_clk25m} <= 2'b11;
            else    {r2_rst_clk25m, r1_rst_clk25m} <= {r1_rst_clk25m, 1'b0};
        end 
    
    // Generate clocks for VGA and camera 
    clk_wiz_0 
    vga_and_cam_clk
    (
        .clk_in1(clk     ),
        .reset(rst       ),
        .clk_out1(clk25m ),
        .clk_out2(xclk   ) 
    );
    
    // FPGA to camera interface module                              
    cam_top #(.CAM_CONFIG_CLK(100_000_000))
    camera
    (   
        .i_clk(clk                  ),
        .i_rst_clk(r2_rst_clk       ),
        .i_rst_pclk(r2_rst_pclk     ),
        
        // I/O for camera intialization 
        .i_cam_start(cam_start      ),
        .o_cam_done(cam_done        ),
        
         // I/O from FPGA to camera 
        .i_pclk(pclk                ),
        .i_pix_byte(pix_byte        ),
        .i_vsync(vsync              ), 
        .i_href(href                ), 
        .o_RESET(RESET              ),
        .o_PWDN(PWDN                ), 
        .o_siod(siod                ),
        .o_sioc(sioc                ),
        
        // Outputs from camera to memory (write)
        .o_pix_wren(i_bram_pix_wren ), 
        .o_pix_data(i_bram_pix_data ),
        .o_pix_addr(i_bram_pix_addr )
    ); 
    
    vga_top
    display_module
    (   
        .i_clk25m(clk25m                ),
        .i_rst_clk25m(r2_rst_clk25m     ),
        
        // Output of VGA to top module 
        .o_VGA_x(                       ),
        .o_VGA_y(                       ), 
        .o_VGA_vsync(VGA_vsync          ),
        .o_VGA_hsync(VGA_hsync          ), 
        .o_VGA_video(                   ),
        .o_VGA_red(VGA_R                ),
        .o_VGA_green(VGA_G              ),
        .o_VGA_blue(VGA_B               ), 
        
        // I/O from VGA top to memory (read)
        .i_pix_mem_data(o_bram_pix_data ), 
        .o_VGA_pix_addr(o_bram_pix_addr )
    );
    
    mem_bram 
    #( .DATA_WIDTH(12), .DEPTH(640*480))
    BRAM
    (  
       .w_clk(pclk             ),
       .w_en(i_bram_pix_wren   ),
       .w_din(i_bram_pix_data  ),
       .w_addr(i_bram_pix_addr ),
       
       .r_clk(clk25m           ),
       .r_en(1'b1              ),
       .r_addr(o_bram_pix_addr ),
       .r_dout(o_bram_pix_data )    
    );
    
endmodule