`timescale 1ns / 1ps

module VGA_controller
    #(  parameter hDisp  = 640, 
        parameter hFp    = 16,
        parameter hPulse = 96,
        parameter hBp    = 48,   
        parameter vDisp  = 480,
        parameter vFp    = 11,   
        parameter vPulse = 2,
        parameter vBp    = 31 )
     (  input          i_clk,
        input          i_rst,
        output  [9:0]  o_x_counter,
        output  [9:0]  o_y_counter,
        output  reg    o_video,
        output  reg    o_hsync_pulse,
        output  reg    o_vsync_pulse
     );
     
     // Horizonal timing     hEND = 800
     localparam hEND        = hDisp + hFp + hPulse + hBp; 
     localparam hSyncStart  = hDisp + hFp;
     localparam hSyncEnd    = hDisp + hFp + hPulse;
             
     // Vertical timing      vEND = 524
     localparam vEND        = vDisp + vFp + vPulse + vBp;
     localparam vSyncStart  = vDisp + vFp;
     localparam vSyncEnd    = vDisp + vFp + vPulse;
     
     reg [9:0]  hc, vc;
     
     always@(posedge i_clk or posedge i_rst)
        begin
            if(i_rst) begin
                hc            <= 0;
                vc            <= 0;
                o_hsync_pulse <= 0;
                o_vsync_pulse <= 0;
                o_video       <= 0;
            end
            else begin
                if(hc == hEND)
                    hc <= 0; 
                else hc <= hc + 1'b1;
                
                if((vc == vEND) && (hc == hEND))
                   vc <= 0; 
                else if(hc == hEND)
                    vc <= vc + 1'b1; 
                    
                o_hsync_pulse  <= ~((hc >= hSyncStart) && (hc <= hSyncEnd));
                o_vsync_pulse  <= ~((vc >= vSyncStart) && (vc <= vSyncEnd));
                o_video        <=  ((hc < hDisp) && (vc < vDisp));
            end
        end 
        
     // Output (x,y) coordinates of the pixel 
     assign o_x_counter = hc;
     assign o_y_counter = vc;
     
endmodule
