`timescale 1ns / 1ps

`include "M6502Defs.sv"

import M6502Defs::*;

module Opcodec(
    input logic[ 7:0 ] i_opcode,
    output Operation o_operation,
    output AddressingMode o_addressingMode,
    output AccessType o_accessType,
    output Index o_index
);

logic[ 2:0 ] w_a;
logic[ 2:0 ] w_b;
logic[ 1:0 ] w_c;

assign w_a = i_opcode[ 7:5 ];
assign w_b = i_opcode[ 4:2 ];
assign w_c = i_opcode[ 1:0 ];

// Decode addressing mode
always_comb
begin
    o_index = Index_None;
    case ( w_b )
        0:
        begin
            case( w_c )
                2'b00:
                begin
                    if ( w_a >= 4 )
                    begin
                        o_addressingMode = Immediate;
                    end
                    else if ( w_a == 1 )
                    begin
                        o_addressingMode = Absolute;
                    end
                    else
                    begin
                        o_addressingMode = Implied;
                    end
                end
                2'b01:
                begin
                    o_addressingMode = IndexedIndirect;
                    o_index = Index_X;
                end
                2'b10:
                begin
                    o_addressingMode = Immediate;
                end
                2'b11:
                begin
                    // Illegal opcodes
                    o_addressingMode = IndexedIndirect;
                end
            endcase
        end

        1:
        begin
            o_addressingMode = ZeroPage;
        end

        2:
        begin
            if ( w_c[ 0 ] == 0 )
            begin
                o_addressingMode = Implied;
            end
            else
            begin
                o_addressingMode = Immediate;
            end
        end

        3:
        begin
            o_addressingMode = ( w_a == 3 && w_c == 0 ) ? AbsoluteIndirect : Absolute;
        end

        4:
        begin
            if ( w_c[ 0 ] == 0 )
            begin
                o_addressingMode = Relative;
            end
            else
            begin
                o_index = Index_Y;
                o_addressingMode = IndirectIndexed;
            end
        end

        5:
        begin
            o_addressingMode = ZeroPageIndexed;
            if ( w_c >= 2 && ( w_a == 4 || w_a == 5 ) )
            begin
                o_index = Index_Y;
            end
            else
            begin
                o_index = Index_X;
            end
        end

        6:
        begin
            if ( w_c[ 0 ] == 0 )
            begin
                o_addressingMode = Implied;
            end
            else
            begin
                o_addressingMode = AbsoluteIndexed;
                o_index = Index_Y;
            end
        end

        7:
        begin
            o_addressingMode = AbsoluteIndexed;

            if ( w_c >= 2 && ( w_a == 4 || w_a == 5 ) )
            begin
                o_index = Index_Y;
            end
            else
            begin
                o_index = Index_X;
            end
        end
    endcase
end

