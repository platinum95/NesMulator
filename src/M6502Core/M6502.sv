`timescale 1ns / 1ps

`include "M6502Defs.sv"

import M6502Defs::AddressingMode;
import M6502Defs::AluOperation;
import M6502Defs::Operation;
import M6502Defs::StatusBits;

module M6502(
    input   wire            i_clk,
    input   wire            i_rst,
    input   wire            i_nmi,
    input   wire            i_irq,
    inout   logic[ 7:0 ]    io_data,
    output  reg[ 15:0 ]    o_addr,
    output  wire            o_rw
);

/*********************
* Work registers
**********************/
reg[ 15:0 ] r_PC_nxt = 0;
reg[ 15:0 ] r_PC = 0;

reg[ 7:0 ] r_S_nxt = 0;
reg[ 7:0 ] r_S = 0;

reg[ 7:0 ] r_P_nxt = 0;
reg[ 7:0 ] r_P = 0;

reg[ 7:0 ] r_A_nxt = 0;
reg[ 7:0 ] r_A = 0;

reg[ 7:0 ] r_X_nxt = 0;
reg[ 7:0 ] r_X = 0;

reg[ 7:0 ] r_Y_nxt = 0;
reg[ 7:0 ] r_Y = 0;


/***********************
* Internal registers
************************/
reg[ 7:0 ] r_OPCODE_nxt = 0;
reg[ 7:0 ] r_OPCODE = 0;

/*****************************
* Addressing mode registers
******************************/
// TODO - Some registers are redundant, no op needs all of these.
//      - Can reduce down to re-use.

// Read in after opcode, up to 2 bytes of operand
reg[ 7:0 ] r_OPERAND1_nxt = 0;
reg[ 7:0 ] r_OPERAND1 = 0;

reg[ 7:0 ] r_OPERAND2_nxt = 0;
reg[ 7:0 ] r_OPERAND2 = 0;

wire[ 15:0 ] w_operandAddress = { r_OPERAND1, r_OPERAND2 }; // TODO - endianness

// Effective Addr, used for indirect lookup
reg[ 7:0 ] r_EFFECTIVEL_ADDR_nxt = 0;
reg[ 7:0 ] r_EFFECTIVEL_ADDR = 0;

reg[ 7:0 ] r_EFFECTIVEH_ADDR_nxt = 0;
reg[ 7:0 ] r_EFFECTIVEH_ADDR = 0;

// Has the result of the indirect lookup
reg[ 7:0 ] r_INDIRECTL_addr_nxt = 0;
reg[ 7:0 ] r_INDIRECTL_addr = 0;

// Working data
reg[ 7:0 ] r_WORKINGL_nxt = 0;
reg[ 7:0 ] r_WORKINGL = 0;

reg[ 7:0 ] r_WORKINGH_nxt = 0;
reg[ 7:0 ] r_WORKINGH = 0;

// Temp, TODO fix this
reg r_indexerCarry_nxt = 0;
reg r_indexerCarry = 0;

/*****************************
* Main FSM states
******************************/
enum {
    Fetch,
    ReadOperand1,
    ReadOperand2,
    ReadMem1,
    ReadMem2,
    ReadIndirect1,
    ReadIndirect2,

    Read1,
    Read2,
    WriteBack,
    WriteResult,

    // Extra states
    StackRead,
    StackWrite,
    BrkAux1, // Fetch PCL from $FFFE
    BrkAux2, // Fetch PCH from $FFFF
    JsrAux, // Fetch PCH from PC
    PcInc,
    Jam
} r_mainState = Fetch, r_mainState_nxt = Fetch;

logic[ 1:0 ] r_stackStateCounter = 0;
logic[ 1:0 ] r_stackStateCounter_nxt = 0;


/******************************
* Addressing modes
******************************/
AddressingMode r_addressingMode;

logic[ 7:0 ] r_indexingIndex;
assign r_indexingIndex = ( r_index == Index_X ) ? r_X : r_Y; // For ZeroPageIndexed/AbsoluteIndexed

/*******************************
* ALU
********************************/
AluOperation l_aluOperation;
logic[ 7:0 ] l_aluInA;
logic[ 7:0 ] l_aluOut;
logic[ 7:0 ] l_aluStatusOut;

alu m_alu(
    .i_operation( l_aluOperation ),
    .i_status( r_P ),
    .i_a( l_aluInA ),
    .i_b( io_data ),
    .o_result( l_aluOut ),
    .o_status( l_aluStatusOut )
);

// Set ALU inputs
always_comb
begin
    l_aluInA = r_A;

    case( r_operation )
        AND,
        ORA,
        EOR,
        BIT,
        ADC,
        SBC,
        CMP,
        DEC,
        INC:
        begin
            l_aluInA = r_A;
        end

        CPX,
        DEX,
        INX:
        begin
            l_aluInA = r_X;
        end

        CPY,
        DEY,
        INY:
        begin
            l_aluInA = r_Y;
        end

        LSR,
        ROL,
        ROR,
        ASL:
        begin
            if ( r_addressingMode == Implied )
            begin
                l_aluInA = r_A;
            end
            else
            begin
                l_aluInA = io_data;
            end
        end

        default:
        begin
            l_aluInA = r_A;
        end

    endcase
end

