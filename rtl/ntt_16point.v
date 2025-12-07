module ntt_16point(
    input wire clk,
    input wire rst,
    input wire start,
    output reg done,
    output reg [6:0] result_0,
    output reg [6:0] result_1,
    output reg [6:0] result_2,
    output reg [6:0] result_3,
    output reg [6:0] result_4,
    output reg [6:0] result_5,
    output reg [6:0] result_6,
    output reg [6:0] result_7,
    output reg [6:0] result_8,
    output reg [6:0] result_9,
    output reg [6:0] result_10,
    output reg [6:0] result_11,
    output reg [6:0] result_12,
    output reg [6:0] result_13,
    output reg [6:0] result_14,
    output reg [6:0] result_15
);

    // NTT parameters: q = 97, omega = 3 (primitive 16th root of unity mod 97)
    localparam Q = 97;
    
    // Precomputed twiddle factors: omega^k mod 97 for k=0 to 15
    // omega = 3, omega^3 = 27 is the primitive 16th root
    reg [6:0] omega [0:15];
    
    // Input array (hardcoded test vector)
    reg [6:0] input_data [0:15];
    
    // Working array
    reg [6:0] data [0:15];
    
    // Computation state
    reg [3:0] stage = 0;
    reg [4:0] i = 0;
    reg computing = 0;
    
    // Variables for butterfly computation
    reg [3:0] m, k, j;
    reg [6:0] t, u, tw;
    reg [4:0] twiddle_idx;
    
    // Initialize twiddle factors and input data
    initial begin
        // Twiddle factors: powers of omega=27 mod 97
        omega[0] = 1;
        omega[1] = 27;
        omega[2] = 50;
        omega[3] = 41;
        omega[4] = 96;
        omega[5] = 70;
        omega[6] = 47;
        omega[7] = 56;
        omega[8] = 1;
        omega[9] = 27;
        omega[10] = 50;
        omega[11] = 41;
        omega[12] = 96;
        omega[13] = 70;
        omega[14] = 47;
        omega[15] = 56;
        
        // Input test vector: [1, 2, 3, ..., 16]
        input_data[0] = 1;
        input_data[1] = 2;
        input_data[2] = 3;
        input_data[3] = 4;
        input_data[4] = 5;
        input_data[5] = 6;
        input_data[6] = 7;
        input_data[7] = 8;
        input_data[8] = 9;
        input_data[9] = 10;
        input_data[10] = 11;
        input_data[11] = 12;
        input_data[12] = 13;
        input_data[13] = 14;
        input_data[14] = 15;
        input_data[15] = 16;
    end
    
    // Modular multiplication: (a * b) mod 97
    function [6:0] mod_mult;
        input [6:0] a;
        input [6:0] b;
        reg [13:0] temp;
        begin
            temp = a * b;
            mod_mult = temp % Q;
        end
    endfunction
    
    // Modular addition: (a + b) mod 97
    function [6:0] mod_add;
        input [6:0] a;
        input [6:0] b;
        reg [7:0] temp;
        begin
            temp = a + b;
            if (temp >= Q)
                mod_add = temp - Q;
            else
                mod_add = temp[6:0];
        end
    endfunction
    
    // Modular subtraction: (a - b) mod 97
    function [6:0] mod_sub;
        input [6:0] a;
        input [6:0] b;
        reg signed [7:0] temp;
        begin
            temp = a - b;
            if (temp < 0)
                mod_sub = temp + Q;
            else
                mod_sub = temp[6:0];
        end
    endfunction
    
    // Bit-reverse permutation for index
    function [3:0] bit_reverse;
        input [3:0] idx;
        begin
            bit_reverse = {idx[0], idx[1], idx[2], idx[3]};
        end
    endfunction
    
    always @(posedge clk) begin
        if (rst) begin
            done <= 0;
            computing <= 0;
            stage <= 0;
            i <= 0;
        end else begin
            if (start && !computing) begin
                // Initialize: bit-reverse permutation
                data[0] <= input_data[bit_reverse(0)];
                data[1] <= input_data[bit_reverse(1)];
                data[2] <= input_data[bit_reverse(2)];
                data[3] <= input_data[bit_reverse(3)];
                data[4] <= input_data[bit_reverse(4)];
                data[5] <= input_data[bit_reverse(5)];
                data[6] <= input_data[bit_reverse(6)];
                data[7] <= input_data[bit_reverse(7)];
                data[8] <= input_data[bit_reverse(8)];
                data[9] <= input_data[bit_reverse(9)];
                data[10] <= input_data[bit_reverse(10)];
                data[11] <= input_data[bit_reverse(11)];
                data[12] <= input_data[bit_reverse(12)];
                data[13] <= input_data[bit_reverse(13)];
                data[14] <= input_data[bit_reverse(14)];
                data[15] <= input_data[bit_reverse(15)];
                
                computing <= 1;
                done <= 0;
                stage <= 0;
                i <= 0;
            end else if (computing) begin
                // 4 stages of butterfly operations (log2(16) = 4)
                if (stage < 4) begin
                    if (i < 16) begin
                        // Compute butterfly parameters
                        m = 1 << stage;  // Distance between butterfly pairs
                        k = i >> (stage + 1);  // Which group
                        j = i & ((1 << (stage + 1)) - 1);  // Position within group
                        
                        if (j < m) begin
                            // Upper half of butterfly
                            twiddle_idx = (j << (4 - stage - 1)) & 15;
                            tw = omega[twiddle_idx];
                            t = mod_mult(tw, data[i + m]);
                            u = data[i];
                            data[i] <= mod_add(u, t);
                            data[i + m] <= mod_sub(u, t);
                        end
                        
                        i <= i + 1;
                    end else begin
                        i <= 0;
                        stage <= stage + 1;
                    end
                end else begin
                    // Done computing
                    result_0 <= data[0];
                    result_1 <= data[1];
                    result_2 <= data[2];
                    result_3 <= data[3];
                    result_4 <= data[4];
                    result_5 <= data[5];
                    result_6 <= data[6];
                    result_7 <= data[7];
                    result_8 <= data[8];
                    result_9 <= data[9];
                    result_10 <= data[10];
                    result_11 <= data[11];
                    result_12 <= data[12];
                    result_13 <= data[13];
                    result_14 <= data[14];
                    result_15 <= data[15];
                    
                    done <= 1;
                    computing <= 0;
                end
            end
        end
    end

endmodule