// Decode operation
always_comb
begin
    unique case( w_c )
        2'b00:
        begin
            o_operation = NOP;

            unique case ( w_b )
                3'd0:
                begin
                    unique case ( w_a )
                        3'd0: o_operation = BRK;
                        3'd1: o_operation = JSR;
                        3'd2: o_operation = RTI;
                        3'd3: o_operation = RTS;
                        3'd4: o_operation = NOP; // TODO
                        3'd5: o_operation = LDY;
                        3'd6: o_operation = CPY;
                        3'd7: o_operation = CPX;
                    endcase
                end
                3'd1:
                begin
                    unique case ( w_a )
                        3'd0: o_operation = NOP; // TODO
                        3'd1: o_operation = BIT;
                        3'd2: o_operation = NOP; // TODO
                        3'd3: o_operation = NOP; // TODO
                        3'd4: o_operation = STY;
                        3'd5: o_operation = LDY;
                        3'd6: o_operation = CPY;
                        3'd7: o_operation = CPX;
                    endcase
                end
                3'd2:
                begin
                    unique case ( w_a )
                        3'd0: o_operation = PHP;
                        3'd1: o_operation = PLP;
                        3'd2: o_operation = PHA;
                        3'd3: o_operation = PLA;
                        3'd4: o_operation = DEY;
                        3'd5: o_operation = TAY;
                        3'd6: o_operation = INY;
                        3'd7: o_operation = INX;
                    endcase
                end
                3'd3:
                begin
                    unique case ( w_a )
                        3'd0: o_operation = NOP; // TODO
                        3'd1: o_operation = BIT;
                        3'd2: o_operation = JMP;
                        3'd3: o_operation = JMP;
                        3'd4: o_operation = STY;
                        3'd5: o_operation = LDY;
                        3'd6: o_operation = CPY;
                        3'd7: o_operation = CPX;
                    endcase
                end
                3'd4:
                begin
                    unique case ( w_a )
                        3'd0: o_operation = BPL;
                        3'd1: o_operation = BMI;
                        3'd2: o_operation = BVC;
                        3'd3: o_operation = BVS;
                        3'd4: o_operation = BCC;
                        3'd5: o_operation = BCS;
                        3'd6: o_operation = BNE;
                        3'd7: o_operation = BEQ;
                    endcase
                end
                3'd5:
                begin
                    unique case ( w_a )
                        3'd0: o_operation = NOP; // TODO
                        3'd1: o_operation = NOP; // TODO
                        3'd2: o_operation = NOP; // TODO
                        3'd3: o_operation = NOP; // TODO
                        3'd4: o_operation = STY;
                        3'd5: o_operation = LDY;
                        3'd6: o_operation = NOP; // TODO
                        3'd7: o_operation = NOP; // TODO
                    endcase
                end
                3'd6:
                begin
                    unique case ( w_a )
                        3'd0: o_operation = CLC;
                        3'd1: o_operation = SEC;
                        3'd2: o_operation = CLI;
                        3'd3: o_operation = SEI;
                        3'd4: o_operation = TYA;
                        3'd5: o_operation = CLV;
                        3'd6: o_operation = CLD;
                        3'd7: o_operation = SED;
                    endcase
                end
                3'd7:
                begin
                    unique case ( w_a )
                        3'd0: o_operation = NOP; // TODO
                        3'd1: o_operation = NOP; // TODO
                        3'd2: o_operation = NOP; // TODO
                        3'd3: o_operation = NOP; // TODO
                        3'd4: o_operation = NOP; // TODO
                        3'd5: o_operation = LDY;
                        3'd6: o_operation = NOP; // TODO
                        3'd7: o_operation = NOP; // TODO
                    endcase
                end
            endcase
        end

        2'b01:
        begin
            unique case( w_a )
                3'd0: o_operation = ORA;
                3'd1: o_operation = AND;
                3'd2: o_operation = EOR;
                3'd3: o_operation = ADC;
                3'd4: o_operation = STA;
                3'd5: o_operation = LDA;
                3'd6: o_operation = CMP;
                3'd7: o_operation = SBC;
            endcase
        end

        2'b10:
        begin
            if ( w_b == 3'd0 && w_a != 3'd5 )
            begin
                if ( w_a <= 3'd3 )
                begin
                    o_operation = JAM;
                end
                else
                begin
                    o_operation = NOP;
                end
            end
            else if ( w_b == 3'd4 )
            begin
                o_operation = JAM;
            end
            else if ( w_b == 3'd6 && !( w_a == 3'd4 || w_a == 3'd5 ) )
            begin
                o_operation = NOP;
            end
            else if ( w_b == 3'd7 && w_a == 3'd4 )
            begin
                o_operation = NOP;
            end
            else if ( w_a == 3'd7 && w_b == 3'd2 )
            begin
                o_operation = NOP;
            end
            else
            begin
                unique case( w_a )
                    3'd0: o_operation = ASL;
                    3'd1: o_operation = ROL;
                    3'd2: o_operation = LSR;
                    3'd3: o_operation = ROR;
                    3'd4:
                    begin
                        if ( w_b == 3'd2 )
                        begin
                            o_operation = TXA;
                        end
                        else if ( w_b == 3'd6 )
                        begin
                            o_operation = TXS;
                        end
                        else
                        begin
                            o_operation = STX;
                        end                       
                    end
                    3'd5:
                    begin
                        if ( w_b == 3'd2 )
                        begin
                            o_operation = TAX;
                        end
                        else if ( w_b == 3'd6 )
                        begin
                            o_operation = TSX;
                        end
                        else
                        begin
                            o_operation = LDX;
                        end
                    end
                    3'd6: o_operation = ( w_b == 3'b010 ) ? DEX : DEC;
                    3'd7: o_operation = INC;
                endcase
            end
        end

        2'b11:
        begin
            // TODO - illegal opcodes
            //Error( "TODO - illegal opcodes" );
            o_operation = NOP;
        end

    endcase
end

// Signal operation access type, used in conjunction with AddressingMode
always_comb
begin
    o_accessType = Access_Read;

    case( o_operation )
        // Always ReadWrite
        DEC,
        INC:
        begin
            o_accessType = Access_ReadWrite;
        end

        // Read if Implied, ReadWrite otherwise
        ASL,
        LSR,
        ROL,
        ROR:
        begin
            o_accessType = ( o_addressingMode == Implied ) ? Access_Read : Access_ReadWrite;
        end

        BPL,
        BMI,
        BVC,
        BVS,
        BCC,
        BCS,
        BNE,
        BEQ,
        JMP,
        JSR, // Technically read-write, but will handle write specifically
        BRK, // Technically read-write, but will handle write specifically
        RTI, // TODO - actually stack-based
        RTS, // TODO - actually stack-based
        PLA, // TODO - actually stack-based
        PLP, // TODO - actually stack-based
        CMP,
        CPX,
        CPY,
        DEX,
        INX,
        DEY,
        INY,
        ADC,
        AND,
        BIT,
        SBC,
        LDA,
        LDX,
        LDY,
        EOR,
        ORA:
        begin
            o_accessType = Access_Read;
        end

        // Stores
        PHA, // TODO - actually stack-based
        PHP, // TODO - actually stack-based
        STA,
        STX,
        STY:
        begin
            o_accessType = Access_Write;
        end

        // Implied addressing mode, no actual read/write, but equivalent to Read
        NOP,
        CLC,
        SEC,
        CLI,
        SEI,
        CLV,
        CLD,
        SED,
        TAX,
        TXA,
        TAY,
        TYA,
        TXS,
        TSX:
        begin
            o_accessType = Access_Read;
        end

        default:
        begin
            Error( "Invalid operation in access-type logic" );
        end
    endcase
end

function string GetStateString();
    return $sformatf ( "Opcode: 0x%0X\nOperation: %s\nAddressing Mode: %s\nAccessType: %s",
            i_opcode, o_operation.name(), o_addressingMode.name(), o_accessType.name()
    );
endfunction

function void Error( string msg );
    $error( $sformatf ( "%s\n%s", msg, GetStateString() ) );
    $fatal( 0 );
endfunction

endmodule
