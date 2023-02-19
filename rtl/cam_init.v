`timescale 1ns / 1ps
`default_nettype none

/*
 *  Instantiates cam_rom, cam_config, sccb_master; 
 *  cam_config waits for i_cam_init_start and ready signal 
 *  from sccb_master in order to send data to sccb_master 
 *  
 *
 *  NOTE:
 *  - cam_config reads from a synchronous ROM
 *  - w_cam_rom_data = { OV7670 REG ADDR , OV7670 REG DATA }
 *  - some (unnecessary) signals used in testbench 
 */

module cam_init
#(parameter CLK_F = 100_000_000,
    parameter SCCB_F = 400_000)
    (   input wire      i_clk,
        input wire      i_rstn,      
        input wire      i_cam_init_start,
        output wire     o_siod,
        output wire     o_sioc,
        output wire     o_cam_init_done,        
        
        // Signal used only for testbench
        output wire         o_data_sent_done,
        output wire [7:0]   o_SCCB_dout
    );
    
    wire [7:0]  w_cam_rom_addr;
    wire [15:0] w_cam_rom_data;    
    wire [7:0]  w_send_addr,    w_send_data;  
    wire        w_start_sccb,   w_ready_sccb; 
    
    cam_rom 
    OV7670_Registers 
    (   .i_clk(i_clk            ),
        .i_rstn(i_rstn          ), 
        
        .i_addr(w_cam_rom_addr  ),
        .o_dout(w_cam_rom_data  )
    );
    
    cam_config 
    #(  .CLK_F(CLK_F)                   )
    OV7670_config
    (   .i_clk(i_clk                    ),
        .i_rstn(i_rstn                  ),
         
         // Ready/Start signals for SCCB: Poll for ready signal to start sending cam ROM data
        .i_i2c_ready(w_ready_sccb       ),
        .o_i2c_start(w_start_sccb       ),
        
        // Start/Done signals for cam init 
        .i_config_start(i_cam_init_start),
        .o_config_done(o_cam_init_done  ),
        
        // Read through cam ROM
        .i_rom_data(w_cam_rom_data      ),
        .o_rom_addr(w_cam_rom_addr      ),
        .o_i2c_addr(w_send_addr         ),
        .o_i2c_data(w_send_data         ) 
    );
      
    sccb_master 
    #(  .CLK_F(CLK_F), 
        .SCCB_F(SCCB_F)         )
    SCCB_HERE 
    (   .i_clk(i_clk            ),
        .i_rstn(i_rstn          ),
        
        // SCCB control signals 
        .i_read(1'b0            ),      
        .i_write(1'b1           ),
        .i_start(w_start_sccb   ),
        .i_restart(1'b0         ),
        .i_stop(1'b0            ),
        .o_ready(w_ready_sccb   ),
        
        // SCCB addr/data signals  
        .i_din(w_send_data      ),
        .i_addr(w_send_addr     ), 
        
        // Slave->Master com signals 
        .o_dout(o_SCCB_dout     ),      
        .o_done(o_data_sent_done),        
        .o_ack(                 ),       
        
        // SCCB Lines
        .io_sda(o_siod          ),      
        .o_scl(o_sioc           )
    );

endmodule