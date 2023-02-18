`timescale 1ns / 1ps

/*
 * Format: 640 x 480 @ 60 Hz 
 *
 * A simple self-checking testbench to verify 
 * that x and y pixel counters stay within 
 * bounds [0, 800) and [0, 524) respectively; the active frame
 * signal is asserted when x and y counters are [0, 640) and
 * [0, 480) respectively; horiztonal/vertical pulses are HIGH 
 * and LOW as per the VGA timing of the aforementione format 
 *
 */

module vga_driver_tb();

    // Period (ns) and frequency (Hz) of VGA Pixel clock
    localparam T_CLK = 40; 
    localparam F_CLK = 25_000_000; 
    
    // vga_driver timing parameters
    localparam hDisp  = 640; 
    localparam hFp    = 16;
    localparam hPulse = 96;
    localparam hBp    = 48;   
    localparam vDisp  = 480;
    localparam vFp    = 10;   
    localparam vPulse = 2;
    localparam vBp    = 33;
    
    // vga_driver inputs
    reg i_clk;
    reg i_rstn; 
    wire [9:0] o_x_counter;
    wire [9:0] o_y_counter;
    wire o_video;
    wire o_hsync_pulse;
    wire o_vsync_pulse;
     
    // Instantiate unit under test 
    vga_driver
    #(  .hDisp(hDisp),
        .hFp(hFp),
        .hPulse(hPulse),
        .hBp(hBp), 
        .vDisp(vDisp), 
        .vFp(vFp), 
        .vPulse(vPulse), 
        .vBp(vBp))
    uut
    (
        .i_clk(i_clk              ), 
        .i_rstn(i_rstn            ),
         
        .o_x_counter(o_x_counter  ), 
        .o_y_counter(o_y_counter  ), 
        .o_video(o_video          ), 
        .o_hsync(o_hsync_pulse    ),
        .o_vsync(o_vsync_pulse    )
    );
    
    // Count errors
    reg [31:0] err_count = 0; 
    
    // Create VGA Pixel Clock
    initial i_clk = 0; 
    
    always #(T_CLK/2) i_clk = ~i_clk;

    // Apply async negedge reset 
    task ApplyResetn(); 
        begin
            i_rstn = 0;
            #(T_CLK/16)
            i_rstn = 1'b1; 
            #(T_CLK/16)
            i_rstn = 0; 
            #(T_CLK/16)
            i_rstn = 1'b1; 
        end 
    endtask
    
    localparam hTOT = hDisp + hFp + hPulse + hBp;
    localparam vTOT = vDisp + vFp + vPulse + vBp;
    
    localparam hSyncStart   = hDisp + hFp; 
    localparam hSyncEnd     = hDisp + hFp + hPulse;
    
    localparam vSyncStart   = vDisp + vFp;
    localparam vSyncEnd     = vDisp + vFp + vPulse; 
    
    initial
        begin: TB
            integer col, row;
            
            #(T_CLK)
            // Reset regs before testing
            ApplyResetn(); 
            
            
            // Verify the counters stay below total horizontal/vertical width
            for(col = 0; col < vTOT; col = col + 1)
            begin
                repeat(hTOT) @(posedge i_clk); #1
                if(o_x_counter >= hTOT) 
                begin
                    err_count = err_count + 1'b1; 
                    $display("ERROR! o_x_counter is not below total horiz width.\n");
                end
                else if(o_x_counter != 0)
                begin
                    err_count = err_count + 1'b1;
                    $display("ERROR! o_x_counter must be reset to 0 at each new row.\n"); 
                end 
            end 
            
            @(posedge i_clk); #1
            if(o_y_counter >= vTOT)
            begin
                err_count = err_count + 1'b1;
                $display("ERROR! o_y_counter is not below total vert width.\n");
            end
            else if(o_y_counter != 0)
            begin
                err_count = err_count + 1'b1;
                $display("ERROR! o_y_counter must be reset to 0 at each new row.\n"); 
            end  
            
            // Apply reset to start a new test 
            @(posedge i_clk); 
            #(T_CLK/8) ApplyResetn();
            
            for(row = 0; row < vTOT; row = row + 1)
            begin
                for(col = 0; col < hTOT; col = col + 1)
                begin
                    #1 
                    //$display("Row:%d Col:%d\n", row, col); 
                    // Video Active Test
                    if((o_video != 1'b1) 
                        && (col < hDisp) 
                        && (row < vDisp))
                    begin
                        err_count = err_count + 1'b1;
                        $display("ERROR! Video should be active. Row: %d, Col: %d\n", row, col);  
                    end
                    
                    if((o_video != 1'b0)
                        && (col >= hDisp)
                        && (row >= vDisp))
                    begin
                        err_count = err_count + 1'b1;
                        $display("ERROR! Video should not be active.\n"); 
                    end  
                    
                    // Horizontal Pulse Test
                    if((o_hsync_pulse != 1'b1)
                        && (col < hSyncStart))
                    begin
                        err_count = err_count + 1'b1;
                        $display("ERROR! Horiz pulse should be HIGH before %d.\n", hSyncStart+1); 
                    end 
                    
                    if((o_hsync_pulse != 1'b0)
                        && (col >= hSyncStart)
                        && (col < hSyncEnd))
                    begin
                        err_count = err_count + 1'b1;
                        $display("ERROR! Horiz pulse should be LOW at %d and after, but before %d.\n", hSyncStart+1, hSyncEnd+1); 
                    end
                    
                    if((o_hsync_pulse != 1'b1)
                        && (col >= hSyncEnd))
                    begin
                        err_count = err_count + 1'b1;
                        $display("ERROR! Horiz pulse should be HIGH at %d until next frame.\n", hSyncEnd+1); 
                    end
                    
                    // Vertical Pulse Test
                    if((o_vsync_pulse != 1'b1)
                        && (row < vSyncStart))
                    begin
                        err_count = err_count + 1'b1;
                        $display("ERROR! Vert pulse should be HIGH before %d.\n", vSyncStart); 
                    end 
                    
                    if((o_vsync_pulse != 1'b0)
                        && (row >= vSyncStart)
                        && (row < vSyncEnd))
                    begin
                        err_count = err_count + 1'b1;
                        $display("ERROR! Vert pulse should be LOW at %d and after, but before %d.\n", vSyncStart, vSyncEnd); 
                    end
                    
                    if((o_vsync_pulse != 1'b1)
                        && (row >= vSyncEnd))
                    begin
                        err_count = err_count + 1'b1;
                        $display("ERROR! Vert pulse should be HIGH at %d until next frame.\n", vSyncEnd); 
                    end
                    
                    @(posedge i_clk);
                end
            end
            
            // Advance one tick to start new frame
            @(posedge i_clk); #1
            
            if(o_video != 1'b1)
            begin
                err_count = err_count + 1'b1;
                $display("ERROR! Video should become active when new frame starts.\n");
            end 
            
            if(o_hsync_pulse != 1'b1)
            begin
                err_count = err_count + 1'b1;
                $display("ERROR! Horiz pulse should be HIGH at start of new frame.\n");
            end 
            
            if(o_vsync_pulse != 1'b1)
            begin
                err_count = err_count + 1'b1;
                $display("ERROR! Vert pulse should be HIGH at start of new frame.\n"); 
            end 


            if(!err_count)
                $display("SUCCESS!");
                
            $finish(); 
        end 


endmodule
