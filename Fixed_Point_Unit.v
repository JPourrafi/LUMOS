`include "Defines.vh"

module Fixed_Point_Unit 
#(
    parameter WIDTH = 32,
    parameter FBITS = 10
)
(
    input wire clk,
    input wire reset,
    
    input wire [WIDTH - 1 : 0] operand_1,
    input wire [WIDTH - 1 : 0] operand_2,
    
    input wire [ 1 : 0] operation,

    output reg [WIDTH - 1 : 0] result,
    output reg ready
);

    always @(*)
    begin
        case (operation)
            `FPU_ADD    : begin result <= operand_1 + operand_2; ready <= 1; end
            `FPU_SUB    : begin result <= operand_1 - operand_2; ready <= 1; end
            `FPU_MUL    : begin result <= product[WIDTH + FBITS - 1 : FBITS]; ready <= product_ready; end
            `FPU_SQRT   : begin result <= root; ready <= root_ready; end
            default     : begin result <= 'bz; ready <= 0; end
        endcase
    end

    always @(posedge reset)
    begin
        if (reset)  ready = 0;
        else        ready = 'bz;
    end
    // ------------------- //
    // Square Root Circuit //
    // ------------------- //
    // Register declarations
    reg [WIDTH - 1 : 0] root;           // Stores the final square root result
    reg root_ready;                     // Flag indicating when the result is ready
    reg [1 : 0] s_stage;      // Current stage of the square root operation
    reg [1 : 0] next_s_stage; // Next stage of the square root operation
    reg sqrt_start;                     // Flag to start the square root calculation
    reg sqrt_busy;                      // Flag indicating the calculation is in progress
    reg [WIDTH - 1 : 0] op1, op1_next;      // Operand and its next value in the calculation
    reg [WIDTH - 1 : 0] q, q_next;      // Partial result and its next value
    reg [WIDTH + 1 : 0] ac, ac_next;    // Accumulator and its next value
    reg [WIDTH + 1 : 0] test_res;       // Temporary result for comparison

    // Calculate the number of iterationations based on WIDTH and FBITS
    localparam iteration = (WIDTH + FBITS) / 2;     
    reg [4 : 0] i = 0;                  // iterationation counter

    // State machine for controlling the square root operation
    always @(posedge clk) 
    begin
        if (operation == `FPU_SQRT) 
            s_stage <= next_s_stage;
        else begin
            s_stage <= 2'b00;
            root_ready <= 0;
        end
    end 

    // Combinational logic for determining the next stage
    always @(*) 
    begin
        next_s_stage <= 'bz;
        case (s_stage)
            2'b00 : begin sqrt_start <= 0; next_s_stage <= 2'b01; end
            2'b01 : begin sqrt_start <= 1; next_s_stage <= 2'b10; end
            2'b10 : begin sqrt_start <= 0; next_s_stage <= 2'b10; end
        endcase    
    end                             

    // Core square root calculation logic
    always @(*)
    begin
        // Calculate the test result
        test_res = ac - {q, 2'b01};

        if (test_res[WIDTH + 1] == 0) 
        begin
            // If test_res is non-negative, update ac and op1, set least significant bit of q to 1
            {ac_next, op1_next} = {test_res[WIDTH - 1 : 0], op1, 2'b0};
            q_next = {q[WIDTH - 2 : 0], 1'b1};
        end 
        else begin
            // If test_res is negative, shift ac and op1, shift q left
            {ac_next, op1_next} = {ac[WIDTH - 1 : 0], op1, 2'b0};
            q_next = q << 1;
        end
    end

    // Sequential logic for square root calculation
    always @(posedge clk) 
    begin
        if (sqrt_start)
        begin
            // Initialize variables for a new calculation
            sqrt_busy <= 1;
            root_ready <= 0;
            i <= 0;
            q <= 0;
            {ac, op1} <= {{WIDTH{1'b0}}, operand_1, 2'b0};
        end
        else if (sqrt_busy) 
        begin
            if (i == iteration-1) 
            begin
                // Calculation is complete
                sqrt_busy <= 0;
                root_ready <= 1;
                root <= q_next;
            end
            else begin 
                // Proceed to next iterationation
                i <= i + 1;
                op1 <= op1_next;
                ac <= ac_next;
                q <= q_next;
                root_ready <= 0;
            end
        end
    end

        /*
         *  Describe Your Square Root Calculator Circuit Here.
         */

    // ------------------ //
    // Multiplier Circuit //
    // ------------------ //   
    reg [64 - 1 : 0] product;
    reg product_ready;

    reg     [15 : 0] multiplierCircuitInput1;
    reg     [15 : 0] multiplierCircuitInput2;
    wire    [31 : 0] multiplierCircuitResult;

    Multiplier multiplier_circuit
    (
        .operand_1(multiplierCircuitInput1),
        .operand_2(multiplierCircuitInput2),
        .product(multiplierCircuitResult)
    );

    reg     [31 : 0] partialProduct1;
    reg     [31 : 0] partialProduct2;
    reg     [31 : 0] partialProduct3;
    reg     [31 : 0] partialProduct4;
    
    reg[2:0] mul_state;

    always @(posedge clk or posedge reset)
    begin
        if (reset) begin
            product <= 0;
            mul_state <= 0;
            product_ready <= 0;
        end else if (operation == `FPU_MUL) begin
            case (mul_state)
                0: begin // Start LL multiplication
                    multiplierCircuitInput1 <= operand_1[15:0];
                    multiplierCircuitInput2 <= operand_2[15:0];
                    mul_state <= 1;
                end
                1: begin // LL multiplication done, start LH
                    partialProduct1 <= multiplierCircuitResult;
                    multiplierCircuitInput1 <= operand_1[15:0];
                    multiplierCircuitInput2 <= operand_2[31:16];
                    mul_state <= 2;
                end
                2: begin // LH multiplication done, start HL
                    partialProduct2 <= multiplierCircuitResult << 16;
                    multiplierCircuitInput1 <= operand_1[31:16];
                    multiplierCircuitInput2 <= operand_2[15:0];
                    mul_state <= 3;
                end
                3: begin // HL multiplication done, start HH
                    partialProduct3 <= multiplierCircuitResult << 16;
                    multiplierCircuitInput1 <= operand_1[31:16];
                    multiplierCircuitInput2 <= operand_2[31:16];
                    mul_state <= 4;
                end
                4: begin // HH multiplication done, combine results
                    partialProduct4 <= multiplierCircuitResult << 32;
                    mul_state <= 5;
                end
                5: begin 
                    product <= partialProduct4 + partialProduct3 + partialProduct2 + partialProduct1;
                    product_ready <= 1;
                end
                default: mul_state <= 0;
            endcase
        end
    end
        /*
         *  Describe Your 32-bit Multiplier Circuit Here.
         */
         
endmodule

module Multiplier
(
    input wire [15 : 0] operand_1,
    input wire [15 : 0] operand_2,

    output reg [31 : 0] product
);

    always @(*)
    begin
        product <= operand_1 * operand_2;
    end
endmodule