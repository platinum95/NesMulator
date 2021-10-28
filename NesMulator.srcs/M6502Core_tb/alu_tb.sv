`timescale 1ns / 1ps

//`include "../../sources_1/new/M6502Defs.sv"
import M6502Defs::AluOperation;
import M6502Defs::StatusBits;

class AluStimulusGenerator;
    static AluOperation currentOperation = AluOperation_ADC;
    static logic[ 7:0 ] a = 0;
    static logic[ 7:0 ] b = 0;
    static logic[ 7:0 ] status = 0;

    function TickStimulus();
        if ( a == 8'hFF && b == 8'hFF && status == 8'hFF)
        begin
            $display( "** COMPLETED VALIDATION OF ALU OPERATION %0s **", currentOperation.name() );
            if ( currentOperation == AluOperation_LSR )
            begin
                $display( "** VALIDATION OF ALU COMPLETE **" );
                return 1'b0;
                $finish;
            end
            else
            begin
                $cast( currentOperation, currentOperation + 1 );
                a = 8'b0;
                b = 8'b0;
                status = 8'b0;
                $display( "** STARTING VALIDATION OF ALU OPERATION %0s **", currentOperation.name() );
                return 1'b1;
            end
        end
        else
        begin
            { b, a, status } = { b, a, status } + 1;
            return 1'b1;
        end
    endfunction

endclass

class ResultVerifier;
    function string GetStatusString( logic[ 7:0 ] status );
        return $sformatf ( "%s%s_%s%s%s%s%s",
            ( status[ NEGATIVE_BIT ] ? "N" : "n" ),
            ( status[ OVERFLOW_BIT ] ? "V" : "v" ),
            ( status[ BREAK_BIT ] ? "B" : "b" ),
            ( status[ DECIMAL_BIT ] ? "D" : "d" ),
            ( status[ INTERRUPT_BIT ] ? "I" : "i" ),
            ( status[ ZERO_BIT ] ? "Z" : "z" ),
            ( status[ CARRY_BIT ] ? "C" : "c" )
        );
    endfunction

    function VerifyResult( AluStimulusGenerator generator, logic[ 7:0 ] result, logic[ 7:0 ] resultantStatus );
        int b_a = signed'( generator.a );
        int b_b = signed'( generator.b );
        logic[ 7:0 ] expectedStatus = generator.status;

        case ( generator.currentOperation )
            AluOperation_ADC:
            begin
                byte expectedResultSigned = b_a + b_b + ( generator.status[ CARRY_BIT ] ? 1 : 0 );
                shortint unsigned expectedResultUnsigned = generator.a + generator.b + ( generator.status[ CARRY_BIT ] ? 1 : 0 );

                expectedStatus[ CARRY_BIT ] = expectedResultUnsigned[ 8 ];
                expectedStatus[ ZERO_BIT ] = ( expectedResultSigned == 0 );
                expectedStatus[ NEGATIVE_BIT ] = expectedResultSigned < 0 ? 1'b1 : 1'b0;
                expectedStatus[ OVERFLOW_BIT ] = ( b_a < 0 && b_b < 0 && expectedResultSigned >= 0 ) || ( b_a >= 0 && b_b >= 0 && expectedResultSigned < 0 );

                if ( result != expectedResultSigned || ( resultantStatus != expectedStatus ) )
                begin
                    $display( "Verifier error: 0x%0X + 0x%0X + %s: expected 0x%0X, got 0x%0X. Expected status %s, got %s",
                        generator.a,
                        generator.b,
                        ( generator.status[ CARRY_BIT ] ? "1" : "0" ),
                        expectedResultSigned,
                        result,
                        GetStatusString( expectedStatus ),
                        GetStatusString( resultantStatus )
                    );
                    return 1'b0;
                end
                return 1'b1;
            end

            AluOperation_SBC:
            begin
                byte expectedResultSigned = b_a - ( b_b + ( generator.status[ CARRY_BIT ] ? 0 : 1 ) );
                logic[ 7:0 ] invertedB = ~generator.b;
                shortint unsigned expectedResultUnsigned = generator.a + invertedB + ( generator.status[ CARRY_BIT ] ? 1 : 0 ); // TODO - this should be more abstract
                
                expectedStatus[ CARRY_BIT ] = expectedResultUnsigned[ 8 ];
                expectedStatus[ ZERO_BIT ] = ( expectedResultSigned == 0 );
                expectedStatus[ NEGATIVE_BIT ] = expectedResultSigned < 0 ? 1'b1 : 1'b0;
                expectedStatus[ OVERFLOW_BIT ] = ( b_a < 0 && b_b >= 0 && expectedResultSigned >= 0 ) || ( b_a >= 0 && b_b < 0 && expectedResultSigned < 0 );

                if ( result != expectedResultSigned || ( resultantStatus != expectedStatus ) )
                begin
                    $display( "Verifier error: 0x%0X - 0x%0X - %s: expected 0x%0X, got 0x%0X. Expected status %s, got %s",
                        generator.a,
                        generator.b,
                        ( generator.status[ CARRY_BIT ] ? "0" : "1" ),
                        expectedResultUnsigned,
                        result,
                        GetStatusString( expectedStatus ),
                        GetStatusString( resultantStatus )
                    );
                    return 1'b0;
                end
                return 1'b1;
            end

            AluOperation_CMP:
            begin
                logic[ 7:0 ] res = generator.a - generator.b; // TODO - maybe more abstract
                expectedStatus[ CARRY_BIT ] = generator.a >= generator.b;
                expectedStatus[ ZERO_BIT ] = generator.a == generator.b;
                expectedStatus[ NEGATIVE_BIT ] = res[ 7 ];
                if ( resultantStatus != expectedStatus )
                begin
                    $display( "Verifier error: 0x%0X <==> 0x%0X: Expected status %s, got %s",
                        generator.a,
                        generator.b,
                        GetStatusString( expectedStatus ),
                        GetStatusString( resultantStatus )
                    );
                    return 1'b0;
                end
                return 1'b1;
            end

            AluOperation_AND:
            begin
                logic [ 7:0 ] expectedResult = generator.a & generator.b;
                expectedStatus[ NEGATIVE_BIT ] = expectedResult[ 7 ];
                expectedStatus[ ZERO_BIT ] = ( expectedResult == 0 );

                if ( expectedResult != result || resultantStatus != expectedStatus )
                begin
                    $display( "Verifier error: 0x%0X & 0x%0X, expected %0X, got %0X. Expected status %s, got %s",
                        generator.a,
                        generator.b,
                        expectedResult,
                        result,
                        GetStatusString( expectedStatus ),
                        GetStatusString( resultantStatus )
                    );
                    return 1'b0;
                end
                return 1'b1;
            end

            AluOperation_OR:
            begin
                logic[ 7:0 ] expectedResult = generator.a | generator.b;
                expectedStatus[ NEGATIVE_BIT ] = expectedResult[ 7 ];
                expectedStatus[ ZERO_BIT ] = ( expectedResult == 0 );

                if ( expectedResult != result || resultantStatus != expectedStatus )
                begin
                    $display( "Verifier error: 0x%0X | 0x%0X, expected %0X, got %0X. Expected status %s, got %s",
                        generator.a,
                        generator.b,
                        expectedResult,
                        result,
                        GetStatusString( expectedStatus ),
                        GetStatusString( resultantStatus )
                    );
                    return 1'b0;
                end
                return 1'b1;
            end

            AluOperation_EOR:
            begin
                logic[ 7:0 ] expectedResult = generator.a ^ generator.b;
                expectedStatus[ NEGATIVE_BIT ] = expectedResult[ 7 ];
                expectedStatus[ ZERO_BIT ] = ( expectedResult == 0 );

                if ( expectedResult != result || resultantStatus != expectedStatus )
                begin
                    $display( "Verifier error: 0x%0X ^ 0x%0X, expected %0X, got %0X. Expected status %s, got %s",
                        generator.a,
                        generator.b,
                        expectedResult,
                        result,
                        GetStatusString( expectedStatus ),
                        GetStatusString( resultantStatus )
                    );
                    return 1'b0;
                end
                return 1'b1;
            end

            AluOperation_INC:
            begin
                logic[ 7:0 ] expectedResult = generator.a + 8'b1;
                expectedStatus[ NEGATIVE_BIT ] = expectedResult[ 7 ];
                expectedStatus[ ZERO_BIT ] = ( expectedResult == 0 );

                if ( expectedResult != result || resultantStatus != expectedStatus )
                begin
                    $display( "Verifier error: 0x%0X + 1, expected %0X, got %0X. Expected status %s, got %s",
                        generator.a,
                        expectedResult,
                        result,
                        GetStatusString( expectedStatus ),
                        GetStatusString( resultantStatus )
                    );
                    return 1'b0;
                end
                return 1'b1;
            end

            AluOperation_DEC:
            begin
                logic[ 7:0 ] expectedResult = generator.a - 8'b1;
                expectedStatus[ NEGATIVE_BIT ] = expectedResult[ 7 ];
                expectedStatus[ ZERO_BIT ] = ( expectedResult == 0 );

                if ( expectedResult != result || resultantStatus != expectedStatus )
                begin
                    $display( "Verifier error: 0x%0X - 1, expected %0X, got %0X. Expected status %s, got %s",
                        generator.a,
                        expectedResult,
                        result,
                        GetStatusString( expectedStatus ),
                        GetStatusString( resultantStatus )
                    );
                    return 1'b0;
                end
                return 1'b1;
            end

            AluOperation_ASL:
            begin
                logic[ 7:0 ] expectedResult = { generator.a[ 6:0 ], 1'b0 };
                expectedStatus[ CARRY_BIT ] = generator.a[ 7 ];
                expectedStatus[ NEGATIVE_BIT ] = expectedResult[ 7 ];
                expectedStatus[ ZERO_BIT ] = ( expectedResult == 0 );

                if ( expectedResult != result || resultantStatus != expectedStatus )
                begin
                    $display( "Verifier error: 0x%0X << 1, expected %0X, got %0X. Expected status %s, got %s",
                        generator.a,
                        expectedResult,
                        result,
                        GetStatusString( expectedStatus ),
                        GetStatusString( resultantStatus )
                    );
                    return 1'b0;
                end
                return 1'b1;
            end

            AluOperation_ROL:
            begin
                logic[ 7:0 ] expectedResult = { generator.a[ 6:0 ], generator.status[ CARRY_BIT ] };
                expectedStatus[ CARRY_BIT ] = generator.a[ 7 ];
                expectedStatus[ NEGATIVE_BIT ] = expectedResult[ 7 ];
                expectedStatus[ ZERO_BIT ] = ( expectedResult == 0 );

                if ( expectedResult != result || resultantStatus != expectedStatus )
                begin
                    $display( "Verifier error: 0x%0X <<< 1 , expected %0X, got %0X. Expected status %s, got %s",
                        generator.a,
                        expectedResult,
                        result,
                        GetStatusString( expectedStatus ),
                        GetStatusString( resultantStatus )
                    );
                    return 1'b0;
                end
                return 1'b1;
            end

            AluOperation_ROR:
            begin
                logic[ 7:0 ] expectedResult = { generator.status[ CARRY_BIT ], generator.a[ 7:1 ] };
                expectedStatus[ CARRY_BIT ] = generator.a[ 0 ];
                expectedStatus[ NEGATIVE_BIT ] = expectedResult[ 7 ];
                expectedStatus[ ZERO_BIT ] = ( expectedResult == 0 );

                if ( expectedResult != result || resultantStatus != expectedStatus )
                begin
                    $display( "Verifier error: 0x%0X >>> 1, expected %0X, got %0X. Expected status %s, got %s",
                        generator.a,
                        expectedResult,
                        result,
                        GetStatusString( expectedStatus ),
                        GetStatusString( resultantStatus )
                    );
                    return 1'b0;
                end
                return 1'b1;
            end

            AluOperation_LSR:
            begin
                logic[ 7:0 ] expectedResult = { 1'b0, generator.a[ 7:1 ] };
                expectedStatus[ CARRY_BIT ] = generator.a[ 0 ];
                expectedStatus[ NEGATIVE_BIT ] = expectedResult[ 7 ];
                expectedStatus[ ZERO_BIT ] = ( expectedResult == 0 );

                if ( expectedResult != result || resultantStatus != expectedStatus )
                begin
                    $display( "Verifier error: 0x%0X >> 1, expected %0X, got %0X. Expected status %s, got %s",
                        generator.a,
                        generator.b,
                        expectedResult,
                        result,
                        GetStatusString( expectedStatus ),
                        GetStatusString( resultantStatus )
                    );
                    return 1'b0;
                end
                return 1'b1;
            end

        endcase
        return 1'b0;
    endfunction
endclass

module alu_tb;

AluStimulusGenerator stimulusGenerator;
ResultVerifier verifier;

logic[ 7:0 ] result = 0;
logic[ 7:0 ] resultantStatus;

alu m_alu(
    .i_operation( stimulusGenerator.currentOperation ),
    .i_status( stimulusGenerator.status ),
    .i_a( stimulusGenerator.a ),
    .i_b( stimulusGenerator.b ),
    .o_result( result ),
    .o_status( resultantStatus )
    );

initial
begin
    stimulusGenerator = new();
    verifier = new();
    #1;
    do
    begin
        #1;
        if ( !verifier.VerifyResult( stimulusGenerator, result, resultantStatus ) )
        begin
            $display( "Verification failed" );
            $finish;
        end
    end while( stimulusGenerator.TickStimulus() );

    $display( "Verification passed" );
    $finish;
end

endmodule