always_comb
begin
    case( r_operation )
        AND,
        BIT: l_aluOperation = AluOperation_AND;
        ORA: l_aluOperation = AluOperation_OR;
        EOR: l_aluOperation = AluOperation_EOR;

        ADC: l_aluOperation = AluOperation_ADC;
        SBC: l_aluOperation = AluOperation_SBC;

        CMP,
        CPX,
        CPY: l_aluOperation = AluOperation_CMP;

        DEC,
        DEX,
        DEY: l_aluOperation = AluOperation_DEC;

        INC,
        INY,
        INX: l_aluOperation = AluOperation_INC;

        LSR: l_aluOperation = AluOperation_LSR;
        ROL: l_aluOperation = AluOperation_ROL;
        ROR: l_aluOperation = AluOperation_ROR;
        ASL: l_aluOperation = AluOperation_ASL;

        default: l_aluOperation = AluOperation_ADC;
    endcase
end

/*******************************
* Combinational Opcode Decoder
********************************/
logic[ 7:0 ] r_workingDataA = 0;
logic[ 7:0 ] r_workingDataB = 0;
Index r_index;

Operation r_operation;
AccessType r_operationAccessType;

Opcodec opcodec(
    .i_opcode( r_OPCODE ),
    .o_operation( r_operation ),
    .o_addressingMode( r_addressingMode ),
    .o_accessType( r_operationAccessType ),
    .o_index( r_index )
);

// Signal that data address is ready and on the address lines.
logic r_readReady = 1'b0;
always_comb
begin
    r_readReady = 1'b0;
    case( r_addressingMode )
        Implied,
        Immediate:
        begin
            r_readReady = ( r_mainState == ReadOperand1 );
        end

        Absolute,
        ZeroPage:
        begin
            r_readReady = ( r_mainState >= ReadMem1 );
        end

        ZeroPageIndexed:
        begin
            r_readReady = ( r_mainState >= ReadIndirect1 );
        end

        AbsoluteIndexed,
        IndirectIndexed:
        begin
            // Goto Indirect1 if invalid, then Indirect2.
            // Go straight to Indirect2 if valid
            r_readReady =
                ( ( r_mainState == Read1 ) && ( r_mainState_nxt != Read2 ) )
                || ( r_mainState >= Read2 );
        end

        Relative:
        begin
            r_readReady = ( r_mainState >= ReadOperand1 );
        end

        IndexedIndirect:
        begin
            r_readReady = ( r_mainState >= Read2 );
        end

        AbsoluteIndirect:
        begin
            r_readReady = ( r_mainState >= ReadIndirect2 );
        end

        default:
        begin
            Error( "Invalid addressing mode in read-ready logic" );
        end
    endcase
end

enum {
    ReadFlag = 0,
    WriteFlag = 1
} r_readWrite;

assign o_rw = r_readWrite;
// Read/write signal logic
always_comb
begin
    r_readWrite = ReadFlag;
    case ( r_mainState )
        Fetch,
        ReadOperand1,
        ReadOperand2,
        ReadMem1,
        ReadMem2,
        ReadIndirect1,
        ReadIndirect2,
        Read1,
        Read2,
        StackRead,
        BrkAux1,
        BrkAux2,
        JsrAux,
        PcInc,
        Jam:
        begin
            r_readWrite = ReadFlag;
        end

        WriteBack,
        WriteResult,
        StackWrite:
        begin
            r_readWrite = WriteFlag;
        end

        default:
        begin
            Error( "Invalid Main State in read-write logic" );
        end
    endcase
end

// Logic for branch instructions
logic l_shouldBranch = 0;
always_comb
begin
    l_shouldBranch = 0;
    case( r_operation )
        BPL: l_shouldBranch = ( r_P[ NEGATIVE_BIT ] == 0 );
        BMI: l_shouldBranch = ( r_P[ NEGATIVE_BIT ] == 1 );
        BVC: l_shouldBranch = ( r_P[ OVERFLOW_BIT ] == 0 );
        BVS: l_shouldBranch = ( r_P[ OVERFLOW_BIT ] == 1 );
        BCC: l_shouldBranch = ( r_P[ CARRY_BIT ] == 0 );
        BCS: l_shouldBranch = ( r_P[ CARRY_BIT ] == 1 );
        BNE: l_shouldBranch = ( r_P[ ZERO_BIT ] == 0 );
        BEQ: l_shouldBranch = ( r_P[ ZERO_BIT ] == 1 );

        default: l_shouldBranch = 0;
    endcase
end

logic[ 7:0 ] r_dataOut = 0;
assign io_data = ( r_readWrite == WriteFlag ) ? r_dataOut : 8'hZZ;

