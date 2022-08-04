`timescale 1ns / 1ps

/* For RGB 444 output, the pixel data is 
       1st byte: {   X,    X,    X,    X, R[3], R[2], R[1], R[0]}
       2nd byte: {G[3], G[2], G[1], G[0], B[3], B[2], B[1], B[0]
    
   Pixel_data format: {RRRR GGGG BBBB};
*/

module cam_capture
    (   input              i_pclk,
        input              i_rst,  
        input              i_vsync,
        input              i_href,    
        input       [7:0]  i_D,
        input              i_cam_done,
        output      [18:0] o_pix_addr, 
        output reg  [11:0] o_pix_data,        
        output reg         o_wren                   
    );
       
    // Negative and Positive Edge Detection of vsync input for frame start/frame done signal
    reg         r1_vsync,    r2_vsync; 
    wire        frame_start, frame_done;
    
    always @(posedge i_pclk or posedge i_rst)
    begin
        if(i_rst) begin
            r1_vsync <= 1'b0; 
            r2_vsync <= 1'b0; 
        end
        else 
            {r2_vsync, r1_vsync} <= {r1_vsync, i_vsync}; 
    end 
        
    assign frame_start = (r1_vsync == 0) && (r2_vsync == 1);    // Negative Edge of vsync
    assign frame_done  = (r1_vsync == 1) && (r2_vsync == 0);    // Positive Edge of vsync
     
    // FSM for capturing pixel data in pclk domain
    localparam [1:0] SM_WAIT = 2'd0,
                     SM_IDLE = 2'd1,
                     SM_DATA = 2'd2;
    
    reg        half_data;               
    reg [1:0]  SM_state;
    reg [11:0] pixel_data;
    reg [18:0] r_pix_addr;
                                                                                                        
    always @(posedge i_pclk)
        begin
            half_data   <= 0;
            o_wren      <= 0; 
            o_pix_data  <= 0; 
            r_pix_addr  <= 0;
            
            case(SM_state)
                SM_WAIT: 
                    begin
                        SM_state    <= (frame_start && i_cam_done) ? SM_IDLE : SM_WAIT;
                    end
                SM_IDLE:        
                    begin
                        SM_state   <= (frame_start) ? SM_DATA : SM_IDLE; 
                    end
                SM_DATA:
                    begin
                        SM_state   <= (frame_done) ? SM_IDLE           : SM_DATA; 
                        r_pix_addr <= (half_data)  ? r_pix_addr + 1'b1 : r_pix_addr;   // Every 2nd byte taken is a new pixel/address
                        if(i_href)
                            begin 
                                 if(!half_data) pixel_data[3:0] <= i_D[3:0];
                                 else           pixel_data      <= {pixel_data[3:0], i_D};
                                 
                                 half_data  <= (~half_data);                       
                                 o_wren     <= (half_data) ? 1'b1 : 1'b0;
                                 o_pix_data <= (half_data) ? {pixel_data[3:0], i_D} : o_pix_data; 
                            end 
                    end  
            endcase
        end
     
    // Assign pixel address
    assign     o_pix_addr = r_pix_addr; 
        
endmodule
