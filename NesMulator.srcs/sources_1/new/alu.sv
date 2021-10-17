`timescale 1ns / 1ps
// TODO - move to common file
typedef enum 
{
    ADC,
    INC,
    DEC,
    SBC,
    CMP,
    AND,
    OR,
    EOR,
    ASL,
    ROL,
    ROR,
    LSR
} AluOperation;

`define CARRY_BIT 0
`define ZERO_BIT 1
`define INTERRUPT_BIT 2
`define DECIMAL_BIT 3
`define BREAK_BIT 4
// Unused bit
`define OVERFLOW_BIT 6
`define NEGATIVE_BIT 7


module alu(
    input AluOperation i_operation,
    input wire[ 7:0 ] i_status,
    input wire[ 7:0 ] i_a,
    input wire[ 7:0 ] i_b,
    output logic[ 7:0 ] o_result,
    output logic[ 7:0 ] o_status
    );

always_comb
begin
    o_status = i_status;
    case( i_operation )
        ADC:
        begin
            // TODO - possibly use { o_status[ `CARRY_BIT ], o_result } = i_a + i_b + i_status[ `CARRY_BIT ];
            o_result = i_a + i_b + i_status[ `CARRY_BIT ];
            o_status[ `CARRY_BIT ] = ( i_a[ 7 ] | i_b[ 7 ] ) & ~o_result[ 7 ];
            o_status[ `ZERO_BIT ] = ( o_result == 0 );
            o_status[ `NEGATIVE_BIT ] = o_result[ 7 ];
            o_status[ `OVERFLOW_BIT ] = ~( i_a[ 7 ] ^ i_b[ 7 ] ) & ( i_a[ 7 ] ^ o_result[ 7 ] );
        end

        INC:
        begin
            o_result = i_a + 1;
            o_status[ `ZERO_BIT ] = ( o_result == 0 );
            o_status[ `NEGATIVE_BIT ] = o_result[ 7 ];
        end

        DEC:
        begin
            o_result = i_a - 1;
            o_status[ `ZERO_BIT ] = ( o_result == 0 );
            o_status[ `NEGATIVE_BIT ] = o_result[ 7 ];
        end

        SBC:
        begin
            
        end

        CMP:
        begin
            
        end

        AND:
        begin
            o_result = i_a & i_b;
            o_status[ `ZERO_BIT ] = ( o_result == 0 );
            o_status[ `NEGATIVE_BIT ] = o_result[ 7 ];
        end

        OR:
        begin
            o_result = i_a | i_b;
            o_status[ `ZERO_BIT ] = ( o_result == 0 );
            o_status[ `NEGATIVE_BIT ] = o_result[ 7 ];
        end

        EOR:
        begin
            o_result = i_a ^ i_b;
            o_status[ `ZERO_BIT ] = ( o_result == 0 );
            o_status[ `NEGATIVE_BIT ] = o_result[ 7 ];
        end

        ASL:
        begin
            o_result = i_a << 1;
            o_status[ `CARRY_BIT ] = ( i_a[ 7 ] );
            o_status[ `ZERO_BIT ] = ( o_result == 0 );
            o_status[ `NEGATIVE_BIT ] = o_result[ 7 ];
        end

        ROL:
        begin
            o_result = i_a << 1;
            o_result[ 0 ] = i_status[ `CARRY_BIT ];
            o_status[ `CARRY_BIT ] = ( i_a[ 7 ] );
            o_status[ `ZERO_BIT ] = ( o_result == 0 );
            o_status[ `NEGATIVE_BIT ] = o_result[ 7 ];
        end

        ROR:
        begin
            o_result = i_a >> 1;
            o_result[ 7 ] = i_status[ `CARRY_BIT ];
            o_status[ `CARRY_BIT ] = ( i_a[ 0 ] );
            o_status[ `ZERO_BIT ] = ( o_result == 0 );
            o_status[ `NEGATIVE_BIT ] = o_result[ 7 ];
        end

        LSR:
        begin
            o_result = i_a >> 1;
            o_status[ `CARRY_BIT ] = ( i_a[ 0 ] );
            o_status[ `ZERO_BIT ] = ( o_result == 0 );
            o_status[ `NEGATIVE_BIT ] = o_result[ 7 ];
        end
        
    endcase
end

endmodule
