`timescale 1ns / 1ps
`default_nettype none

/*
 *  Creates SCCB serial protocol in order to write data 
 *  to OV7670 registers for configuring pixel output 
 *  
 */
 
module sccb_master
#(parameter CLK_F = 100_000_000,
    parameter SCCB_F = 400_000)
    (   input wire          i_clk,
        input wire          i_rstn,
        
        input wire          i_read,       // I2C Commands. Assume read/write are mutually exclusive
        input wire          i_write,
        input wire          i_start,
        input wire          i_restart,
        input wire          i_stop,
        
        input wire   [7:0]  i_din,
        input wire   [7:0]  i_addr, 
        
        output wire  [7:0]  o_dout,
        output wire         o_ready,      
        output wire         o_done,       // 1-cycle tick when a transaction is completed 
        output wire         o_ack,       
        
        inout  wire         io_sda,      
        output wire         o_scl
     );
     
    // Camera Address for writing  
    localparam CAM_ADDR = 7'h21;
    
    // FSM States
    localparam [3:0] IDLE      = 0,
                     START_1   = 1,
                     START_2   = 2,
                     WAIT      = 3,
                     DATA_1    = 4,
                     DATA_2    = 5,
                     DATA_3    = 6,
                     DATA_4    = 7,
                     DATA_DONE = 8,
                     RESTART   = 9, 
                     END_1     = 10,
                     END_2     = 11;
                     
    // CLK_F/SCCB_F is number of clocks in ONE period of the SCCB clock (SCL)                   
    localparam TIMER_WIDTH = $clog2(CLK_F/SCCB_F); 
    localparam HALF        = CLK_F/(2*SCCB_F);
    localparam QUARTER     = HALF/2;
                      
    reg [TIMER_WIDTH - 1: 0] timer;
    reg [3:0]                state;
    reg [8:0]                r_data_bit_index;
    reg [8:0]                r_tx;
    reg [8:0]                r_rx; 
    reg [7:0]                r_latched_data, r_latched_addr;
    reg [1:0]                r_byte_index;
    reg                      data_state;
    wire                     i_sda;
    
    reg r_done;
    reg r_ready;
       
    // Buffer SCL and SDA lines 
    reg r_scl, r2_scl;
    reg r_sda, r2_en_sda;                 
    
    // Register read/write inputs
    reg r_read;
    reg r_write;
    
   initial begin
        state       = IDLE;
        r_ready     = 1'b1;
        r_scl       = 1'b1; 
        r_sda       = 1'b1;
        r2_scl      = 1'b1;
        r2_en_sda   = 1'b1; 
        r_done      = 1'b0; 
   end
            
    always @(posedge i_clk or negedge i_rstn)
        begin
            if(!i_rstn) begin
                r2_scl    <= 1'b1;
                r2_en_sda <= 1'b1;
            end
            else begin
                r2_scl    <= r_scl;
                r2_en_sda <= r_sda;
            end 
        end 
        
    always @(posedge i_clk)
        begin
            r_read  <= i_read;
            r_write <= i_write;
        end
        
    // 2-Wire SCCB bus lines
    assign i_sda  = (data_state && r_read) || (data_state && r_write && r_data_bit_index == 8);
    assign o_scl  = (r2_scl)             ? 1'bZ : 1'b0; 
    assign io_sda = (i_sda || r2_en_sda) ? 1'bZ : 1'b0;
    
    
    // State Machine 
    always @(posedge i_clk)
        begin
            timer <= timer + 1'b1;              // Free Running Counter
            case(state)
                IDLE: begin                     // SDA and SCL line high; Wait for start command
                    timer            <= 0;
                    r_ready          <= 1'b1;
                    r_done           <= 1'b0;
                    data_state       <= 1'b0;
                    r_data_bit_index <= 9'b0;
                    r_byte_index     <= 2'b0;
                    r_scl            <= 1'b1; 
                    r_sda            <= 1'b1;
                    r_latched_data   <= 8'hZZ;
                    r_latched_addr   <= 8'hZZ;
                    if(i_start) begin
                            state      <= START_1;
                            timer      <= 0;
                            r_latched_data <= i_din; 
                            r_latched_addr <= i_addr; 
                            r_ready    <= 1'b0; 
                        end
                    end
                START_1: begin    // Bring SDA line low; Wait for 1/2 period of SCL
                    r_sda       <= 1'b0;
                    if(timer == (HALF-1)) begin
                        timer <= 0; 
                        state <= START_2;
                    end
                end
                START_2: begin    // Bring SCL line low; Wait for 1/2 period of SCL
                    r_scl   <= 1'b0; 
                    if(timer == (HALF-1)) begin
                        timer        <= 0;
                        state        <= WAIT; 
                    end
                end
                WAIT:   begin     // Both SCL/SDA low; Wait for Control Signal (Read or Write)
                    r_scl            <= 1'b0;
                    r_sda            <= 1'b0;
                    timer            <= 0;
                    r_data_bit_index <= 0;
                    r_byte_index     <=  r_byte_index + 1'b1;
                    state            <= (r_byte_index == 3) ? END_1 : DATA_1;
                    case(r_byte_index)                                  // 3-Phase Write Cycle (no ack in SCCB)
                       2'b00: r_tx <= {CAM_ADDR, ~i_write, 1'b1};       //   byte1 = {SLAVE ADDRESS, WR BIT, Don't Care Bit}      
                       2'b01: r_tx <= {r_latched_addr, 1'b1};           //   byte2 = {Register Addr,         Don't Care Bit} 
                       2'b10: r_tx <= {r_latched_data, 1'b1};           //   byte3 = {Data to Register,      Don't Care Bit} 
                       default: r_tx <= {r_latched_data, 1'b1}; 
                    endcase
                    
                    if((!i_write) && (!i_read)) begin
                        if(i_stop)                      state <= END_1; 
                        else if(i_restart || i_start)   state <= RESTART;
                        else                            state <= IDLE; 
                    end
                end 
                DATA_1: begin   // Load Data Bit to SDA before sampled by SCL
                    r_sda       <= r_tx[8]; 
                    r_scl       <= 1'b0; 
                    data_state  <= 1'b1;
                    if(timer == (QUARTER-1)) begin
                        timer <= 0;
                        state <= DATA_2; 
                    end
                end
                DATA_2: begin   // SCL Samples the Data Bit (Shift in for read/Shift out for write)
                    r_sda <= r_tx[8];
                    r_scl <= 1'b1; 
                    // Sample read bits in the middle of SCL being HIGH for sample reads
                    if(timer == (QUARTER-1)) begin      
                        timer <= 0; 
                        state <= DATA_3;
                        r_rx  <= {r_rx[7:0], io_sda};   
                    end
                end 
                DATA_3: begin   // Wait another quarter SCL cycle of it being HIGH
                    r_sda <= r_tx[8];
                    r_scl <= 1'b1; 
                    if(timer == (QUARTER-1)) begin
                        timer <= 0; 
                        state <= DATA_4;  // Shift Data In
                    end
                end
                DATA_4: begin   // Bring SCL Low again; Wait another quarter of a cycle
                    r_sda       <= r_tx[8];
                    r_scl       <= 1'b0; 
                    if(timer == (QUARTER-1)) begin
                        timer <= 0;
                        if(r_data_bit_index == 8) begin
                            state      <= DATA_DONE;
                            r_done     <= 1'b1;     // Set done signal HIGH
                            data_state <= 1'b0;
                        end
                        else begin
                            r_tx             <=  {r_tx[7:0], 1'b0};
                            r_data_bit_index <=  r_data_bit_index + 1'b1;
                            state            <=  DATA_1;
                        end
                    end
                end
                DATA_DONE: begin
                    r_done <= 1'b0;     // Set done signal LOW since it's a tick
                    r_sda  <= 1'b0;
                    r_scl  <= 1'b0;
                    if(timer == (QUARTER-1)) begin
                        timer <= 0;
                        state <= WAIT;
                    end
                end
                RESTART: begin
                    if(timer == (HALF-1)) begin
                        timer <= 0;
                        state <= START_1;
                    end
                end
                END_1: begin
                    // SCL low, SDA low,        SCL high, SDA high
                    // [ Done in WAIT state]
                    r_scl <= 1'b1;
                    r_sda <= 1'b0; 
                    if(timer == (HALF-1)) begin
                        timer <= 0;
                        state <= END_2;
                    end
                end
                END_2: begin
                    r_scl <= 1'b1;
                    r_sda <= 1'b1;
                    if(timer == (HALF-1)) begin
                        timer <= 0;
                        state <= IDLE;
                    end
                end     
            endcase 
        end 

    // Assign Output from SCCBA Reads ( don't read ACK bit )
    assign o_dout = r_rx[8:1]; 
    // ACK (from slave in writes should be '0')
    assign o_ack = r_rx[0]; 
    
    // Assign I2C Master Status Signals  
    assign o_ready = r_ready;  
    assign o_done  = r_done; 
       
endmodule 
