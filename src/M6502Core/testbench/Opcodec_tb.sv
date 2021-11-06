`timescale 1ns / 1ps

import M6502Defs::*;

module Opcodec_tb;

logic[ 7:0 ] l_opcode = 8'h00;
Operation l_operation;
AddressingMode l_addressingMode;
AccessType l_accessType;
Index      l_index;

Opcodec opcodec (
    .i_opcode( l_opcode ),
    .o_operation( l_operation ),
    .o_addressingMode( l_addressingMode ),
    .o_accessType( l_accessType ),
    .o_index( l_index )
);

typedef struct {
    Operation       operation;
    AddressingMode  addressingMode;
    AccessType      accessType;
    Index           index;
} OpcodeState;

initial begin
    for ( int opcodeIndex = 0; opcodeIndex < 151; ++opcodeIndex ) begin
        OpcodeState dutState;
        l_opcode = opcodes[ opcodeIndex ];
        $display( "START: Verifying opcode %0X", l_opcode );
        #1;

        dutState = '{ 
            l_operation,
            l_addressingMode,
            l_accessType,
            l_index
        };

        CompareStates( l_opcode, dutState, GetReferenceState( l_opcode ) );
    end

    $display( "FINISH: Testbench completed" );
    $finish;
end

function void CompareStates( logic[ 7:0 ] opcode, OpcodeState dutState, OpcodeState referenceState );
    if ( dutState.operation != referenceState.operation
        || dutState.addressingMode != referenceState.addressingMode
        || dutState.accessType != referenceState.accessType
        || dutState.index != referenceState.index ) begin
        $error( $sformatf( "Mismatch detected for opcode 0x%0X:\n\nDUT: %s\n\nRef: %s",
            opcode, GetStateString( dutState ), GetStateString( referenceState ) ) );
        $fatal;
    end
    else
    begin
        $display( "END: Opcode 0x%0X verified\n", opcode );
    end
endfunction

function string GetStateString( OpcodeState state );
    return $sformatf( "Operation: %s\nAddressing Mode: %s\nAccess Type: %s\nIndex: %s\n",
        state.operation.name(), state.addressingMode.name(), state.accessType.name(), state.index.name() );
endfunction

function OpcodeState GetReferenceState( logic[ 7:0 ] opcode );
    case ( opcode )
        8'h69: return '{ ADC, Immediate, Access_Read, Index_None };
        8'h65: return '{ ADC, ZeroPage, Access_Read, Index_None };
        8'h75: return '{ ADC, ZeroPageIndexed, Access_Read, Index_X };
        8'h6d: return '{ ADC, Absolute, Access_Read, Index_None };
        8'h7d: return '{ ADC, AbsoluteIndexed, Access_Read, Index_X };
        8'h79: return '{ ADC, AbsoluteIndexed, Access_Read, Index_Y };
        8'h61: return '{ ADC, IndexedIndirect, Access_Read, Index_X };
        8'h71: return '{ ADC, IndirectIndexed, Access_Read, Index_Y };

        8'h29: return '{ AND, Immediate, Access_Read, Index_None };
        8'h25: return '{ AND, ZeroPage, Access_Read, Index_None };
        8'h35: return '{ AND, ZeroPageIndexed, Access_Read, Index_X };
        8'h2d: return '{ AND, Absolute, Access_Read, Index_None };
        8'h3d: return '{ AND, AbsoluteIndexed, Access_Read, Index_X };
        8'h39: return '{ AND, AbsoluteIndexed, Access_Read, Index_Y };
        8'h21: return '{ AND, IndexedIndirect, Access_Read, Index_X };
        8'h31: return '{ AND, IndirectIndexed, Access_Read, Index_Y };

        8'h0a: return '{ ASL, Implied, Access_Read, Index_None };
        8'h06: return '{ ASL, ZeroPage, Access_ReadWrite, Index_None };
        8'h16: return '{ ASL, ZeroPageIndexed, Access_ReadWrite, Index_X };
        8'h0e: return '{ ASL, Absolute, Access_ReadWrite, Index_None };
        8'h1e: return '{ ASL, AbsoluteIndexed, Access_ReadWrite, Index_X };

        8'h90: return '{ BCC, Relative, Access_Read, Index_None };
        8'hB0: return '{ BCS, Relative, Access_Read, Index_None };
        8'hF0: return '{ BEQ, Relative, Access_Read, Index_None };
        8'h30: return '{ BMI, Relative, Access_Read, Index_None };
        8'hD0: return '{ BNE, Relative, Access_Read, Index_None };
        8'h10: return '{ BPL, Relative, Access_Read, Index_None };
        8'h50: return '{ BVC, Relative, Access_Read, Index_None };
        8'h70: return '{ BVS, Relative, Access_Read, Index_None };

        8'h24: return '{ BIT, ZeroPage, Access_Read, Index_None };
        8'h2c: return '{ BIT, Absolute, Access_Read, Index_None };

        8'h00: return '{ BRK, Implied, Access_Read, Index_None };
        8'h18: return '{ CLC, Implied, Access_Read, Index_None };
        8'hd8: return '{ CLD, Implied, Access_Read, Index_None };
        8'h58: return '{ CLI, Implied, Access_Read, Index_None };
        8'hb8: return '{ CLV, Implied, Access_Read, Index_None };
        8'hea: return '{ NOP, Implied, Access_Read, Index_None };
        8'h48: return '{ PHA, Implied, Access_Write, Index_None };
        8'h68: return '{ PLA, Implied, Access_Read, Index_None };
        8'h08: return '{ PHP, Implied, Access_Write, Index_None };
        8'h28: return '{ PLP, Implied, Access_Read, Index_None };
        8'h40: return '{ RTI, Implied, Access_Read, Index_None };
        8'h60: return '{ RTS, Implied, Access_Read, Index_None };
        8'h38: return '{ SEC, Implied, Access_Read, Index_None };
        8'hf8: return '{ SED, Implied, Access_Read, Index_None };
        8'h78: return '{ SEI, Implied, Access_Read, Index_None };
        8'haa: return '{ TAX, Implied, Access_Read, Index_None };
        8'h8a: return '{ TXA, Implied, Access_Read, Index_None };
        8'ha8: return '{ TAY, Implied, Access_Read, Index_None };
        8'h98: return '{ TYA, Implied, Access_Read, Index_None };
        8'hba: return '{ TSX, Implied, Access_Read, Index_None };
        8'h9a: return '{ TXS, Implied, Access_Read, Index_None };

        8'hc9: return '{ CMP, Immediate, Access_Read, Index_None };
        8'hc5: return '{ CMP, ZeroPage, Access_Read, Index_None };
        8'hd5: return '{ CMP, ZeroPageIndexed, Access_Read, Index_X };
        8'hcd: return '{ CMP, Absolute, Access_Read, Index_None };
        8'hdd: return '{ CMP, AbsoluteIndexed, Access_Read, Index_X };
        8'hd9: return '{ CMP, AbsoluteIndexed, Access_Read, Index_Y };
        8'hc1: return '{ CMP, IndexedIndirect, Access_Read, Index_X };
        8'hd1: return '{ CMP, IndirectIndexed, Access_Read, Index_Y };

        8'he0: return '{ CPX, Immediate, Access_Read, Index_None };
        8'he4: return '{ CPX, ZeroPage, Access_Read, Index_None };
        8'hec: return '{ CPX, Absolute, Access_Read, Index_None };

        8'hc0: return '{ CPY, Immediate, Access_Read, Index_None };
        8'hc4: return '{ CPY, ZeroPage, Access_Read, Index_None };
        8'hcc: return '{ CPY, Absolute, Access_Read, Index_None };

        8'hc6: return '{ DEC, ZeroPage, Access_ReadWrite, Index_None };
        8'hd6: return '{ DEC, ZeroPageIndexed, Access_ReadWrite, Index_X };
        8'hce: return '{ DEC, Absolute, Access_ReadWrite, Index_None };
        8'hde: return '{ DEC, AbsoluteIndexed, Access_ReadWrite, Index_X };

        8'hca: return '{ DEX, Implied, Access_Read, Index_None };
        8'h88: return '{ DEY, Implied, Access_Read, Index_None };
        8'he8: return '{ INX, Implied, Access_Read, Index_None };
        8'hc8: return '{ INY, Implied, Access_Read, Index_None };

        8'h49: return '{ EOR, Immediate, Access_Read, Index_None };
        8'h45: return '{ EOR, ZeroPage, Access_Read, Index_None };
        8'h55: return '{ EOR, ZeroPageIndexed, Access_Read, Index_X };
        8'h4d: return '{ EOR, Absolute, Access_Read, Index_None };
        8'h5d: return '{ EOR, AbsoluteIndexed, Access_Read, Index_X };
        8'h59: return '{ EOR, AbsoluteIndexed, Access_Read, Index_Y };
        8'h41: return '{ EOR, IndexedIndirect, Access_Read, Index_X };
        8'h51: return '{ EOR, IndirectIndexed, Access_Read, Index_Y };

        8'he6: return '{ INC, ZeroPage, Access_ReadWrite, Index_None };
        8'hf6: return '{ INC, ZeroPageIndexed, Access_ReadWrite, Index_X };
        8'hee: return '{ INC, Absolute, Access_ReadWrite, Index_None };
        8'hfe: return '{ INC, AbsoluteIndexed, Access_ReadWrite, Index_X };

        8'h4c: return '{ JMP, Absolute, Access_Read, Index_None };
        8'h6c: return '{ JMP, AbsoluteIndirect, Access_Read, Index_None };
        8'h20: return '{ JSR, Absolute, Access_Read, Index_None };

        8'ha9: return '{ LDA, Immediate, Access_Read, Index_None };
        8'ha5: return '{ LDA, ZeroPage, Access_Read, Index_None };
        8'hb5: return '{ LDA, ZeroPageIndexed, Access_Read, Index_X };
        8'had: return '{ LDA, Absolute, Access_Read, Index_None };
        8'hbd: return '{ LDA, AbsoluteIndexed, Access_Read, Index_X };
        8'hb9: return '{ LDA, AbsoluteIndexed, Access_Read, Index_Y };
        8'ha1: return '{ LDA, IndexedIndirect, Access_Read, Index_X };
        8'hb1: return '{ LDA, IndirectIndexed, Access_Read, Index_Y };

        8'ha2: return '{ LDX, Immediate, Access_Read, Index_None };
        8'ha6: return '{ LDX, ZeroPage, Access_Read, Index_None };
        8'hb6: return '{ LDX, ZeroPageIndexed, Access_Read, Index_Y };
        8'hae: return '{ LDX, Absolute, Access_Read, Index_None };
        8'hbe: return '{ LDX, AbsoluteIndexed, Access_Read, Index_Y };

        8'ha0: return '{ LDY, Immediate, Access_Read, Index_None };
        8'ha4: return '{ LDY, ZeroPage, Access_Read, Index_None };
        8'hb4: return '{ LDY, ZeroPageIndexed, Access_Read, Index_X };
        8'hac: return '{ LDY, Absolute, Access_Read, Index_None };
        8'hbc: return '{ LDY, AbsoluteIndexed, Access_Read, Index_X };

        8'h4a: return '{ LSR, Implied, Access_Read, Index_None };
        8'h46: return '{ LSR, ZeroPage, Access_ReadWrite, Index_None };
        8'h56: return '{ LSR, ZeroPageIndexed, Access_ReadWrite, Index_X };
        8'h4e: return '{ LSR, Absolute, Access_ReadWrite, Index_None };
        8'h5e: return '{ LSR, AbsoluteIndexed, Access_ReadWrite, Index_X };

        8'h09: return '{ ORA, Immediate, Access_Read, Index_None };
        8'h05: return '{ ORA, ZeroPage, Access_Read, Index_None };
        8'h15: return '{ ORA, ZeroPageIndexed, Access_Read, Index_X };
        8'h0d: return '{ ORA, Absolute, Access_Read, Index_None };
        8'h1d: return '{ ORA, AbsoluteIndexed, Access_Read, Index_X };
        8'h19: return '{ ORA, AbsoluteIndexed, Access_Read, Index_Y };
        8'h01: return '{ ORA, IndexedIndirect, Access_Read, Index_X };
        8'h11: return '{ ORA, IndirectIndexed, Access_Read, Index_Y };

        8'h2a: return '{ ROL, Implied, Access_Read, Index_None };
        8'h26: return '{ ROL, ZeroPage, Access_ReadWrite, Index_None };
        8'h36: return '{ ROL, ZeroPageIndexed, Access_ReadWrite, Index_X };
        8'h2e: return '{ ROL, Absolute, Access_ReadWrite, Index_None };
        8'h3e: return '{ ROL, AbsoluteIndexed, Access_ReadWrite, Index_X };

        8'h6a: return '{ ROR, Implied, Access_Read, Index_None };
        8'h66: return '{ ROR, ZeroPage, Access_ReadWrite, Index_None };
        8'h76: return '{ ROR, ZeroPageIndexed, Access_ReadWrite, Index_X };
        8'h7e: return '{ ROR, AbsoluteIndexed, Access_ReadWrite, Index_X };
        8'h6e: return '{ ROR, Absolute, Access_ReadWrite, Index_None };

        8'he9: return '{ SBC, Immediate, Access_Read, Index_None };
        8'he5: return '{ SBC, ZeroPage, Access_Read, Index_None };
        8'hf5: return '{ SBC, ZeroPageIndexed, Access_Read, Index_X };
        8'hed: return '{ SBC, Absolute, Access_Read, Index_None };
        8'hfd: return '{ SBC, AbsoluteIndexed, Access_Read, Index_X };
        8'hf9: return '{ SBC, AbsoluteIndexed, Access_Read, Index_Y };
        8'he1: return '{ SBC, IndexedIndirect, Access_Read, Index_X };
        8'hf1: return '{ SBC, IndirectIndexed, Access_Read, Index_Y };

        8'h85: return '{ STA, ZeroPage, Access_Write, Index_None };
        8'h95: return '{ STA, ZeroPageIndexed, Access_Write, Index_X };
        8'h8d: return '{ STA, Absolute, Access_Write, Index_None };
        8'h9d: return '{ STA, AbsoluteIndexed, Access_Write, Index_X };
        8'h99: return '{ STA, AbsoluteIndexed, Access_Write, Index_Y };
        8'h81: return '{ STA, IndexedIndirect, Access_Write, Index_X };
        8'h91: return '{ STA, IndirectIndexed, Access_Write, Index_Y };

        8'h86: return '{ STX, ZeroPage, Access_Write, Index_None };
        8'h96: return '{ STX, ZeroPageIndexed, Access_Write, Index_Y };
        8'h8e: return '{ STX, Absolute, Access_Write, Index_None };
        8'h84: return '{ STY, ZeroPage, Access_Write, Index_None };
        8'h94: return '{ STY, ZeroPageIndexed, Access_Write, Index_X };
        8'h8c: return '{ STY, Absolute, Access_Write, Index_None };

        default: return '{ NOP, Implied, Access_Read, Index_None };
    endcase
endfunction

byte opcodes[ 151 ] = {
    8'h69,
    8'h65,
    8'h75,
    8'h6d,
    8'h7d,
    8'h79,
    8'h61,
    8'h71,
    8'h29,
    8'h25,
    8'h35,
    8'h2d,
    8'h3d,
    8'h39,
    8'h21,
    8'h31,
    8'h0a,
    8'h06,
    8'h16,
    8'h0e,
    8'h1e,
    8'h90,
    8'hB0,
    8'hF0,
    8'h30,
    8'hD0,
    8'h10,
    8'h50,
    8'h70,
    8'h24,
    8'h2c,
    8'h00,
    8'h18,
    8'hd8,
    8'h58,
    8'hb8,
    8'hea,
    8'h48,
    8'h68,
    8'h08,
    8'h28,
    8'h40,
    8'h60,
    8'h38,
    8'hf8,
    8'h78,
    8'haa,
    8'h8a,
    8'ha8,
    8'h98,
    8'hba,
    8'h9a,
    8'hc9,
    8'hc5,
    8'hd5,
    8'hcd,
    8'hdd,
    8'hd9,
    8'hc1,
    8'hd1,
    8'he0,
    8'he4,
    8'hec,
    8'hc0,
    8'hc4,
    8'hcc,
    8'hc6,
    8'hd6,
    8'hce,
    8'hde,
    8'hca,
    8'h88,
    8'he8,
    8'hc8,
    8'h49,
    8'h45,
    8'h55,
    8'h4d,
    8'h5d,
    8'h59,
    8'h41,
    8'h51,
    8'he6,
    8'hf6,
    8'hee,
    8'hfe,
    8'h4c,
    8'h6c,
    8'h20,
    8'ha9,
    8'ha5,
    8'hb5,
    8'had,
    8'hbd,
    8'hb9,
    8'ha1,
    8'hb1,
    8'ha2,
    8'ha6,
    8'hb6,
    8'hae,
    8'hbe,
    8'ha0,
    8'ha4,
    8'hb4,
    8'hac,
    8'hbc,
    8'h4a,
    8'h46,
    8'h56,
    8'h4e,
    8'h5e,
    8'h09,
    8'h05,
    8'h15,
    8'h0d,
    8'h1d,
    8'h19,
    8'h01,
    8'h11,
    8'h2a,
    8'h26,
    8'h36,
    8'h2e,
    8'h3e,
    8'h6a,
    8'h66,
    8'h76,
    8'h7e,
    8'h6e,
    8'he9,
    8'he5,
    8'hf5,
    8'hed,
    8'hfd,
    8'hf9,
    8'he1,
    8'hf1,
    8'h85,
    8'h95,
    8'h8d,
    8'h9d,
    8'h99,
    8'h81,
    8'h91,
    8'h86,
    8'h96,
    8'h8e,
    8'h84,
    8'h94,
    8'h8c
};


endmodule
