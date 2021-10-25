`timescale 1ns / 1ps

`include "M6502Defs.sv"

import M6502Defs::*;

module alu(
    input AluOperation i_operation,
    input wire[ 7:0 ] i_status,
    input wire[ 7:0 ] i_a,
    input wire[ 7:0 ] i_b,
    output logic[ 7:0 ] o_result,
    output logic[ 7:0 ] o_status
    );

wire[ 7:0 ] l_adderB = ( i_operation == AluOperation_ADC ) ? i_b : ~i_b;
wire w_c6;
wire[ 6:0 ] l_addLower;
assign { w_c6, l_addLower } = i_a[ 6:0 ] + l_adderB[ 6:0 ] + ( ( i_operation == AluOperation_CMP ) ? 1'b1 : i_status[ CARRY_BIT ] );


always_comb
begin
    o_status = i_status;
    case( i_operation )
        AluOperation_ADC,
        AluOperation_SBC,
        AluOperation_CMP:
        begin
            o_result[ 6:0 ] = l_addLower;
            { o_status[ CARRY_BIT ], o_result[ 7 ] } = i_a[ 7 ] + l_adderB[ 7 ] + w_c6;

            if ( i_operation != AluOperation_CMP )
            begin
                o_status[ OVERFLOW_BIT ] = ( ~i_a[ 7 ] & ~l_adderB[ 7 ] & w_c6 ) | ( i_a[ 7 ] & l_adderB[ 7 ] & ~w_c6 );
            end
        end

        AluOperation_INC: o_result = i_a + 1;
        AluOperation_DEC: o_result = i_a - 1;
        AluOperation_AND: o_result = i_a & i_b;
        AluOperation_OR:  o_result = i_a | i_b;
        AluOperation_EOR: o_result = i_a ^ i_b;

        AluOperation_ASL,
        AluOperation_ROL:
        begin
            o_result = i_a << 1;
            if ( i_operation == AluOperation_ROL )
            begin
                o_result[ 0 ] = i_status[ CARRY_BIT ];
            end

            o_status[ CARRY_BIT ] = ( i_a[ 7 ] );
        end

        AluOperation_LSR,
        AluOperation_ROR:
        begin
            o_result = i_a >> 1;
            if ( i_operation == AluOperation_ROR )
            begin
                o_result[ 7 ] = i_status[ CARRY_BIT ];
            end
            o_status[ CARRY_BIT ] = ( i_a[ 0 ] );

        end
    endcase

    o_status[ ZERO_BIT ] = ( o_result == 0 );
    o_status[ NEGATIVE_BIT ] = o_result[ 7 ];
end

endmodule