// Register-updating logic.
always_comb
begin
    r_A_nxt = r_A;
    r_X_nxt = r_X;
    r_Y_nxt = r_Y;
    r_S_nxt = r_S;
    r_P_nxt = r_P;
    r_PC_nxt = r_PC;
    r_OPCODE_nxt = r_OPCODE;
    r_dataOut = 8'hZZ;
    r_OPERAND1_nxt = r_OPERAND1;
    r_OPERAND2_nxt = r_OPERAND2;
    r_EFFECTIVEL_ADDR_nxt = r_EFFECTIVEL_ADDR;
    r_EFFECTIVEH_ADDR_nxt = r_EFFECTIVEH_ADDR;
    r_INDIRECTL_addr_nxt = r_INDIRECTL_addr;
    r_WORKINGL_nxt = r_WORKINGL;
    r_WORKINGH_nxt = r_WORKINGH;
    
    r_indexerCarry_nxt = 0;

    if ( r_mainState == Fetch )
    begin
        if ( r_indexerCarry )
        begin
            // Just fetched branched opcode, but PCH needs fixing
            r_PC_nxt[ 15:8 ] = ( r_OPERAND1[ 7 ] == 0 ) ?
                r_PC[ 15:8 ] + 1    // Addition
                : r_PC[ 15:8 ] - 1; // Subtraction
        end
        else
        begin
            // Not branching or branched PC doesn't need fixing: regular fetch. Inc PC and get next OPCODE
            r_PC_nxt = r_PC + 1;
            r_OPCODE_nxt = io_data;
        end
    end
    else if ( r_mainState == ReadOperand2 && r_addressingMode == Relative )
    begin
        // Branch op, check if we should branch. Add OPERAND1 to PCL if so, otherwise increment PC.
        if ( l_shouldBranch )
        begin
            // Need to branch based on relative address.
            r_PC_nxt[ 7:0 ] = r_PC[ 7:0 ] + r_OPERAND1;

            // 'Carry' here indicates either addition-carry or subtraction-borrow,
            // Really just a flag that we need to fix PCH.
            r_indexerCarry_nxt = ( r_OPERAND1[ 7 ] == 0 ) ?
                ( r_PC[ 7 ] == 1 ) && ( r_PC_nxt[ 7 ] == 0 ) // Addition
                : ( r_PC[ 7 ] == 0 ) && ( r_PC_nxt[ 7 ] == 1 ); // Subtraction
        end
        else
        begin
            // Not branching, continue to read operand of current instruction
            r_PC_nxt = r_PC + 1;
            r_OPCODE_nxt = io_data;
        end
    end
    else
    begin

        if ( ( r_mainState == ReadOperand1 || r_mainState == ReadOperand2 ) && r_addressingMode != Implied )
        begin
            // Inc PC if the operation has operands
            r_PC_nxt = r_PC + 1;
        end
        else if ( r_mainState == PcInc )
        begin
            r_PC_nxt = r_PC + 1;
        end

        if ( r_mainState == StackRead && r_stackStateCounter == 0 && r_operation != JSR )
        begin
            r_S_nxt = r_S + 1;
        end
        else if ( r_mainState == StackWrite )
        begin
            r_S_nxt = r_S - 1;
        end

        case( r_operation )
            BRK:
            begin
                case( r_mainState )
                    ReadOperand1:
                    begin
                        r_PC_nxt = r_PC + 1;
                    end

                    StackWrite:
                    begin
                        case( r_stackStateCounter )
                            2'b00:
                            begin
                                r_dataOut = r_PC[ 15:8 ];
                            end

                            2'b01:
                            begin
                                r_dataOut = r_PC[ 7:0 ];
                            end

                            2'b10:
                            begin
                                r_dataOut = { r_P[ 7:6 ], 1'b1, 1'b1, r_P[ 3:0 ] };
                                r_P_nxt[ INTERRUPT_BIT ] = 1'b1;
                            end

                            2'b11:
                            begin
                                Error( "Invalid stack-write state in BRK reg-updating logic" );
                            end
                        endcase
                    end

                    BrkAux1:
                    begin
                        r_PC_nxt[ 7:0 ] = io_data;
                    end

                    BrkAux2:
                    begin
                        r_PC_nxt[ 15:8 ] = io_data;
                    end

                    default:
                    begin
                        Error( "Invalid Main State in BRK reg-updating logic" );
                    end
                endcase
            end

            RTI:
            begin
                case( r_mainState )
                    ReadOperand1:
                    begin
                        // NOP
                    end

                    StackRead:
                    begin
                        case( r_stackStateCounter )
                            2'b00:
                            begin
                                // NOP
                            end

                            2'b01:
                            begin
                                r_S_nxt = r_S + 1;
                                r_P_nxt = io_data;
                            end

                            2'b10:
                            begin
                                r_S_nxt = r_S + 1;
                                r_PC_nxt[ 7:0 ] = io_data;
                            end

                            2'b11:
                            begin
                                r_PC_nxt[ 15:8 ] = io_data;
                            end
                        endcase
                    end

                    default:
                    begin
                        Error( "Invalid Main State in RTI reg-updating logic" );
                    end
                endcase
            end

            RTS:
            begin
                case( r_mainState )
                    ReadOperand1:
                    begin
                        // NOP
                    end

                    StackRead:
                    begin
                        case( r_stackStateCounter )
                            2'b00:
                            begin
                                // NOP
                            end

                            2'b01:
                            begin
                                r_S_nxt = r_S + 1;
                                r_PC_nxt[ 7:0 ] = io_data;
                            end

                            2'b10:
                            begin
                                r_PC_nxt[ 15:8 ] = io_data;
                            end

                            2'b11:
                            begin
                                Error( "Invalid stack-read state in RTS reg-updating logic" );
                            end
                        endcase
                    end
                    default:
                    begin
                        Error( "Invalid Main State in RTS reg-updating logic" );
                    end
                endcase
            end

            PHA,
            PHP:
            begin
                case( r_mainState )
                    ReadOperand1:
                    begin
                        // NOP
                    end

                    StackWrite:
                    begin
                        case( r_stackStateCounter )
                            2'b00:
                            begin
                                r_dataOut = ( r_operation == PHA ) ? r_A : '{ r_P[ 7:6 ], 1'b1, 1'b1, r_P[ 3:0 ] };
                            end
                            default:
                            begin
                                Error( "Invalid stack-write state in PHA/PHP reg-updating logic" );
                            end
                        endcase
                    end
                    default:
                    begin
                        Error( "Invalid Main State in PHA/PHP reg-updating logic" );
                    end
                endcase
            end

            PLA,
            PLP:
            begin
                case( r_mainState )
                    ReadOperand1:
                    begin
                        // NOP
                    end

                    StackRead:
                    begin
                        case( r_stackStateCounter )
                            2'b00:
                            begin
                                // NOP
                            end

                            2'b01:
                            begin
                                if ( r_operation == PLA )
                                begin
                                    r_A_nxt = io_data;
                                    r_P_nxt[ NEGATIVE_BIT ] = io_data[ 7 ];
                                    r_P_nxt[ ZERO_BIT ] = io_data == 8'h00;
                                end
                                else
                                begin
                                    r_P_nxt = io_data;
                                end
                            end
                            default:
                            begin
                                Error( "Invalid stack-read state in PLA/PLP reg-updating logic" );
                            end
                        endcase
                    end
                    default:
                    begin
                        Error( "Invalid Main State in PLA/PLP reg-updating logic" );
                    end
                endcase
            end

            JSR:
            begin
                case( r_mainState )
                    ReadOperand1:
                    begin
                        r_OPERAND1_nxt = io_data;
                    end

                    StackRead:
                    begin
                        // NOP
                    end

                    StackWrite:
                    begin
                        case( r_stackStateCounter )
                            2'b00:
                            begin
                                r_dataOut = r_PC_nxt[ 15:8 ];
                            end

                            2'b01:
                            begin
                                r_dataOut = r_PC_nxt[ 7:0 ];
                            end

                            default:
                            begin
                                Error( "Invalid stack-write state in JSR reg-updating logic" );
                            end
                        endcase
                    end

                    JsrAux:
                    begin
                        r_PC_nxt = { io_data, r_OPERAND1 };
                    end
                    default:
                    begin
                        Error( "Invalid Main State in JSR reg-updating logic" );
                    end
                endcase
            end

            JMP:
            begin
                case ( r_addressingMode )
                    Absolute: begin
                        case ( r_mainState )
                            ReadOperand1: r_OPERAND1_nxt = io_data;
                            ReadOperand2: r_PC_nxt = { io_data, r_OPERAND1 };
                        endcase
                    end
                    AbsoluteIndirect: begin
                        case ( r_mainState )
                            ReadOperand1: r_OPERAND1_nxt = io_data;
                            ReadOperand2: r_OPERAND2_nxt = io_data;
                            ReadMem1: r_EFFECTIVEL_ADDR_nxt = io_data;
                            ReadMem2: r_PC_nxt = { io_data, r_EFFECTIVEL_ADDR };
                        endcase
                    end
                endcase
            end

            default:
            begin
                // Get-effective address logic
                if ( r_addressingMode != Implied && r_addressingMode != Immediate )
                begin
                    case ( r_mainState )
                        ReadOperand1:
                        begin
                            case ( r_addressingMode )
                                Absolute,
                                AbsoluteIndexed,
                                ZeroPage,
                                ZeroPageIndexed:
                                begin
                                    r_EFFECTIVEL_ADDR_nxt = io_data; // TODO - remove
                                    r_OPERAND1_nxt = io_data;
                                    r_EFFECTIVEH_ADDR_nxt = 8'b0;
                                end

                                default:
                                begin
                                    r_OPERAND1_nxt = io_data;
                                end
                            endcase
                        end

                        ReadOperand2:
                        begin
                            case ( r_addressingMode )
                                Absolute:
                                begin
                                    r_EFFECTIVEH_ADDR_nxt = io_data; // TODO - remove
                                    r_OPERAND2_nxt = io_data;
                                end
                                AbsoluteIndexed:
                                begin
                                    r_EFFECTIVEH_ADDR_nxt = io_data;
                                    r_EFFECTIVEL_ADDR_nxt = r_EFFECTIVEL_ADDR + r_indexingIndex;
                                    r_indexerCarry_nxt = r_EFFECTIVEL_ADDR[ 7 ] == 1 && r_EFFECTIVEL_ADDR_nxt[ 7 ] == 0;
                                end

                                default:
                                begin
                                    r_OPERAND2_nxt = io_data;
                                end
                            endcase
                        end

                        ReadMem1:
                        begin
                            unique case ( r_addressingMode )
                                ZeroPageIndexed:
                                begin
                                    r_EFFECTIVEL_ADDR_nxt = r_EFFECTIVEL_ADDR + r_indexingIndex;
                                end

                                IndexedIndirect:
                                begin
                                    r_INDIRECTL_addr_nxt = io_data + r_X;
                                end

                                IndirectIndexed:
                                begin
                                    r_EFFECTIVEL_ADDR_nxt = io_data;
                                end

                                AbsoluteIndirect:
                                begin
                                    r_PC_nxt[ 7:0 ] = io_data;
                                end

                                Absolute:
                                begin
                                    r_workingDataA = io_data;
                                end

                                default:
                                begin
                                    Error( "Invalid addressing mode in reg-updating logic" );
                                end
                            endcase
                        end

                        ReadMem2:
                        begin
                            case ( r_addressingMode )
                                IndirectIndexed:
                                begin
                                    r_EFFECTIVEH_ADDR_nxt = io_data;
                                    r_EFFECTIVEL_ADDR_nxt = r_EFFECTIVEL_ADDR + r_Y;
                                    r_indexerCarry_nxt = r_EFFECTIVEL_ADDR[ 7 ] == 1 && r_EFFECTIVEL_ADDR_nxt[ 7 ] == 0;
                                end

                                AbsoluteIndirect:
                                begin
                                    r_PC_nxt[ 15:8 ] = io_data;
                                end

                                default:
                                begin
                                    Error( "Invalid addressing mode in reg-updating logic" );
                                end
                            endcase
                        end

                        ReadIndirect1:
                        begin
                            case ( r_addressingMode )
                                IndexedIndirect:
                                begin
                                    r_EFFECTIVEL_ADDR_nxt = io_data;
                                end

                                default:
                                begin
                                    Error( "Invalid addressing mode in reg-updating logic" );
                                end
                            endcase
                        end

                        ReadIndirect2:
                        begin
                            case ( r_addressingMode )
                                IndexedIndirect:
                                begin
                                    r_EFFECTIVEH_ADDR_nxt = io_data;
                                end

                                default:
                                begin
                                    Error( "Invalid addressing mode in reg-updating logic" );
                                end
                            endcase
                        end

                        Read1:
                        begin
                            case ( r_addressingMode )
                                AbsoluteIndexed,
                                IndirectIndexed:
                                begin
                                    r_EFFECTIVEH_ADDR_nxt = r_EFFECTIVEH_ADDR + r_indexerCarry;
                                    r_workingDataA = io_data;
                                end

                                ZeroPageIndexed:
                                begin
                                    r_workingDataA = io_data;
                                end

                                default:
                                begin
                                    Error( "Invalid addressing mode in reg-updating logic" );
                                end
                            endcase
                        end

                        Read2:
                        begin
                            r_workingDataA = io_data;
                        end

                        WriteBack:
                        begin
                            case ( r_operation )
                                ASL,
                                LSR,
                                ROL,
                                ROR,
                                DEC,
                                INC:
                                begin
                                    r_dataOut = l_aluOut;
                                end

                                default:
                                begin
                                    Error( "Invalid operation in WriteBack state" );
                                end
                            endcase;
                        end
                        WriteResult:
                        begin
                            case ( r_operation )
                                ASL,
                                LSR,
                                ROL,
                                ROR,
                                DEC,
                                INC:
                                begin
                                    r_dataOut = l_aluOut;
                                end

                                STA: r_dataOut = r_A;
                                STX: r_dataOut = r_X;
                                STY: r_dataOut = r_Y;

                                default:
                                begin
                                    Error( "Invalid operation in WriteResult state" );
                                end
                            endcase;
                        end
                    endcase
                end

                if ( r_readReady )
                begin
                    // TODO - status register

                    case( r_operation )
                        TYA: begin
                            r_A_nxt = r_Y;
                            r_P_nxt[ NEGATIVE_BIT ] = r_Y[ 7 ];
                            r_P_nxt[ ZERO_BIT ] = r_Y == 0;
                        end 
                        TXA: begin 
                            r_A_nxt = r_X;
                            r_P_nxt[ NEGATIVE_BIT ] = r_X[ 7 ];
                            r_P_nxt[ ZERO_BIT ] = r_X == 0;
                        end
                        LDA: begin
                            r_A_nxt = io_data;
                            r_P_nxt[ NEGATIVE_BIT ] = io_data[ 7 ];
                            r_P_nxt[ ZERO_BIT ] = io_data == 0;
                        end

                        ADC,
                        AND,
                        ORA,
                        SBC:
                        begin
                            // ALU Operations and register-transfers
                            r_A_nxt = l_aluOut;
                            r_P_nxt = l_aluStatusOut;
                        end

                        CMP,
                        CPX,
                        CPY:
                        begin
                            r_P_nxt = l_aluStatusOut;
                        end

                        ASL,
                        EOR,
                        LSR,
                        ROL,
                        DEC,
                        INC,
                        ROR:
                        begin
                            // Also ALU, but possibly going to mem
                            if ( r_addressingMode == Immediate )
                            begin
                                r_A_nxt = l_aluOut;
                            end
                            r_P_nxt = l_aluStatusOut;
                        end

                        TSX: begin
                            r_X_nxt = r_S;
                            r_P_nxt[ NEGATIVE_BIT ] = r_S[ 7 ];
                            r_P_nxt[ ZERO_BIT ] = r_S == 0;
                        end
                        TAX: begin 
                            r_X_nxt = r_A;
                            r_P_nxt[ NEGATIVE_BIT ] = r_A[ 7 ];
                            r_P_nxt[ ZERO_BIT ] = r_A == 0;
                        end
                        LDX: begin 
                            r_X_nxt = io_data;
                            r_P_nxt[ NEGATIVE_BIT ] = io_data[ 7 ];
                            r_P_nxt[ ZERO_BIT ] = io_data == 0;
                        end
                        DEX,
                        INX:
                        begin
                            r_X_nxt = l_aluOut;
                            r_P_nxt = l_aluStatusOut;
                        end

                        TAY:
                        begin
                            r_Y_nxt = r_A;
                            r_P_nxt[ NEGATIVE_BIT ] = r_A[ 7 ];
                            r_P_nxt[ ZERO_BIT ] = r_A == 0;
                        end
                        LDY: begin
                            r_Y_nxt = io_data;
                            r_P_nxt[ NEGATIVE_BIT ] = io_data[ 7 ];
                            r_P_nxt[ ZERO_BIT ] = io_data == 0;
                        end

                        DEY,
                        INY:
                        begin
                            r_Y_nxt = l_aluOut;
                            r_P_nxt = l_aluStatusOut;
                        end

                        TXS: r_S_nxt = r_X;

                        CLC: r_P_nxt[ CARRY_BIT ] = 0;
                        SEC: r_P_nxt[ CARRY_BIT ] = 1;
                        CLI: r_P_nxt[ INTERRUPT_BIT ] = 0;
                        SEI: r_P_nxt[ INTERRUPT_BIT ] = 1;
                        CLV: r_P_nxt[ OVERFLOW_BIT ] = 0;
                        CLD: r_P_nxt[ DECIMAL_BIT ] = 0;
                        SED: r_P_nxt[ DECIMAL_BIT ] = 1;

                        BPL,
                        BMI,
                        BVC,
                        BVS,
                        BCC,
                        BCS,
                        BNE,
                        BEQ,
                        JMP,
                        NOP:
                        begin
                            
                        end
                        
                    endcase
                end
            end
        endcase
    end
