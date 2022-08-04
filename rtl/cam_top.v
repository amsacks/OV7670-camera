`timescale 1ns / 1ps

module cam_top
    #(  parameter CAM_CONFIG_CLK = 100_000_000)
     (  input        i_clk, 
        input        i_pclk,      
        input        i_rst_clk,
        input        i_rst_pclk,
        
        // I/O for cam initalization
        input        i_cam_start,
        output       o_cam_done,
        
        // I/O for FPGA to OV7670 
        input [7:0]  i_pix_byte, 
        input        i_vsync,
        input        i_href,
        output       o_RESET,     
        output       o_PWDN,       
        output       o_siod,
        output       o_sioc,
        
        // Outputs to memory (BRAM)
        output        o_pix_wren, 
        output [11:0] o_pix_data,
        output [18:0] o_pix_addr
    );
    
    assign o_RESET = 1;       // 0: reset registers   1: normal mode
    assign o_PWDN  = 0;       // 0: normal mode       1: power down mode
       
    wire       start_db;
        
    debounce #(.DELAY(CAM_CONFIG_CLK/1000))    
    button0
    (   .i_clk(i_clk      ), 
        .i_in(i_cam_start ),
        .o_out(start_db   )
    );
    
    cam_interface #(.CLK_F(CAM_CONFIG_CLK), .SCCB_F(400_000) )
    configure_cam
    (   .i_clk(i_clk       ),
        .i_rst(i_rst_clk   ),      
        .i_start(start_db  ),
        .o_siod(o_siod     ),
        .o_sioc(o_sioc     ),
        .o_done(o_cam_done )
    );
    
    cam_capture
    cam_pixels
    (   .i_pclk(i_pclk         ), 
        .i_rst(i_rst_pclk      ),
        .i_vsync(i_vsync       ),
        .i_href(i_href         ),
        .i_D(i_pix_byte        ),
        .i_cam_done(o_cam_done ),
        .o_pix_addr(o_pix_addr ),
        .o_wren(o_pix_wren     ),           
        .o_pix_data(o_pix_data )  
    );
      
endmodule
