`timescale 1ns / 1ps

/*
 * A simple self-checking testbench to verify 
 * that the first frame of data is ignored;
 * data is captured only after the frame starts and
 * i_href is HIGH; o_wr is only asserted once every 
 * two clock cycles (when the 2nd byte is captured);
 * o_pix_addr is only incremented every other clock;
 * o_pix_data successfully captures the 1st and 2nd byte 
 *
 * Roughly simulates the VGA Frame Timing of the OV7670
 * 
 */

module cam_capture_tb();

    // Period (ns) and frequency (Hz) of PCLK
    localparam T_CLK = 41.67;
    localparam F_CLK = 24_000_000;
    
    // Number of rows and columns of VGA interface
    localparam nRows = 480,
                nCols = 640; 
    
    // cam_capture inputs
    reg i_pclk = 1'b0;
    reg i_vsync; 
    reg i_href;
    reg [7:0] i_D;
    reg i_cam_done; 
    
    // cam_capture outputs
    wire [18:0] o_pix_addr;
    wire [11:0] o_pix_data;
    wire o_wr;
    
    
    // Instantiate unit under test 
    cam_capture
    uut
    (
        .i_pclk(i_pclk          ),
        .i_vsync(i_vsync        ),
        .i_href(i_href          ),    
        .i_D(i_D                ),
        .i_cam_done(i_cam_done  ),
        .o_pix_addr(o_pix_addr  ), 
        .o_pix_data(o_pix_data  ),        
        .o_wr(o_wr              )
    ); 
    
    // Count number of errors
    reg [31:0] err_count = 0;
    
    // Pixel Data to be sent in testbench for 2 rows 
    reg [7:0] ROM [(4*nCols) - 1:0]; 
    reg [7:0] ROM_DATA;
    
    wire [18:0] pix_addr = o_pix_addr;
    wire [11:0] pix_data = o_pix_data;
    
    // Create 24 MHz Pixel Clock
    always
        begin
            #(T_CLK/2) i_pclk = ~i_pclk;
        end     

    task FrameStart();
        begin
            #(T_CLK/4) i_vsync = 1;
            @(posedge i_pclk);
            #((3*T_CLK)/4) i_vsync = 0;    
            @(posedge i_pclk);
            
        end 
    endtask
    
    task FrameEnd();
        begin
            #(T_CLK/4) i_vsync = 0;         // Wait T/4 before posedge
            @(posedge i_pclk);
            #((3*T_CLK)/4) i_vsync = 1;     // Wait T*3/4 after posedge to assert
            @(posedge i_pclk); 
        end
    endtask
    
    task DataInvalid();
        begin
            // Expect all outputs are 0
            if(o_wr || o_pix_data || o_pix_addr)
                err_count = err_count + 1'b1;
            
            if(err_count)
                $display("ERROR! Outputs are to remain 0.\n"); 
        end 
    endtask
    
    task WriteData();
        begin: WRITE_ONE_ROW
            integer k;
            for(k = 0; k < nCols; k = k + 1)
                begin
                    if(k % 2 == 0)  // First Byte
                        begin
                            i_D = ROM[k]; #(T_CLK/16)
                            @(posedge i_pclk);
                        end
                    else            // Second Byte
                        begin
                            i_D = ROM[k]; #(T_CLK/16)
                            @(posedge i_pclk) ;
                        end  
                end 
        end 
    endtask
    
    integer i, j;
    initial
        begin: CREATE_ROM
            
            // Create pseudorandom pixel data for two rows
            $display("Starting to create random pixel data for two rows\n"); 
            for(i = 0; i < (4*nCols); i = i + 1)
                begin
                    if(i % 2 == 0)  // First Byte
                        begin
                            ROM_DATA = { 4'bxxxx, $urandom % 16 };
                            ROM[i] = ROM_DATA;
                        end
                    else            // Second Byte
                        begin
                            ROM_DATA = $urandom % 256; 
                            ROM[i] = ROM_DATA;
                        end  
                end 
            $display("Done.\n"); 
        end 
    

    
    initial
        begin: TB
                           
            i_vsync = 0;
            i_href = 0;
            i_D = {8{1'b0}}; 
            i_cam_done = 0;  
            FrameEnd();
            // Verify: data should remain invalid at the first tick of pclk
            @(posedge i_pclk); 
            DataInvalid(); 
            
            // Assume i_cam_done and 1x frame start has occured
            @(negedge i_pclk) 
                i_cam_done = 1'b1;            
            FrameStart();
            
            // Write data for an entire frame
            for(j = 0; j < nRows; j = j + 1)
                for(i = 0; i < nCols; i = i + 1)
                    begin
                        if(i%2 == 0)
                            begin
                                i_D = ROM[i]; #(T_CLK/16)
                                @(posedge i_pclk);
                            end
                        else
                            begin
                                i_D = ROM[i];#(T_CLK/16)
                                @(posedge i_pclk); 
                            end 
                    end 
                
            // Verify: First frame of data is ignored
            DataInvalid();
            FrameEnd();
            
            // Begin a new frame            
            FrameStart(); 
            
            // Assume i_href is LOW and write one row of data
            i_href = 0;
            @(negedge i_pclk) ;
            WriteData(); 
            
            // Verify: Data is ignored after the first frame is ignored and when i_href is 0
            DataInvalid();

            // Assume i_href is HIGH and check that 1st row of data is captured
            @(negedge i_pclk); i_href = 1;
            for(i = 0; i < (2*nCols); i = i+1)
                begin
                    #(T_CLK/4) i_D =  ROM[i]; 
                    @(posedge i_pclk); 
                    #1
                    if((i % 2 == 1))    
                    begin
                        if(!o_wr)
                        begin
                            err_count  = err_count + 1'b1;
                            $display("ERROR! o_wr needs to be asserted once every 2 clocks.\n"); 
                        end
                        if(o_pix_data != { ROM[i-1][3:0], ROM[i] })
                        begin    
                            err_count = err_count + 1'b1;
                            $display("ERROR! o_pix_data not correct.\n"); 
                        end
                        if(o_pix_addr != i/2 + 1)
                        begin
                            err_count = err_count + 1'b1;
                            $display("ERROR! o_pix_addr can only increment once every 2 clocks.\n"); 
                        end
                    end
                end 
                
            // Assume i_href is LOW and check that data does not change
            @(negedge i_pclk); i_href = 0; 
            for(i = 0; i < 5; i = i + 1)
                begin
                    i_D = ROM[i]; #(T_CLK/16)
                    @(posedge i_pclk); #1
                    if(pix_addr != o_pix_addr)
                    begin
                        err_count = err_count + 1'b1;
                        $display("ERROR! o_pix_addr can not change when i_href (between rows, same frame)\n"); 
                    end 
                    if(pix_data != o_pix_data)
                    begin
                        err_count = err_count + 1'b1;
                        $display("ERROR! o_pix_data can not change when i_href (between rows, same frame)\n"); 
                    end 
                end 
            
            // Assume i_href is HIGH and check that the 2nd row of data is captured 
            @(negedge i_pclk); i_href = 1;
            for(i = (2*nCols); i < (4*nCols); i = i+1)
                begin
                    #(T_CLK/4) i_D =  ROM[i]; 
                    @(posedge i_pclk); 
                    #1
                    if((i % 2 == 1))   
                    begin
                        if(!o_wr)
                        begin
                            err_count  = err_count + 1'b1;
                            $display("ERROR! o_wr needs to be asserted once every 2 clocks.\n"); 
                        end
                        if(o_pix_data != { ROM[i-1][3:0], ROM[i] })
                        begin    
                            err_count = err_count + 1'b1;
                            $display("ERROR! o_pix_data not correct.\n"); 
                        end
                        if(o_pix_addr != ((i-2*640)/2 + 1) + 640)
                        begin
                            err_count = err_count + 1'b1;
                            $display("ERROR! o_pix_addr can only increment once every 2 clocks.\n"); 
                        end
                    end
                end 
            
            if(!err_count)
                $display("SUCCESS!"); 
            
            $finish(); 
        end 
        
endmodule
