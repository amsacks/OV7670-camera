`timescale 1ns / 1ns

/* 
 *  
 *  Verify that unique pixel data gets stored at unique addresses
 *  Verify that VGA reads through all data
 *  Verify that BRAM does not get full
 */
 
module top_tb();

    // Period (ns) and frequency (Hz) of FPGA clock
    localparam T_SYS_CLK = 10;
    localparam F_SYS_CLK = 100_000_000;
    
    // Period (ns) and frequency (Hz) of VGA Pixel clock
    localparam T_VGA_CLK = 40; 
    localparam F_VGA_CLK = 25_000_000; 
    
    // Period (ns) and frequency (Hz) of PCLK
    localparam T_P_CLK = 41.667;
    localparam F_P_CLK = 24_000_000;

    // Number of clocks for btn debounce
    localparam DELAY = 10; 
    
    // VGA Frame Timing 
    localparam nFrames = 2,
                nRows   = 640,
                nPixelsPerRow = 480;  
    
    
    // top I/O signals
    logic       vga_clk;

    logic       i_top_clk;
    logic       i_top_rst;
    
    logic       i_top_cam_start;
    logic       o_top_cam_done;
    
    logic       i_top_pclk;
    logic [7:0] i_top_pix_byte;
    logic       i_top_pix_vsync;
    logic       i_top_pix_href;
    logic       o_top_reset;
    logic       o_top_pwdn;
    logic       o_top_xclk;
    logic       o_top_siod;
    logic       o_top_sioc; 
    
    logic [3:0] o_top_vga_red,
                o_top_vga_green,
                o_top_vga_blue;
    logic       o_top_vsync;
    logic       o_top_hsync;
    
    
    logic [11:0] pixel_data_queue [$];
    logic [11:0] BRAM_data [$];
    logic [11:0] first_pixel_byte;
    
    logic  [11:0] remove_last_byte; 
      
    // Instantiate unit under test 
    top
    uut
    (   
        .i_top_clk(i_top_clk                ),
        .i_top_rst(i_top_rst                ),
        
        // I/O for cam initalization 
        .i_top_cam_start(i_top_cam_start    ), 
        .o_top_cam_done(o_top_cam_done      ), 
        
        // I/O to cameraInternal Clock
        .i_top_pclk(i_top_pclk              ), 
        .i_top_pix_byte(i_top_pix_byte      ),
        .i_top_pix_vsync(i_top_pix_vsync    ),
        .i_top_pix_href(i_top_pix_href      ),
        .o_top_reset(o_top_reset            ),
        .o_top_pwdn(o_top_pwdn              ),
        .o_top_xclk(o_top_xclk              ),
        .o_top_siod(o_top_siod              ),
        .o_top_sioc(o_top_sioc              ),
        
        // I/O to VGA 
        .o_top_vga_red(o_top_vga_red        ),
        .o_top_vga_green(o_top_vga_green    ),
        .o_top_vga_blue(o_top_vga_blue      ),
        .o_top_vga_vsync(o_top_vsync        ),
        .o_top_vga_hsync(o_top_hsync        )
    );

    initial
        begin
            i_top_clk = 0;
            i_top_pclk= 0;
            vga_clk   = 0; 
            i_top_rst = 0;
            
            i_top_cam_start = 0;
            i_top_pix_vsync = 0;
            i_top_pix_href = 0; 
        end 
    
    // Create Clocks
    always #(T_SYS_CLK/2) i_top_clk = ~i_top_clk; 
    always #(T_VGA_CLK/2) vga_clk   = ~vga_clk;
    always #(T_P_CLK/2)   i_top_pclk= ~i_top_pclk; 
    
    initial
    begin: TB 
        integer frame, row, pix_byte;  
        
        // Sample a '0' from i_top_rst as to pass assertion $fell(uut.top_btn_db.o_btn_db)
        repeat(DELAY+1) @(posedge i_top_clk); 
        
        // Start simulation in known state
        TopResetDb();      
        
        i_top_cam_start = 1'b1; 
        repeat(10) @(posedge i_top_clk);
        
        // Skip initialization (tested in cam_init_tb) and start first frame 
        @(posedge i_top_pclk) 
            force uut.OV7670_cam.o_cam_done = 1'b1; 
        FrameStart(); 
        
        // Pad for first frame - BRAM has a one clock cycle delay for reads
        BRAM_data.push_front( {12'h000} );
        
        /*
            Simulate VGA Frame Timing
            
            http://web.mit.edu/6.111/www/f2016/tools/OV7670_2006.pdf (page 7) 
            
            Note: tline = 784*tpclk
        */
        
        for(frame = 0; frame < nFrames; frame=frame+1)
        begin
            // Start frame to start sending pixel data to BRAM
            FrameStart();  
            
            for(row = 1; row < nRows+1; row=row+1)
            begin
            
                for(pix_byte = 0; pix_byte < (2*nPixelsPerRow); pix_byte=pix_byte+1)
                begin
                    @(negedge i_top_pclk)
                    begin
                        if(pix_byte == 0)                         
                            i_top_pix_href = 1'b1;
                        
                        // First byte
                        if(pix_byte % 2 == 0)                       
                        begin
                            first_pixel_byte = { $urandom() % 4096 }; //row*(pix_byte/2); 
                            i_top_pix_byte   = { 4'hF , first_pixel_byte[11:8] };
                        end
                        // Second byte, add to queue for testing 
                        else
                        begin
                            i_top_pix_byte = first_pixel_byte[7:0];         //{ $urandom() % 256 };              
                            pixel_data_queue.push_front(first_pixel_byte);  // { first_pixel_byte[3:0] , i_top_pix_byte });
                            BRAM_data.push_front(first_pixel_byte);         //{first_pixel_byte[3:0] , i_top_pix_byte } ); 
                        end
                    end       
                      
                end 

                // Invalid Data region (before next row)
                @(negedge i_top_pclk) i_top_pix_href = 0;
                repeat(144*2) @(posedge i_top_pclk); 
            end 
            
            // Remove last data (at address 307200 -> invalid)
            remove_last_byte = BRAM_data.pop_front(); 
                        
            // Last row -> end of frame
            i_top_pix_vsync = 0; 
            repeat(10*784*2) @(negedge i_top_pclk); 
            
            // Pad for next frame 
            BRAM_data.push_front( {12'h000} );
            BRAM_data.push_front( {12'h000} );
            
            // Finish sim
            if(frame == nFrames - 1)
            begin                
                $display("SUCCESS!\n");
                $finish();    
            end    
        end 
        
    end // testbench 
    



    /**
        1st: Top Reset to Multi-clock resets 
    **/ 
    
    // Simulate top rst button debounce 
    task TopResetDb();
    begin
        i_top_rst = 0; 
        @(posedge i_top_clk);
        assert(uut.top_btn_db.i_btn_in == 1'b1);
        
        i_top_rst = 1'b1; 
        repeat(DELAY+1) @(posedge i_top_clk);
        assert(uut.top_btn_db.i_btn_in == 0);
        
        i_top_rst = 0; 
    end
    endtask
    
    // Verify that top rst to mutli-clock reset are asserted/deasserted properly
    property top_rst_db_p;
        @(posedge i_top_clk) $fell(i_top_rst) 
                                |-> $fell(uut.top_btn_db.o_btn_db)
                                ##(DELAY+1) $rose(uut.top_btn_db.o_btn_db);
    endproperty
    top_rst_assert_db_p_chk: assert property(top_rst_db_p)
                                $display("Multi-clock resets pass.\n"); 
                             else
                                $fatal("Multi-clock resets fail.\n"); 
 
    // Verify that negedge multi-clock resets are asserted once top rst debounce samples '1'  
    always @(posedge i_top_clk)
    begin
        if($fell(uut.top_btn_db.o_btn_db))
        begin
            assert(uut.OV7670_cam.i_rstn_clk == 0) 
                $display("100 MHz Multi-clock reset is 0.\n"); 
            else 
                $fatal("100 MHz MultiYou are not receiving the ACK after the addres-clock reset is NOT 0.\n");
        end
    end
    always @(posedge i_top_pclk)
    begin
        if($fell(uut.top_btn_db.o_btn_db))
        begin
            assert(uut.OV7670_cam.i_rstn_pclk == 0) 
                $display("24 MHz Multi-clock reset is 0.\n");
            else
                $fatal("24 MHz Multi-clock reset is NOT 0.\n");
        end
    end
    always @(posedge uut.w_clk25m)
    begin
        if($fell(uut.top_btn_db.o_btn_db))
        begin
            assert(uut.display_interface.i_rstn_clk25m == 0)
                $display("25 MHz Multi-clock reset is 0.\n");
            else
                $fatal("25 MHz Multi-clock reset is NOT 0.\n");
        end 
    end        
     
    /**
        2nd: Verify that pixel data captured gets fed into BRAM
    **/
    
    task FrameStart();    // VGA Timing of OV7670
    begin
        i_top_pix_vsync = 1'b1; 
        repeat(3*784*2) @(posedge i_top_pclk);
        i_top_pix_vsync = 0; 
        repeat(17*784*2) @(posedge i_top_pclk); 
    end
    endtask    
    
    // Check that BRAM gets fed the right data, stop simulation if any error occurs 
    logic [11:0] BRAM_actual_data;
    logic [11:0] BRAM_expected_data;

    always @(posedge i_top_pclk)
    begin
        if($rose(uut.OV7670_cam.o_pix_wr))  
        begin
                BRAM_actual_data   = uut.pixel_memory.i_bram_data;
                BRAM_expected_data = pixel_data_queue.pop_back();
                  
                assert(BRAM_actual_data == BRAM_expected_data)
                    $display("BRAM recieved pixel byte 0x%h\n", BRAM_actual_data);
                else
                    $fatal("BRAM did not recieve pixel byte. Expected Data: 0x%h, Actual Data: 0x%h\n"
                        , BRAM_expected_data, BRAM_actual_data);
        end

    end 

    /**
        3rd: Verify that VGA reads match data written to BRAM
    **/
   
    // Verify that data written to BRAM is read sequentially
    wire [9:0]  VGA_x = uut.display_interface.o_VGA_x;
    wire [9:0]  VGA_y = uut.display_interface.o_VGA_y;
    
    logic [11:0] expected_VGA_read;
    logic [11:0] actual_VGA_read;
    
    always @(posedge uut.w_clk25m)
    begin
        // one clock cycle BRAM delay, shift X to right by 1
        if( (((VGA_x > 0 && VGA_x < 640) && (VGA_y < 480))
            || ((VGA_x == 799) && ((VGA_y == 524) || (VGA_y < 480))))
            && uut.display_interface.r_SM_state == 'd2)
        begin        
            expected_VGA_read   = BRAM_data.pop_back(); 
            actual_VGA_read     = uut.display_interface.i_pix_data;
            assert(actual_VGA_read === expected_VGA_read)
                $display("VGA Pixel Read Byte: 0x%h.\n", actual_VGA_read); 
            else
                $fatal("Expected VGA Pixel Read: 0x%h, Actual VGA Pixel Byte Read: 0x%h\n",
                      expected_VGA_read, actual_VGA_read);
        end
    end 

endmodule
