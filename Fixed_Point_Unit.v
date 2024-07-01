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
    reg [WIDTH - 1 : 0] root;
    reg root_ready;

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

    always @(posedge reset)
    begin
        if (reset) begin
            mul_state <= 3'd0;
            product_ready <= 1'b0;
        end else if (operation == `FPU_MUL) begin
            case (mul_state)
                3'd0: begin // Start LL multiplication
                    multiplierCircuitInput1 <= operand_1[15:0];
                    multiplierCircuitInput2 <= operand_2[15:0];
                    mul_state <= 3'd1;
                end
                3'd1: begin // LL multiplication done, start LH
                    partialProduct1 <= multiplierCircuitResult;
                    multiplierCircuitInput1 <= operand_1[15:0];
                    multiplierCircuitInput2 <= operand_2[31:16];
                    mul_state <= 3'd2;
                end
                3'd2: begin // LH multiplication done, start HL
                    partialProduct2 <= multiplierCircuitResult;
                    multiplierCircuitInput1 <= operand_1[31:16];
                    multiplierCircuitInput2 <= operand_2[15:0];
                    mul_state <= 3'd3;
                end
                3'd3: begin // HL multiplication done, start HH
                    partialProduct3 <= multiplierCircuitResult;
                    multiplierCircuitInput1 <= operand_1[31:16];
                    multiplierCircuitInput2 <= operand_2[31:16];
                    mul_state <= 3'd4;
                end
                3'd4: begin // HH multiplication done, combine results
                    partialProduct4 <= multiplierCircuitResult;
                    product <= {partialProduct4, 32'b0} + {partialProduct3, 16'b0} + {partialProduct2, 16'b0} + partialProduct1;
                    product_ready <= 1'b1;
                    mul_state <= 3'd0;
                end
                default: mul_state <= 3'd0;
            endcase
        end else begin
            mul_state <= 3'd0;
            product_ready <= 1'b0;
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