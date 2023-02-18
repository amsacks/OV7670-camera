`timescale 1ns / 1ps
`default_nettype none

/*
 *  Begins sending cam rom to sccb_master after
 *  i_config_start button is asserted and sccb_master is ready (first state)
 *
 *  creates a delay using a timer, which is used after sending data to  
 *  reset sccb registers
 *  
 *  signal a cam initalization done signal for modules downstream
 *
 */

module cam_config
#(parameter CLK_F = 100_000_000)
    (   input wire          i_clk,
        input wire          i_rstn,
        input wire          i_i2c_ready,
        input wire          i_config_start,
        input wire [15:0]   i_rom_data, 
        output reg [7:0]    o_rom_addr,
        output reg          o_i2c_start, 
        output reg [7:0]    o_i2c_addr,
        output reg [7:0]    o_i2c_data,
        output reg          o_config_done
    );
    
    localparam ten_ms_delay  = (CLK_F * 10) / 1000;
    localparam timer_size    =  $clog2(ten_ms_delay);
    reg [timer_size - 1: 0] timer;
    
    localparam SM_IDLE  = 0;
    localparam SM_SEND  = 1;
    localparam SM_DONE  = 2;
    localparam SM_TIMER = 3;

    reg [2:0] SM_state;
    reg [2:0] SM_return_state;
    reg [1:0] byte_index; 
    
    always @(posedge i_clk or negedge i_rstn)
        begin
            if(!i_rstn) begin
                    o_config_done <= 0;
                    byte_index    <= 0; 
                    o_rom_addr    <= 0;
                    o_i2c_addr    <= 0; 
                    o_i2c_start   <= 0;
                    o_i2c_data    <= 0; 
                    SM_state      <= SM_IDLE;
                end
            else begin
                case(SM_state)
                    SM_IDLE: 
                        begin
                            SM_state <= (i_config_start) ? SM_SEND : SM_IDLE;                        
                        end 
                    SM_SEND:
                        begin
                            if(i_i2c_ready)
                                case(i_rom_data)
                                16'hFF_FF: SM_state <= SM_DONE;
                                16'hFF_F0: begin
                                                SM_state          <= SM_TIMER;
                                                SM_return_state   <= SM_SEND;
                                                timer             <= ten_ms_delay;
                                                o_rom_addr        <= o_rom_addr + 1;
                                           end 
                                default: 
                                        begin 
                                            SM_state        <= SM_TIMER;
                                            SM_return_state <= SM_SEND; 
                                            timer           <= 1;                             
                                            o_i2c_start     <= 1;                                        
                                            o_i2c_addr      <= i_rom_data[15:8]; 
                                            o_i2c_data      <= i_rom_data[7:0];
                                            o_rom_addr      <= o_rom_addr + 1; 
                                        end  
                                endcase 
                        end 
                    SM_DONE:
                        begin
                            SM_state        <= SM_IDLE;
                            o_config_done   <= 1; 
                        end
                    SM_TIMER:
                        begin
                            SM_state    <= (timer == 1) ? SM_return_state : SM_TIMER;
                            timer       <= (timer == 1) ?        0        : timer - 1; 
                            o_i2c_start <= 0;      
                        end  
                endcase
            end   
        end 
           
endmodule
