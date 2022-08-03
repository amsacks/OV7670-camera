`timescale 1ns / 1ps

// Includes modules: cam_rom, cam_config, sccb_master 
module cam_interface
    #(  parameter CLK_F = 25_000_000,
        parameter SCCB_F = 400_000 )
    (   input  i_clk,
        input  i_rst,      
        input  i_start,
        output o_siod,
        output o_sioc,
        output o_done         // Reading all of ROM is done.
    );

    wire [7:0]  cam_rom_addr;
    wire [15:0] cam_rom_data;    
    wire [7:0]  send_addr, send_data;  
    wire        start_i2c, ready_i2c; 
    
    cam_rom OV7670_Registers 
    (   .i_clk(i_clk         ),
        .i_rst(i_rst         ), 
        .i_addr(cam_rom_addr ),
        .o_dout(cam_rom_data )
    );
    
    // Read Rom to configure OV7670 and send it to sccb_master
    cam_config #(.CLK_F(CLK_F))
    (   .i_clk(i_clk             ),
        .i_rst(i_rst             ), 
        .i_i2c_ready(ready_i2c   ),
        .i_config_start(i_start  ),
        .i_rom_data(cam_rom_data ),
        
        .o_rom_addr(cam_rom_addr ),
        .o_i2c_addr(send_addr    ),
        .o_i2c_data(send_data    ),
        .o_config_done(o_done    ),
        .o_i2c_start(start_i2c   )
    );
      
    sccb_master 
    #( .CLK_F(CLK_F), .SCCB_F(SCCB_F) )
    SCCB_HERE 
    (   .i_clk(i_clk       ),
        .i_rst(i_rst       ),
        .i_read(1'b0       ),      
        .i_write(1'b1      ),
        .i_start(start_i2c ),
        .i_restart(1'b0    ),
        .i_stop(1'b0       ),

        .i_din(send_data   ),
        .i_addr(send_addr  ), 
        
        .o_dout(            ),
        .o_ready(ready_i2c  ),      
        .o_done(            ),        
        .o_ack(             ),       
        
        // SCCB Lines
        .io_sda(o_siod      ),      
        .o_scl(o_sioc       )
    );

endmodule