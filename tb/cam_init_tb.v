`timescale 1ns / 1ns

/*
 * A simple self-checking testbench to verify 
 * all ROM is read and sent to SCCB master in
 * order to initialize the camera 
 */

module cam_init_tb();
    
    // Period (ns) and frequency (Hz) of FPGA clock
    localparam T_CLK = 10;
    localparam F_CLK = 100_000_000;
    
    // Period (ns) and frequency (Hz) of SCCB (sioc) clock
    localparam T_SCCB = 2500; 
    localparam F_SCCB = 400_000; 
    
    // cam_init inputs 
    reg i_clk = 1'b0;
    reg i_rstn = 1'b1;
    reg i_cam_start = 1'b0;
    
    // cam_init outputs 
    wire o_siod;
    wire o_sioc;
    wire o_data_done;
    wire o_cam_done;
    wire [7:0] o_SCCB_dout; 
           
    // Instantiate unit under test 
    cam_init
    uut
    (
        .i_clk(i_clk                    ),
        .i_rstn(i_rstn                  ),
        
        // Cam init begin/end signal lines
        .i_cam_init_start(i_cam_start   ),
        .o_cam_init_done(o_cam_done     ),
        
        // SCCB data and clock signal lines
        .o_siod(o_siod                  ),
        .o_sioc(o_sioc                  ),
        
        // 3x one clock pulse assertions of o_data_sent_done 
        // completes a 3-Phase Write Cycle
        .o_data_sent_done(o_data_done   ),
        .o_SCCB_dout(o_SCCB_dout        )
    );
    
    // cam_rom input
    reg  [7:0]  i_rom_addr;
    
    // cam_rom output 
    wire [15:0] o_rom_data;
    
    // Instantiate COM to get access to the cam reg address and 
    // cam reg data to be sent
    cam_rom
    ROM_TB
    (
        .i_clk(i_clk        ),
        .i_rstn(i_rstn      ), 
        .i_addr(i_rom_addr  ), 
        .o_dout(o_rom_data  )
    );
    
    // ROM as is
    reg  [15:0] ROM  [76:0]; 
    initial $readmemh("rom.txt", ROM); 
    
    // Address/Data that should be seen on siod line of SCCB master
    reg [15:0] ROM_Z [76:0];
    reg [7:0] cam_addr = {8'b0Z00_00Z0}; 
    
    // Count number of errors
    reg [31:0] err_count = 0;
    
    // Create 100 MHz clock 
    always #(T_CLK/2) i_clk = ~i_clk;
    
    // Apply negedge reset 
    task ApplyReset(); 
        begin
            i_rstn = 1;
            #(T_CLK/4)
            i_rstn = 0; 
            #(T_CLK/4)
            i_rstn = 1;
        end 
    endtask
    
    // Verify that the bus should be idle until a start signal 
    task BusIDLE();
        begin
            i_cam_start = 1'b0;
            #1; 
            if(o_cam_done)
            begin
                $display("Error! o_cam_done should be 0 when starting cam initialization\n");
                err_count = err_count + 1'b1;
            end 
            if((o_siod === 1'bZ) && ((o_sioc === 1'bZ))) 
                $display("Bus is IDLE.");
            else
            begin 
                $display("Error! Bus isn't 1'bZ when start signal is 1'b0");
                err_count = err_count + 1'b1; 
            end 
        end 
    endtask 

 
    initial
        begin: TB 
            integer ROM_WIDTH, ROM_DEPTH, write_cycle;
            
            // Set $time format in ns
            $timeformat(-9, 1, " ns" );     
            
            // Check that all ROM in rom.txt is the same in cam_rom.v
            for(ROM_DEPTH = 0; ROM_DEPTH < 77; ROM_DEPTH = ROM_DEPTH + 1)
                begin
                    #(T_CLK/8)
                    i_rom_addr = ROM_DEPTH;
                    #(T_CLK/8)
                    repeat (2) @(posedge i_clk) ; 
                    if(o_rom_data != ROM[ROM_DEPTH])
                    begin
                        $display("ERROR! %dth ROM data is 0x%h, but should be 0x%h", 
                            ROM_DEPTH, ROM[ROM_DEPTH], o_rom_data);
                        err_count = err_count + 1'b1;     
                    end 
                end
            
            // Convert "1" in ROM as "Z"
            for(ROM_DEPTH = 0; ROM_DEPTH < 77; ROM_DEPTH = ROM_DEPTH + 1)
                begin
                    for(ROM_WIDTH = 0; ROM_WIDTH < 16; ROM_WIDTH = ROM_WIDTH + 1)
                        begin
                            ROM_Z[ROM_DEPTH][ROM_WIDTH] = (ROM[ROM_DEPTH][ROM_WIDTH]) ? 1'bZ : 1'b0;
                        end  
                end
 
            // Apply Reset
            $display("Applying Reset check at time: %t\n", $time);  
            @(posedge i_clk) ;  
            #1 ApplyReset(); 
            
            // Bus Should remain IDLE without a start signal
            $display("Bus is IDLE check at time: %t\n", $time); 
            @(posedge i_clk) ; 
            #1 BusIDLE(); 
            
            // Check that all ROM is correctly written to SCCB master
            // and it sends the correct data to the camera for intialization
            // Note: (0-76) 1st and 76th ROM data are NOT sent to SCCB master
            
            $display("Read all ROM test at time: %t\n", $time);  
            @(posedge i_clk) ;                  // Start cam initialization
            #1 i_cam_start <= 1'b1; 
            
            for(ROM_DEPTH = 0; ROM_DEPTH < 76; ROM_DEPTH = ROM_DEPTH + 1)
                begin
                    if(ROM_DEPTH != 1)
                    begin
                        $display("Beginning Test for #%d in ROM at time: %t \n.", ROM_DEPTH, $time); 
                        @(negedge o_data_done)              // Negedge indicates a write cycle is complete    
                            if(o_SCCB_dout !== cam_addr)    // 1st write cycle: cam slave address for Writes
                            begin
                                $display("ERROR! %dth ROM_DEPTH Cam address is 8'b%b, but should be 8'b%b.\n",
                                    ROM_DEPTH, o_SCCB_dout, cam_addr);
                                err_count = err_count + 1'b1;
                            end
                        @(negedge o_data_done) 
                            if(o_SCCB_dout !== ROM_Z[ROM_DEPTH][15:8])  // 2nd write cycle: cam reg address
                            begin
                                $display("ERROR! %dth ROM_DEPTH Cam reg address is 8'b%b, but should be 8'b%b\n",
                                ROM_DEPTH, o_SCCB_dout, ROM_Z[ROM_DEPTH][15:8]);
                                err_count = err_count + 1'b1;
                            end 
                        @(negedge o_data_done) 
                            if(o_SCCB_dout !== ROM_Z[ROM_DEPTH][7:0])   // 3rd write cycle: cam data address 
                            begin
                                $display("ERROR! %dth ROM_DEPTH Cam reg data is 8'b%b, but should be 8'b%b\n",
                                ROM_DEPTH, o_SCCB_dout, ROM_Z[ROM_DEPTH][7:0]);
                                err_count = err_count + 1'b1;
                            end
                        
                        // Have to end simulation within for loop or else
                        // simulation will continue to run forever
                        if(ROM_DEPTH == 75)
                            begin
                                $display("Done sending ROM to SCCB master.\n");
                                
                                // Check that the done flag is asserted once reading and sending all ROM
                                @(posedge o_cam_done)
                                    $display("o_cam_done flag asserted.\n");
                                if(!err_count)
                                    $display("SUCCESS!");
                                else
                                    $display("FAIL!");
                                    
                                // Advance one tick to see the o_cam_done flag assertion in simulation
                                @(posedge i_clk) ; 
                                
                                $finish();    // End simulation 
                            end     
                            
                    end
                                                               
                end // for loop
               
        end // testbench

endmodule