end

/************************
* Main state logic
*************************/

// Output address logic
// TODO - this won't hold the address
always_comb
begin
    o_addr = 0;
    case ( r_mainState )
        Fetch,
        ReadOperand1,
        ReadOperand2:
        begin
            o_addr = r_PC;
        end

        ReadMem1:
        begin
            case ( r_addressingMode )
                ZeroPage,
                ZeroPageIndexed,
                IndexedIndirect,
                IndirectIndexed:
                begin
                    o_addr = { 8'h00, r_OPERAND1 };
                end

                Absolute,
                AbsoluteIndirect:
                begin
                    o_addr = { r_OPERAND2, r_OPERAND1 };
                end

                default:
                begin
                    Error( "Invalid addressing mode in output address logic" );
                end
            endcase
        end

        ReadMem2:
        begin
            case ( r_addressingMode )
                IndirectIndexed:
                begin
                    o_addr = { 8'h00, r_OPERAND1 + 1'b1 };
                end

                AbsoluteIndirect:
                begin
                    o_addr = { r_OPERAND2, r_OPERAND1 + 1'b1 };
                end

                default:
                begin
                    Error( "Invalid addressing mode in output address logic" );
                end
            endcase
        end

        ReadIndirect1:
        begin
            assert ( r_addressingMode == IndexedIndirect );
            o_addr = { 8'h00, r_INDIRECTL_addr };
        end

        ReadIndirect2:
        begin
            assert ( r_addressingMode == IndexedIndirect );
            o_addr = {  8'h00, r_INDIRECTL_addr + 1'b1 }; // TODO - boundaries for some addressing modes
        end

        Read1:
        begin
            o_addr = { r_EFFECTIVEH_ADDR, r_EFFECTIVEL_ADDR };
        end

        WriteBack,
        WriteResult:
        begin
            o_addr = { r_EFFECTIVEH_ADDR, r_EFFECTIVEL_ADDR };
        end

        StackRead,
        StackWrite:
        begin
            o_addr = { 8'h01, r_S };
        end

        BrkAux1:
        begin
            o_addr = { 8'hFF, 8'hFE };
        end
        
        BrkAux2:
        begin
            o_addr = { 8'hFF, 8'hFF };
        end

        JsrAux,
        PcInc:
        begin
            o_addr = r_PC;
        end

        default:
        begin
            Error( "Invalid state in output address logic" );
            o_addr = 0;
        end
    endcase
end

// Next-state logic
always_comb
begin
    r_mainState_nxt = r_mainState;
    r_stackStateCounter_nxt = 0;

    case ( r_mainState )
        Fetch:
        begin

            if ( r_indexerCarry )
            begin
                // If carry is set in Fetch, we're at the second stage of a branch
                r_mainState_nxt = Fetch;
            end
            else
            begin
                r_mainState_nxt = ReadOperand1;
            end
        end

        ReadOperand1:
        begin
            if ( r_operation == JSR )
            begin
                r_mainState_nxt = StackRead;
                r_stackStateCounter_nxt = 0;
            end
            else
            begin
                case( r_addressingMode )
                    Implied,
                    Immediate:
                    begin
                        // Send stack-ops off to specific handlers
                        case ( r_operation )
                            BRK,
                            PHA,
                            PHP:
                            begin
                                r_mainState_nxt = StackWrite;
                            end

                            RTI,
                            RTS,
                            PLA,
                            PLP:
                            begin
                                r_mainState_nxt = StackRead;
                            end
                            default:
                            begin
                                r_mainState_nxt = Fetch;
                            end
                        endcase
                    end

                    Absolute,
                    AbsoluteIndexed,
                    AbsoluteIndirect,
                    Relative:
                    begin
                        r_mainState_nxt = ReadOperand2;
                    end

                    ZeroPage:
                    begin
                        r_mainState_nxt = ( r_operationAccessType == Access_Write ) ? WriteResult : ReadMem1;
                    end

                    ZeroPageIndexed:
                    begin
                        r_mainState_nxt = ReadMem1;
                    end

                    IndexedIndirect,
                    IndirectIndexed:
                    begin
                        r_mainState_nxt = ReadMem1;
                    end

                    default:
                    begin
                        Error( "Invalid addressing mode in next-state logic" );
                    end
                endcase
            end
        end
        ReadOperand2:
        begin
            case( r_addressingMode )
                Absolute:
                begin
                    if ( r_operation == JMP ) r_mainState_nxt = Fetch;
                    else r_mainState_nxt = ( r_operationAccessType == Access_Write ) ? WriteResult : ReadMem1;
                end

                AbsoluteIndexed:
                begin
                    r_mainState_nxt = Read1;
                end

                AbsoluteIndirect:
                begin
                    r_mainState_nxt = ReadMem1;
                end

                Relative:
                begin
                    // If we're not branching, the value in OPERAND2 becomes the new OPCODE.
                    // If we are branching, we need to fetch the new opcode.
                    r_mainState_nxt = l_shouldBranch ? Fetch : ReadOperand1;
                end

                default:
                begin
                    Error( "Invalid addressing mode in next-state logic" );
                end
            endcase

        end
        ReadMem1:
        begin
            case( r_addressingMode )
                Absolute,
                ZeroPage:
                begin
                    r_mainState_nxt = ( r_operationAccessType == Access_Read ) ? Fetch : WriteBack;
                end

                ZeroPageIndexed:
                begin
                    r_mainState_nxt = ( r_operationAccessType == Access_Write ) ? WriteResult : Read1;
                end

                AbsoluteIndirect,
                IndexedIndirect,
                IndirectIndexed:
                begin
                    r_mainState_nxt = ReadMem2;
                end

                AbsoluteIndexed:
                begin
                    r_mainState_nxt = Read1;
                end

                AbsoluteIndirect:
                begin
                    r_mainState_nxt = ReadMem2;
                end

                default:
                begin
                    Error( "Invalid addressing mode in next-state logic" );
                end
            endcase
        end
        ReadMem2:
        begin
            case( r_addressingMode )
                IndexedIndirect,
                IndirectIndexed:
                begin
                    // TODO - fix addr
                    r_mainState_nxt = ReadIndirect1;
                end

                AbsoluteIndirect:
                begin
                    r_mainState_nxt = Fetch;
                end

                default:
                begin
                    Error( "Invalid addressing mode in next-state logic" );
                end
            endcase
        end
        ReadIndirect1:
        begin
            case( r_addressingMode )
                IndexedIndirect:
                begin
                    r_mainState_nxt = Fetch;
                end

                IndirectIndexed,
                AbsoluteIndexed:
                begin
                    // TODO - fix addr for IndirectIndexed and AbsoluteIndexed
                    r_mainState_nxt = ReadIndirect2;
                end

                default:
                begin
                    Error( "Invalid addressing mode in next-state logic" );
                end
            endcase
        end
        ReadIndirect2:
        begin
            case( r_addressingMode )
                IndirectIndexed,
                AbsoluteIndexed:
                begin
                    r_mainState_nxt = Fetch;
                end

                default:
                begin
                    Error( "Invalid addressing mode in next-state logic" );
                end
            endcase
        end

        Read1:
        begin
            case ( r_addressingMode )
                IndirectIndexed,
                AbsoluteIndexed:
                begin
                    case ( r_operationAccessType )
                        Access_Read:
                        begin
                            r_mainState_nxt = ( r_indexerCarry == 1'b1 ) ? Read2 : Fetch;
                        end
                        
                        Access_ReadWrite:
                        begin
                            // Will always have re-read
                            r_mainState_nxt = Read2;
                        end

                        Access_Write:
                        begin
                            // Time to write-out result
                            r_mainState_nxt = WriteResult;
                        end

                        default:
                        begin
                            Error( "Invalid op access type in state Read1" );
                        end

                    endcase
                end

                default:
                begin
                    case( r_operationAccessType )
                        Access_Read:
                        begin
                            r_mainState_nxt = Fetch;
                        end
                        Access_ReadWrite:
                        begin
                            // Need to write-back whatever value was read
                            r_mainState_nxt = WriteBack;
                        end

                        default:
                        begin
                            Error( "Invalid op access type in state Read1: " );
                        end
                    endcase
                end
            endcase
        end

        Read2:
        begin
            // Re-read state for indexed RW, and fixed indexed R
            case ( r_operationAccessType )
                Access_Read:
                begin
                    // If only reading, we're done
                    r_mainState_nxt = Fetch;
                end

                Access_ReadWrite:
                begin
                    // Prepare to write out result
                    r_mainState_nxt = WriteBack;
                end

                default:
                begin
                    Error( "Invalid addressing type in next-state logic" );
                end
            endcase
        end

        WriteBack:
        begin
            // Write-back state for RW
            r_mainState_nxt = WriteResult;
        end

        WriteResult:
        begin
            // Write out result
            r_mainState_nxt = Fetch;
        end

        StackRead:
        begin
            r_mainState_nxt = StackRead;
            case ( r_stackStateCounter )
                2'b00:
                begin
                    if ( r_operation == JSR ) begin
                        r_mainState_nxt = StackWrite;
                        r_stackStateCounter_nxt = 2'b00;
                    end
                    else begin
                        r_stackStateCounter_nxt = 2'b01;
                    end
                end

                2'b01:
                begin
                    case( r_operation )
                        PLA,
                        PLP:
                        begin
                            r_mainState_nxt = Fetch;
                            r_stackStateCounter_nxt = 2'b00;
                        end

                        RTS,
                        RTI:
                        begin
                            r_stackStateCounter_nxt = 2'b10;
                        end

                        default:
                        begin
                            Error( "Invalid operation in next-state logic" );
                        end
                    endcase
                end

                2'b10:
                begin
                    case( r_operation )
                        RTS:
                        begin
                            r_mainState_nxt = PcInc;
                            r_stackStateCounter_nxt = 2'b00;
                        end

                        RTI:
                        begin
                            r_stackStateCounter_nxt = 2'b11;
                        end

                        default:
                        begin
                            Error( "Invalid operation in next-state logic" );
                        end
                    endcase
                end

                2'b11:
                begin
                    case( r_operation )
                        RTI:
                        begin
                            r_mainState_nxt = Fetch;
                            r_stackStateCounter_nxt = 2'b00;
                        end

                        default:
                        begin
                            Error( "Invalid operation in next-state logic" );
                        end
                    endcase
                end
            endcase
        end

        StackWrite:
        begin
            case ( r_stackStateCounter )
            2'b00:
            begin
                case( r_operation )
                    PHA,
                    PHP:
                    begin
                        r_mainState_nxt = Fetch;
                        r_stackStateCounter_nxt = 2'b00;
                    end

                    JSR,
                    BRK:
                    begin
                        r_mainState_nxt = StackWrite;
                        r_stackStateCounter_nxt = 2'b01;
                    end
                endcase
            end
            2'b01:
            begin
                case( r_operation )
                    JSR:
                    begin
                        r_mainState_nxt = JsrAux;
                        r_stackStateCounter_nxt = 2'b00;
                    end
                    BRK:
                    begin
                        r_mainState_nxt = StackWrite;
                        r_stackStateCounter_nxt = 2'b10;
                    end
                endcase
            end
            2'b10:
            begin
                case( r_operation )
                    BRK:
                    begin
                        r_mainState_nxt = BrkAux1; // TODO - fix - Needs to read PC from 0xFFFE
                        r_stackStateCounter_nxt = 2'b00;
                    end

                    default:
                    begin
                        Error( "Invalid operation in next-state logic" );
                    end
                endcase
            end
            2'b11:
            begin
                Error( "Invalid stack-write state in next-state logic" );
            end
            endcase
        end

        BrkAux1:
        begin
            r_mainState_nxt = BrkAux2;
        end
        
        BrkAux2,
        JsrAux,
        PcInc:
        begin
            r_mainState_nxt = Fetch;
        end

        Jam:
        begin
            r_mainState_nxt = Jam;
        end
    endcase
end

// Main-state sequential block
always_ff @( posedge i_clk, negedge i_rst )
begin
    if ( ~i_rst )
    begin
        r_mainState         <= Fetch;
        r_stackStateCounter <= 2'b0;
        r_OPCODE            <= NOP;

        r_A                 <= 8'h00;
        r_X                 <= 8'h00;
        r_Y                 <= 8'h00;
        r_S                 <= 8'hFD;
        r_P                 <= 8'h34;
        r_PC                <= 16'h0400;

        r_OPERAND1          <= 0;
        r_OPERAND2          <= 0;
        r_EFFECTIVEL_ADDR   <= 0;
        r_EFFECTIVEH_ADDR   <= 0;
        r_INDIRECTL_addr    <= 0;
        r_WORKINGL          <= 0;
        r_WORKINGH          <= 0;
        r_indexerCarry      <= 0;
    end
    else
    begin
        r_mainState         <= r_mainState_nxt;
        r_stackStateCounter <= r_stackStateCounter_nxt;
        r_OPCODE            <= r_OPCODE_nxt;

        r_A                 <= r_A_nxt;
        r_X                 <= r_X_nxt;
        r_Y                 <= r_Y_nxt;
        r_S                 <= r_S_nxt;
        r_P                 <= r_P_nxt;
        r_PC                <= r_PC_nxt;

        r_OPERAND1          <= r_OPERAND1_nxt;
        r_OPERAND2          <= r_OPERAND2_nxt;
        r_EFFECTIVEL_ADDR   <= r_EFFECTIVEL_ADDR_nxt;
        r_EFFECTIVEH_ADDR   <= r_EFFECTIVEH_ADDR_nxt;
        r_INDIRECTL_addr    <= r_INDIRECTL_addr_nxt;
        r_WORKINGL          <= r_WORKINGL_nxt;
        r_WORKINGH          <= r_WORKINGH_nxt;
        r_indexerCarry      <= r_indexerCarry_nxt;
    end
end

function string GetStatusString();
    return $sformatf ( "%s%s_%s%s%s%s%s",
            ( r_P[ NEGATIVE_BIT ] ? "N" : "n" ),
            ( r_P[ OVERFLOW_BIT ] ? "V" : "v" ),
            ( r_P[ BREAK_BIT ] ? "B" : "b" ),
            ( r_P[ DECIMAL_BIT ] ? "D" : "d" ),
            ( r_P[ INTERRUPT_BIT ] ? "I" : "i" ),
            ( r_P[ ZERO_BIT ] ? "Z" : "z" ),
            ( r_P[ CARRY_BIT ] ? "C" : "c" )
    );
endfunction

function string GetStateString();
    return $sformatf ( "A: 0x%0X\nX: 0x%0X\nY: 0x%0X\nSP: 0x%0X\nP: %s\nPC: 0x%0X\nOpcode: 0x%0X\nOperation: %s\nAddressing Mode: %s\nAccessType: %s\nMain State: %s",
            r_A, r_X, r_Y, r_S, GetStatusString(), r_PC,
            r_OPCODE, r_operation.name(), r_addressingMode.name(), r_operationAccessType.name(), r_mainState.name()
    );
endfunction

function void Error( string msg );
    $error( $sformatf ( "%s\n%s", msg, GetStateString() ) );
    $fatal( 0 );
endfunction

endmodule
