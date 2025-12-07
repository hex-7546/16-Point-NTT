module ntt_top(
    input wire clk,           // 100MHz clock
    input wire rst,           // Reset button (active high)
    output wire uart_tx,      // UART TX to PC
    output wire [1:0] led     // LED0 and LED1
);

    // State machine
    localparam IDLE = 0, COMPUTE = 1, TRANSMIT = 2, DONE = 3, PAUSE = 4;
    reg [2:0] state = IDLE;
    
    // NTT signals
    reg ntt_start = 0;
    wire ntt_done;
    wire [6:0] ntt_out [0:15];  // 16 outputs, each 7-bit (max value 96 for q=97)
    
    // UART signals
    reg [7:0] uart_data = 0;
    reg uart_start = 0;
    wire uart_busy;
    
    // LED blink control
    reg [25:0] blink_counter = 0;
    reg [3:0] blink_state = 0;
    
    // Transmission control
    reg [7:0] tx_index = 0;
    reg [3:0] digit_index = 0;
    reg [3:0] tx_state = 0;
    reg [15:0] delay_counter = 0;
    reg waiting = 0;
    
    // Pause counter for delay between runs
    reg [27:0] pause_counter = 0;
    
    // NTT instance
    ntt_16point ntt_inst(
        .clk(clk),
        .rst(rst),
        .start(ntt_start),
        .done(ntt_done),
        .result_0(ntt_out[0]),
        .result_1(ntt_out[1]),
        .result_2(ntt_out[2]),
        .result_3(ntt_out[3]),
        .result_4(ntt_out[4]),
        .result_5(ntt_out[5]),
        .result_6(ntt_out[6]),
        .result_7(ntt_out[7]),
        .result_8(ntt_out[8]),
        .result_9(ntt_out[9]),
        .result_10(ntt_out[10]),
        .result_11(ntt_out[11]),
        .result_12(ntt_out[12]),
        .result_13(ntt_out[13]),
        .result_14(ntt_out[14]),
        .result_15(ntt_out[15])
    );
    
    // UART transmitter instance
    uart_tx uart_inst(
        .clk(clk),
        .rst(rst),
        .tx_data(uart_data),
        .tx_start(uart_start),
        .tx(uart_tx),
        .busy(uart_busy)
    );
    
    // Assign LEDs based on state
    assign led[0] = (state == COMPUTE || state == TRANSMIT) && (blink_state == 1 || blink_state == 3);
    assign led[1] = (state == DONE || state == PAUSE) && (blink_state == 1 || blink_state == 3);
    
    // Helper function to convert number to ASCII digit
    function [7:0] to_ascii;
        input [3:0] digit;
        begin
            to_ascii = 8'd48 + digit;  // '0' = 48
        end
    endfunction
    
    // Main state machine - COMBINED to avoid multiple drivers
    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            ntt_start <= 0;
            uart_start <= 0;
            tx_index <= 0;
            tx_state <= 0;
            blink_counter <= 0;
            blink_state <= 0;
            delay_counter <= 0;
            waiting <= 0;
            pause_counter <= 0;
        end else begin
            uart_start <= 0;  // Default
            
            // LED blink counter (always running)
            blink_counter <= blink_counter + 1;
            if (blink_counter == 26'd10_000_000) begin
                blink_counter <= 0;
                if (state == COMPUTE || state == TRANSMIT) begin
                    if (blink_state < 4) blink_state <= blink_state + 1;
                end else if (state == DONE || state == PAUSE) begin
                    if (blink_state < 4) blink_state <= blink_state + 1;
                    else blink_state <= 0;  // Reset for continuous blinking
                end
            end
            
            // State machine logic
            case (state)
                IDLE: begin
                    ntt_start <= 1;
                    state <= COMPUTE;
                    blink_state <= 0;
                end
                
                COMPUTE: begin
                    ntt_start <= 0;
                    if (ntt_done) begin
                        state <= TRANSMIT;
                        tx_index <= 0;
                        tx_state <= 0;
                        digit_index <= 0;
                    end
                end
                
                TRANSMIT: begin
                    if (waiting) begin
                        // Wait for UART to complete and add delay
                        delay_counter <= delay_counter + 1;
                        if (delay_counter >= 16'd10000) begin  // Longer delay between chars
                            delay_counter <= 0;
                            waiting <= 0;
                        end
                    end else if (!uart_busy && !uart_start) begin
                        case (tx_state)
                            0: begin  // Send header
                                case (tx_index)
                                    0: uart_data <= "=";
                                    1: uart_data <= "=";
                                    2: uart_data <= "=";
                                    3: uart_data <= "=";
                                    4: uart_data <= "=";
                                    5: uart_data <= "\n";
                                endcase
                                uart_start <= 1;
                                waiting <= 1;
                                tx_index <= tx_index + 1;
                                if (tx_index == 5) begin
                                    tx_index <= 0;
                                    tx_state <= 1;
                                end
                            end
                            
                            1: begin  // Send "16-Point NTT Result:"
                                case (tx_index)
                                    0: uart_data <= "N";
                                    1: uart_data <= "T";
                                    2: uart_data <= "T";
                                    3: uart_data <= " ";
                                    4: uart_data <= "R";
                                    5: uart_data <= "e";
                                    6: uart_data <= "s";
                                    7: uart_data <= "u";
                                    8: uart_data <= "l";
                                    9: uart_data <= "t";
                                    10: uart_data <= "\n";
                                endcase
                                uart_start <= 1;
                                waiting <= 1;
                                tx_index <= tx_index + 1;
                                if (tx_index == 10) begin
                                    tx_index <= 0;
                                    tx_state <= 2;
                                end
                            end
                            
                            2: begin  // Send each result on new line
                                if (digit_index == 0) begin
                                    // Send tens digit
                                    uart_data <= to_ascii(ntt_out[tx_index] / 10);
                                    uart_start <= 1;
                                    waiting <= 1;
                                    digit_index <= 1;
                                end else if (digit_index == 1) begin
                                    // Send ones digit
                                    uart_data <= to_ascii(ntt_out[tx_index] % 10);
                                    uart_start <= 1;
                                    waiting <= 1;
                                    digit_index <= 2;
                                end else if (digit_index == 2) begin
                                    uart_data <= " ";
                                    uart_start <= 1;
                                    waiting <= 1;
                                    if (tx_index < 15) begin
                                        tx_index <= tx_index + 1;
                                        digit_index <= 0;
                                    end else begin
                                        tx_index <= 0;
                                        tx_state <= 3;
                                        digit_index <= 0;
                                    end
                                end
                            end
                            
                            3: begin  // Send success message
                                case (tx_index)
                                    0: uart_data <= "\n";
                                    1: uart_data <= "S";
                                    2: uart_data <= "U";
                                    3: uart_data <= "C";
                                    4: uart_data <= "C";
                                    5: uart_data <= "E";
                                    6: uart_data <= "S";
                                    7: uart_data <= "S";
                                    8: uart_data <= "\n";
                                    9: uart_data <= "=";
                                    10: uart_data <= "=";
                                    11: uart_data <= "=";
                                    12: uart_data <= "=";
                                    13: uart_data <= "=";
                                    14: uart_data <= "\n";
                                    15: uart_data <= "\n";
                                endcase
                                uart_start <= 1;
                                waiting <= 1;
                                tx_index <= tx_index + 1;
                                if (tx_index == 15) begin
                                    state <= DONE;
                                    blink_state <= 0;
                                end
                            end
                        endcase
                    end
                end
                
                DONE: begin
                    // Wait for LED blinks to complete
                    if (blink_state == 4) begin
                        state <= PAUSE;
                        pause_counter <= 0;
                    end
                end
                
                PAUSE: begin
                    // Long pause (3 seconds) before restarting
                    pause_counter <= pause_counter + 1;
                    if (pause_counter >= 28'd300_000_000) begin
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule