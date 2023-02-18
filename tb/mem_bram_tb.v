`timescale 1ns / 1ps

/*
 *  A simple self-checking testbench that verifies
 *  write/read is disabled when i_bram_en is LOW; 
 *  write/read data requires one clock from each 
 *  respective domain; data can be continuously
 *  written and read from the BRAM
 */


module mem_bram_tb();

    // Period (ns) and frequency (Hz) of Write clock
    localparam T_WCLK = 41.67;
    localparam F_WCLK = 24_000_000;
    
    // Period (ns) and frequency (Hz) of Read clock
    localparam T_RCLK = 40; 
    localparam F_RCLK = 25_000_000; 
    
    // mem_bram depth and width
    localparam DEPTH_BRAM = (640*480);
    localparam WIDTH_BRAM = 12;
    
    // mem_bram inputs
    reg                             i_wclk;
    reg                             i_wr;
    reg [$clog2(DEPTH_BRAM)-1:0]    i_wr_addr;
    
    reg                             i_rclk;
    reg                             i_rd;
    reg [$clog2(DEPTH_BRAM)-1:0]    i_rd_addr;
    
    reg                             i_bram_en;
    reg [WIDTH_BRAM-1:0]            i_bram_data;
    
    // mem_bram output
    wire [WIDTH_BRAM-1:0]           o_bram_data;
    
    
    // Instantiate unit under test 
    mem_bram 
    #(  .WIDTH(WIDTH_BRAM           ), 
        .DEPTH(DEPTH_BRAM)          )
    uut
    (
        .i_wclk(i_wclk              ),
        .i_wr(i_wr                  ),
        .i_wr_addr(i_wr_addr        ),
        
        .i_rclk(i_rclk              ), 
        .i_rd(i_rd                  ),
        .i_rd_addr(i_rd_addr        ),
        
        .i_bram_en(i_bram_en        ),
        .i_bram_data(i_bram_data    ), 
        .o_bram_data(o_bram_data    )
    );
    
    // Count errors
    reg [31:0] err_count; 
    
    // Initial conditions before test
    initial
    begin
        err_count = 0; 
    
        i_wclk = 0;
        i_wr = 0; 
        i_wr_addr = 0;
        
        i_rclk = 0;
        i_rd = 0; 
        i_rd_addr = 0; 
        
        i_bram_en = 0; 
        i_bram_data = 0;      
    end 
     
    // Create Write/Read clocks
    always #(T_WCLK/2) i_wclk = ~i_wclk;
    always #(T_RCLK/2) i_rclk = ~i_rclk;   
      
    task OneClockWriteRead(); 
        begin
            #(T_WCLK/2) i_bram_data = $urandom % (1 << WIDTH_BRAM);
                       
            if(o_bram_data == i_bram_data)
            begin
                err_count = err_count + 1'b1; 
                $display("ERROR! BRAM does not have access to data until data is written at write clock.\n"); 
            end               
            
            // Write Data
            @(posedge i_wclk);
            if(o_bram_data == i_bram_data)
            begin
                err_count = err_count + 1'b1; 
                $display("ERROR! BRAM does not have access to data until read clock.\n"); 
            end
            
            @(posedge i_rclk); #1
            if(o_bram_data != i_bram_data)
            begin
                err_count = err_count + 1'b1;
                $display("ERROR! BRAM should have access to data after a write and read clock.\n"); 
            end 
        end 
    endtask
    
       
    // Start testbench
    initial
    begin: TB 
        integer j;
        #(T_RCLK/4) i_rd = 1'b1;
        @(posedge i_rclk);
        @(posedge i_wclk); 
        #(T_WCLK/4) i_wr = 1'b1;
        @(posedge i_wclk) ; 
        
        // Assume that if BRAM is not enabled, but i_wr/i_rd are enabled, 
        // verify no output is read
        for(j = 0; j < 5; j = j + 1)
        begin
                // Write data at negedge of i_wclk
                #(T_WCLK/2) i_bram_data = $urandom % (1 << WIDTH_BRAM);
                @(posedge i_wclk) ; 
                
                // Read data 
                @(posedge i_rclk) ;
                if(o_bram_data == i_bram_data)
                begin
                    err_count = err_count + 1'b1; 
                    $display("ERROR! BRAM cannot read data when module is not enabled.\n"); 
                end               
           end
        
        // BRAM enabled
        @(negedge i_wclk);    
        #(T_WCLK/8) i_bram_en = 1'b1;
        @(posedge i_wclk); 
        
        // Verify that it takes one write clock and read clock to write/read data
        OneClockWriteRead(); 
        
        @(posedge i_wclk);
        
        // Continuously Write and Read Data
        for(j = 0; j < DEPTH_BRAM; j = j + 1)
            begin
                #(T_WCLK/2) i_bram_data = $urandom % (1 << WIDTH_BRAM);
                @(posedge i_wclk); 
                i_wr_addr = i_wr_addr + 1'b1; 
                
                @(posedge i_rclk); 
                i_rd_addr = i_rd_addr + 1'b1; 
                #1
                if(o_bram_data != i_bram_data)
                begin
                    err_count = err_count + 1'b1;
                    $display("ERROR! BRAM read error.\n");
                end
            end 
        
        if(!err_count)
            $display("SUCCESS!");    
            
        $finish(); 
    end 
        
        
endmodule
