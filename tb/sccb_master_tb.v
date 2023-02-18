`timescale 1ns / 1ps

/*
 * A very simple self-checking testbench to verify  
 * a proper 3-Phase write transmission cycle occurs
 * by feeding inputs sccb_addr, sccb_din 
 * and observing the outputs sccb_dout
 */
 
module sccb_master_tb();

    // Period (ns) of 100 MHz FPGA clock
    localparam T_CLK = 10; 
    
    // Period (ns) os 400 kHz SCCB (SIOC) clock
    localparam T_SIOC = 2500; 
    
    // SCCB master inputs
    reg        i_clk = 1'b0; 
    reg        i_rstn;
    reg        sccb_start; 
    reg [7:0]  sccb_addr; 
    reg [7:0]  sccb_din; 
    
    // SCCB master outputs 
    wire [7:0] sccb_dout; 
    wire       sccb_ready; 
    wire       sccb_done; 
    wire       sccb_sda; 
    wire       sccb_scl;
    
    // Holds output data from SCCB master for the 3-Phase Write Cycle 
    reg [7:0] tb_output_data [2:0]; 
      
    // 1st write Cycle for writes = { cam_addr, write bit }
    // 1 is treated as 'Z', since we use the rx shift register
    // to get the output data
    reg [7:0] cam_addr  = { 7'h21, 1'b0 };      // Do NOT change
    reg [7:0] reg_addr;
    reg [7:0] reg_data;
       
    reg [7:0] reg_data_test;  
    reg [7:0] cam_addr_test;
    reg [7:0] reg_addr_test;
    
    // Count the number of errors
    reg [1:0] error_count;
    
    // Instantiate unit under test 
    sccb_master 
    uut
    (
        .i_clk(i_clk         ),
        .i_rstn(i_rstn       ),
        
        // SCCB commands
        .i_read(1'b0         ),       
        .i_write(1'b1        ),
        .i_start(sccb_start  ),
        .i_restart(1'b0      ),
        .i_stop(1'b0         ), 
        
        // Input Data/Address
        .i_din(sccb_din      ),
        .i_addr(sccb_addr    ),
        
        // Output Data 
        .o_dout(sccb_dout    ),
        
        // Output Status Signals
        .o_ready(sccb_ready  ),      
        .o_done(sccb_done    ),      
        .o_ack(              ),                   
        
        // 2-Wire SCCB Lines 
        .io_sda(sccb_sda     ),               
        .o_scl(sccb_scl      )
    );
    
    // Create 100 MHz Clock 
    always 
        begin
            #(T_CLK/2) i_clk = ~i_clk;
        end 
    
    task ApplyReset();
        begin
            i_rstn = 1; 
            #(T_CLK/8)
            i_rstn = 0;
            #(T_CLK/8)
            i_rstn  = 1;
        end 
    endtask
    
    task WriteData(input [7:0] data, input [7:0] addr);
        begin
            @(posedge i_clk);       // Start off write transaction
            # 1; sccb_start <= 1'b1;
            # 1; sccb_din   <= data;
            # 1; sccb_addr  <= addr;
             
            @(posedge i_clk);       
            # 1; sccb_start <= 0;        
            $display("Writing...Addr: 0x%H, Data: 0x%H\n", reg_addr, reg_data);
            
            // 3-Phase Write cycle: 3 writes for one write transaction 
            @(negedge sccb_done);   
            tb_output_data[0] <= sccb_dout;
            @(negedge sccb_done);   
            tb_output_data[1] <= sccb_dout;
            @(negedge sccb_done);   
            tb_output_data[2] <= sccb_dout;

            @(posedge sccb_ready);      // Wait for when the transaction is complete 
        end
    endtask 
                   
  
    initial
        begin: TB
            integer bit; 
            #(T_CLK/8)
            ApplyReset();
            // Generate random 8-bit unsigned register address and register data to be written
            // to camera module
            reg_addr = $urandom % 256;
            reg_data = $urandom % 256; 
            #(T_CLK/4)
            
            // Convert the 1s in the data to be sent into 'Z' so proper error messages
            // can be displayed 
            for(bit = 0; bit < 8; bit = bit + 1)
                begin
                    cam_addr_test[bit] = (cam_addr[bit]) ? 1'bZ : 1'b0; 
                    reg_addr_test[bit] = (reg_addr[bit]) ? 1'bZ : 1'b0;
                    reg_data_test[bit] = (reg_data[bit]) ? 1'bZ : 1'b0; 
                end
                
            // Begin by writing data and see if transmitted data matched
            // read data from uut  
            error_count = 0; 
            WriteData(reg_data, reg_addr);
            $display("Writing Data Done.");
            
            if(tb_output_data[0] !== cam_addr_test)
                begin
                    $display("Error sending camera address: 0x%H\n", cam_addr);
                    error_count = error_count + 1;
                    for(bit = 7; bit >= 0; bit = bit - 1)
                        begin
                            if(tb_output_data[0][bit] !== cam_addr_test[bit])
                                $display("Bit %d should be 1'b%b, but is 1'b%b\n"
                                    , bit, cam_addr_test[bit], tb_output_data[0][bit]); 
                        end 
                end 
            if(tb_output_data[1] !== reg_addr_test)
                begin
                    $display("Error sending reg daddress: 0x%H\n", reg_addr);
                    error_count = error_count + 1;
                    for(bit = 7; bit >= 0; bit = bit - 1)
                        begin
                            if(tb_output_data[1][bit] !== reg_addr_test[bit])
                                $display("Bit %d should be 1'b%b, but is 1'b%b\n"
                                    , bit, reg_addr_test[bit], tb_output_data[1][bit]); 
                        end
                end
            if(tb_output_data[2] !== reg_data_test)
                begin
                    $display("Error sending data: 0x%H\n", reg_data_test);
                    error_count = error_count + 1;
                    for(bit = 7; bit >= 0; bit = bit - 1)
                        begin
                            if(tb_output_data[2][bit] !== reg_data_test[bit])
                                $display("Bit %d should be %X, but is %X\n"
                                    , bit, reg_data_test[bit], tb_output_data[2][bit]); 
                        end 
                end  
            
            if(!error_count)
                $display("SUCCESS!");
            else
                $display("FAIL!"); 
                
            $finish();
        end 
endmodule

