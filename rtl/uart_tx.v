module uart_tx(
    input wire clk,           // 100MHz clock
    input wire rst,
    input wire [7:0] tx_data,
    input wire tx_start,
    output reg tx,
    output reg busy
);

    // UART parameters for 115200 baud at 100MHz clock
    // Baud rate = 115200, Clock = 100MHz
    // Divider = 100,000,000 / 115,200 = 868
    localparam CLKS_PER_BIT = 868;
    
    // State machine
    localparam IDLE = 0, START_BIT = 1, DATA_BITS = 2, STOP_BIT = 3;
    
    reg [1:0] state = IDLE;
    reg [9:0] clk_count = 0;
    reg [2:0] bit_index = 0;
    reg [7:0] tx_buffer = 0;
    
    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            tx <= 1;
            busy <= 0;
            clk_count <= 0;
            bit_index <= 0;
        end else begin
            case (state)
                IDLE: begin
                    tx <= 1;  // Idle high
                    busy <= 0;
                    clk_count <= 0;
                    bit_index <= 0;
                    
                    if (tx_start) begin
                        tx_buffer <= tx_data;
                        busy <= 1;
                        state <= START_BIT;
                    end
                end
                
                START_BIT: begin
                    tx <= 0;  // Start bit (low)
                    
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        state <= DATA_BITS;
                    end
                end
                
                DATA_BITS: begin
                    tx <= tx_buffer[bit_index];
                    
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1;
                        end else begin
                            bit_index <= 0;
                            state <= STOP_BIT;
                        end
                    end
                end
                
                STOP_BIT: begin
                    tx <= 1;  // Stop bit (high)
                    
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1;
                    end else begin
                        clk_count <= 0;
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule