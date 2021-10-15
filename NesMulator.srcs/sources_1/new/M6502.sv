`timescale 1ns / 1ps

`define DECL_SM_REG( NAME, WIDTH, DEFAULT ) \
    reg[ WIDTH-1:0 ] r_NAME_nxt = DEFAULT; \
    reg[ WIDTH-1:0 ] r_NAME = DEFAULT;

module M6502(
    input   wire            i_clk,
    input   wire            i_rst,
    input   wire            i_nmi,
    input   wire            i_irq,
    inout   logic[ 7:0 ]    io_data,
    output  reg[ 15:0 ]    o_addr,
    output  wire            o_rw
);

`define CARRY_BIT 0
`define ZERO_BIT 1
`define INTERRUPT_BIT 2
`define DECIMAL_BIT 3
`define BREAK_BIT 4
// Unused bit
`define OVERFLOW_BIT 6
`define NEGATIVE_BIT 7

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

    // New states to replace the old ones
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
enum {
    Implied,
    Immediate,
    Absolute,
    ZeroPage,
    ZeroPageIndexed,
    AbsoluteIndexed,
    Relative,
    IndexedIndirect,
    IndirectIndexed,
    AbsoluteIndirect
} r_addressingMode;

logic[ 7:0 ] r_indexingIndex; // For ZeroPageIndexed/AbsoluteIndexed

/*******************************
* Temporary ALU dummy
********************************/
wire[ 7:0 ] w_aluOperation;
wire[ 7:0 ] w_aluInA;
wire[ 7:0 ] w_aluInB;
wire[ 7:0 ] w_aluOut;
wire[ 7:0 ] w_aluStatusIn;
wire[ 7:0 ] w_aluStatusOut;

/*******************************
* Combinational Opcode Decoder
********************************/
logic[ 7:0 ] r_workingDataA = 0;
logic[ 7:0 ] r_workingDataB = 0;

wire[ 2:0 ] w_a;
wire[ 2:0 ] w_b;
wire[ 1:0 ] w_c;

assign w_a = r_OPCODE_nxt[ 7:5 ];
assign w_b = r_OPCODE_nxt[ 4:2 ];
assign w_c = r_OPCODE_nxt[ 1:0 ];

// Decode addressing mode
always_comb
begin
    r_indexingIndex = 0;

    case ( w_b )
        0:
        begin
            case( w_c )
                2'b00:
                begin
                    if ( w_a >= 4 )
                    begin
                        r_addressingMode = Immediate;
                    end
                    else if ( w_a == 1 )
                    begin
                        r_addressingMode = Absolute;
                    end
                    else
                    begin
                        r_addressingMode = Implied;
                    end
                end
                2'b01:
                begin
                    r_addressingMode = IndexedIndirect;
                end
                2'b10:
                begin
                    r_addressingMode = Immediate;
                end
                2'b11:
                begin
                    // Illegal opcodes
                    r_addressingMode = IndexedIndirect;
                end
            endcase            
        end

        1:
        begin
            r_addressingMode = ZeroPage;
        end

        2:
        begin
            if ( w_c[ 0 ] == 0 )
            begin
                r_addressingMode = Implied;
            end
            else
            begin
                r_addressingMode = Immediate;
            end
        end

        3:
        begin
            r_addressingMode = Absolute;
        end

        4:
        begin
            if ( w_c[ 0 ] == 0 )
            begin
                r_addressingMode = Relative;
            end
            else
            begin
                r_addressingMode = IndirectIndexed;
            end
        end

        5:
        begin
            r_addressingMode = ZeroPageIndexed;
            if ( w_c >= 2 && ( w_a == 4 || w_a == 5 ) )
            begin
                r_indexingIndex = r_Y;
            end
            else
            begin
                r_indexingIndex = r_X;
            end
        end

        6:
        begin
            if ( w_c[ 0 ] == 0 )
            begin
                r_addressingMode = Implied;
            end
            else
            begin
                r_addressingMode = AbsoluteIndexed;
                r_indexingIndex = r_Y;;
            end
        end

        7:
        begin
            r_addressingMode = AbsoluteIndexed;

            if ( w_c >= 2 && ( w_a == 4 || w_a == 5 ) )
            begin
                r_indexingIndex = r_Y;
            end
            else
            begin
                r_indexingIndex = r_X;
            end
        end
    endcase
end

// Operation decoding logic
enum {
    // ALU Ops
    ADC,
    AND,
    ASL,
    DEC,
    DEX,
    INX,
    DEY,
    INY,
    EOR,
    INC,
    ORA,
    ROL,
    ROR,
    SBC,

    // Compares
    CMP,
    CPX,
    CPY,
    
    // Loads
    LDA,
    LDX,
    LDY,
    LSR,

    // Stores
    STA,
    STX,
    STY,

    // Register-transfer ops
    TAX,
    TXA,
    TAY,
    TYA,
    TXS,
    TSX,

    // Stack ops
    PHA,
    PLA,
    PHP,
    PLP,

    // Status ops
    CLC,
    SEC,
    CLI,
    SEI,
    CLV,
    CLD,
    SED,

    // Branch ops
    BPL,
    BMI,
    BVC,
    BVS,
    BCC,
    BCS,
    BNE,
    BEQ,

    BIT,
    BRK,
    JMP,
    JSR,
    NOP,
    RTI,
    RTS,
    JAM
} r_operation;

// Decode operation
always_comb
begin
    case( w_c )
        2'b00:
        begin
            r_operation = NOP;
            case ( w_b )
                0:
                begin
                    case ( w_a )
                        0: r_operation = BRK;
                        1: r_operation = JSR;
                        2: r_operation = RTI;
                        3: r_operation = RTS;
                        4: r_operation = NOP; // TODO
                        5: r_operation = LDY;
                        6: r_operation = CPY;
                        7: r_operation = CPX;
                    endcase
                end
                1:
                begin
                    case ( w_a )
                        0: r_operation = NOP; // TODO
                        1: r_operation = BIT;
                        2: r_operation = NOP; // TODO
                        3: r_operation = NOP; // TODO
                        4: r_operation = STY;
                        5: r_operation = LDY;
                        6: r_operation = CPY;
                        7: r_operation = CPX;
                    endcase
                end
                2:
                begin
                    case ( w_a )
                        0: r_operation = PHP;
                        1: r_operation = PLP;
                        2: r_operation = PHA;
                        3: r_operation = PLA;
                        4: r_operation = DEY;
                        5: r_operation = TAY;
                        6: r_operation = INY;
                        7: r_operation = INX;
                    endcase
                end
                3:
                begin
                    case ( w_a )
                        0: r_operation = NOP; // TODO
                        1: r_operation = BIT;
                        2: r_operation = JMP;
                        3: r_operation = JMP;
                        4: r_operation = STY;
                        5: r_operation = LDY;
                        6: r_operation = CPY;
                        7: r_operation = CPX;
                    endcase
                end
                4:
                begin
                    case ( w_a )
                        0: r_operation = BPL;
                        1: r_operation = BMI;
                        2: r_operation = BVC;
                        3: r_operation = BVS;
                        4: r_operation = BCC;
                        5: r_operation = BCS;
                        6: r_operation = BNE;
                        7: r_operation = BEQ;
                    endcase
                end
                5:
                begin
                    case ( w_a )
                        0: r_operation = NOP; // TODO
                        1: r_operation = NOP; // TODO
                        2: r_operation = NOP; // TODO
                        3: r_operation = NOP; // TODO
                        4: r_operation = STY;
                        5: r_operation = LDY;
                        6: r_operation = NOP; // TODO
                        7: r_operation = NOP; // TODO
                    endcase
                end
                6:
                begin
                    case ( w_a )
                        0: r_operation = CLC;
                        1: r_operation = SEC;
                        2: r_operation = CLI;
                        3: r_operation = SEI;
                        4: r_operation = TYA;
                        5: r_operation = CLV;
                        6: r_operation = CLD;
                        7: r_operation = SED;
                    endcase
                end
                7:
                begin
                    case ( w_a )
                        0: r_operation = NOP; // TODO
                        1: r_operation = NOP; // TODO
                        2: r_operation = NOP; // TODO
                        3: r_operation = NOP; // TODO
                        4: r_operation = NOP; // TODO
                        5: r_operation = LDY;
                        6: r_operation = NOP; // TODO
                        7: r_operation = NOP; // TODO
                    endcase
                end
            endcase
        end

        2'b01:
        begin
            case( w_a )
                0: r_operation = ORA;
                1: r_operation = AND;
                2: r_operation = EOR;
                3: r_operation = ADC;
                4: r_operation = STA;
                5: r_operation = LDA;
                6: r_operation = CMP;
                7: r_operation = SBC;
            endcase
        end

        2'b10:
        begin
            if ( w_b == 0 && w_a != 5 )
            begin
                if ( w_a <= 3 )
                begin
                    r_operation = JAM;
                end
                else
                begin
                    r_operation = NOP;
                end
            end
            else if ( w_b == 4 )
            begin
                r_operation = JAM;
            end
            else if ( w_b == 6 && !( w_a == 4 || w_a == 5 ) )
            begin
                r_operation = NOP;
            end
            else if ( w_b == 7 && w_a == 4 )
            begin
                r_operation = NOP;
            end
            else if ( w_a == 7 && w_b == 2 )
            begin
                r_operation = NOP;
            end
            else
            begin
                case( w_a )
                    0: r_operation = ASL;
                    1: r_operation = ROL;
                    2: r_operation = LSR;
                    3: r_operation = ROR;
                    4:
                    begin
                        if ( w_b == 2 )
                        begin
                            r_operation = TXA;
                        end
                        else if ( w_b == 6 )
                        begin
                            r_operation = TXS;
                        end
                        else
                        begin
                            r_operation = STX;
                        end                       
                    end
                    5:
                    begin
                        if ( w_b == 2 )
                        begin
                            r_operation = TAX;
                        end
                        else if ( w_b == 6 )
                        begin
                            r_operation = TSX;
                        end
                        else
                        begin
                            r_operation = LDX;
                        end
                    end
                    6: r_operation = DEC;
                    7: r_operation = INC;
                endcase
            end
        end

        2'b11:
        begin
            // TODO - illegal opcodes
            r_operation = NOP;
        end
    endcase
end

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
            // TODO - branching
            r_readReady = ( r_mainState >= ReadOperand1 );
        end

        IndexedIndirect:
        begin
            r_readReady = ( r_mainState >= Read2 );
        end

        AbsoluteIndirect:
        begin
            // TODO - JMP
            r_readReady = ( r_mainState >= ReadIndirect2 );
        end

        default:
        begin
            // TODO - error
        end
    endcase
end


// Signal operation access type, used in conjunction with AddressingMode
enum {
    Access_Read,
    Access_Write,
    Access_ReadWrite
} r_operationAccessType;

always_comb
begin
    r_operationAccessType = Access_Read;

    case( r_operation )
        ASL,
        DEC,
        DEX,
        INX,
        DEY,
        INY,
        INC,
        ROL,
        ROR,
        LSR:
        begin
            r_operationAccessType = Access_ReadWrite;
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
        ADC,
        AND,
        SBC,
        LDA,
        LDX,
        LDY,
        EOR,
        ORA:
        begin
            r_operationAccessType = Access_Read;
        end

        // Stores
        PHA, // TODO - actually stack-based
        PHP, // TODO - actually stack-based
        STA,
        STX,
        STY:
        begin
            r_operationAccessType = Access_Write;
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
            r_operationAccessType = Access_Read;
        end

        default:
        begin
            // TODO - error
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
        WriteFlag,
        StackWrite:
        begin
            r_readWrite = WriteFlag;
        end

        default:
        begin
            // TODO - error
        end
    endcase
end

// Logic for branch instructions
logic l_shouldBranch = 0;
always_comb
begin
    l_shouldBranch = 0;
    case( r_operation )
        BPL: l_shouldBranch = ( r_P[ `NEGATIVE_BIT ] == 0 );
        BMI: l_shouldBranch = ( r_P[ `NEGATIVE_BIT ] == 1 );
        BVC: l_shouldBranch = ( r_P[ `OVERFLOW_BIT ] == 0 );
        BVS: l_shouldBranch = ( r_P[ `OVERFLOW_BIT ] == 1 );
        BCC: l_shouldBranch = ( r_P[ `CARRY_BIT ] == 0 );
        BCS: l_shouldBranch = ( r_P[ `CARRY_BIT ] == 1 );
        BNE: l_shouldBranch = ( r_P[ `ZERO_BIT ] == 0 );
        BEQ: l_shouldBranch = ( r_P[ `ZERO_BIT ] == 1 );

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
        // Always inc PC after fetch
        r_PC_nxt = r_PC + 1;
        r_OPCODE_nxt = io_data;

        if ( r_indexerCarry )
        begin
            // Just fetched branched opcode, but PCH needs fixing
            r_PC_nxt[ 15:8 ] = ( r_OPERAND1[ 7 ] == 0 ) ?
                r_PC[ 15:8 ] + 1    // Addition
                : r_PC[ 15:8 ] - 1; // Subtraction
        end
        else
        begin
            case ( r_operation )
                BPL,
                BMI,
                BVC,
                BVS,
                BCC,
                BCS,
                BNE,
                BEQ:
                begin
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
                    end
                end

                default:
                begin
                    r_PC_nxt = r_PC + 1;
                end
            endcase
        end
    end
    else
    begin

        if ( ( r_mainState >= ReadOperand1 || r_mainState == ReadOperand2 ) && r_addressingMode != Implied )
        begin
            // Inc PC if the operation has operands
            r_PC_nxt = r_PC + 1;
        end
        else if ( r_mainState == PcInc )
        begin
            r_PC_nxt = r_PC + 1;
        end

        if ( r_mainState == StackRead && r_stackStateCounter == 0 )
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
                                r_P_nxt[ `BREAK_BIT ] = 1'b1;
                            end

                            2'b01:
                            begin
                                r_dataOut = r_PC[ 7:0 ];
                            end

                            2'b10:
                            begin
                                r_dataOut = r_P;
                            end

                            2'b11:
                            begin
                                // TODO - error
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
                        // TODO - error
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
                        // TODO - error
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
                                // TODO - error
                            end
                        endcase
                    end
                    default:
                    begin
                        // TODO - error
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
                                r_dataOut = ( r_operation == PHA ) ? r_A : r_P;
                            end
                            default:
                            begin
                                // TODO - error
                            end
                        endcase
                    end
                    default:
                    begin
                        // TODO - error
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
                                end
                                else
                                begin
                                    r_P_nxt = io_data;
                                end
                            end
                            default:
                            begin
                                // TODO - error
                            end
                        endcase
                    end
                    default:
                    begin
                        // TODO - error
                    end
                endcase
            end

            JSR:
            begin
                case( r_mainState )
                    ReadOperand1:
                    begin
                        // NOP
                    end

                    // TODO - there's a NOP cycle here

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
                                // TODO - error
                            end
                        endcase
                    end

                    JsrAux:
                    begin
                        r_PC_nxt = { io_data, r_OPERAND1 };
                    end
                    default:
                    begin
                        // TODO - error
                    end
                endcase
            end

            JMP:
            begin
                case ( r_mainState )
                    ReadOperand1: r_OPERAND1_nxt = io_data;
                    ReadOperand2: r_PC_nxt = { io_data, r_OPERAND1 };
                endcase
            end

            default:
            begin
                // Get-effective address logic
                if ( r_addressingMode != Implied && r_addressingMode != Immediate && r_mainState < Read1 )
                begin
                    case ( r_mainState_nxt )
                        ReadOperand1:
                        begin
                            case ( r_addressingMode )
                                Absolute,
                                AbsoluteIndexed,
                                ZeroPage:
                                begin
                                    r_EFFECTIVEL_ADDR_nxt = io_data;
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
                                    r_EFFECTIVEH_ADDR_nxt = io_data;
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
                            case ( r_addressingMode )
                                ZeroPageIndexed:
                                begin
                                    r_EFFECTIVEL_ADDR_nxt = io_data + r_indexingIndex;
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

                                default:
                                begin
                                    // TODO - error
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
                                    // TODO - error
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
                                    // TODO - error
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
                                    // TODO - error
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
                                
                                default:
                                begin
                                    // TODO - error
                                end
                            endcase
                        end

                        Read2:
                        begin
                            r_workingDataA = io_data;
                        end
                    endcase

                end

                if ( r_readReady )
                begin
                    // TODO - status register

                    case( r_operation )
                        TYA: r_A_nxt = r_Y;
                        TXA: r_A_nxt = r_X;
                        LDA: r_A_nxt = io_data;

                        ADC,
                        AND,
                        ORA,
                        SBC:
                        begin
                            // ALU Operations and register-transfers
                            r_A_nxt = w_aluOut;
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
                            if ( r_addressingMode == Implied )
                            begin
                                r_A_nxt = w_aluOut;
                            end
                        end

                        TSX: r_X_nxt = r_S;
                        TAX: r_X_nxt = r_A;
                        LDX: r_X_nxt = io_data;
                        DEX,
                        INX:
                        begin
                            r_X_nxt = w_aluOut;
                        end

                        TAY: r_Y_nxt = r_A;
                        LDY: r_Y_nxt = io_data;
                        DEY,
                        INY:
                        begin
                            r_Y_nxt = w_aluOut;
                        end

                        TXS: r_S_nxt = r_X;

                    
                        CLC: r_S_nxt[ `CARRY_BIT ] = 0;
                        SEC: r_S_nxt[ `CARRY_BIT ] = 1;
                        CLI: r_S_nxt[ `INTERRUPT_BIT ] = 0;
                        SEI: r_S_nxt[ `INTERRUPT_BIT ] = 1;
                        CLV: r_S_nxt[ `OVERFLOW_BIT ] = 0;
                        CLD: r_S_nxt[ `DECIMAL_BIT ] = 0;
                        SED: r_S_nxt[ `DECIMAL_BIT ] = 1;

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
                    // TODO - error
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
                    // TODO - error
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
            // TODO - error
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
                // Check the opcode that we just operated on. If it's a branch, then
                // we're still executing it at this point.
                case ( r_operation )
                    BPL,
                    BMI,
                    BVC,
                    BVS,
                    BCC,
                    BCS,
                    BNE,
                    BEQ:
                    begin
                        r_mainState_nxt = ( l_shouldBranch == 1'b1 ) ? Fetch : ReadOperand1;
                    end

                    default:
                    begin
                        r_mainState_nxt = ReadOperand1;
                    end
                endcase
            end
        end

        ReadOperand1:
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

                ZeroPage,
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
                    // TODO - error
                end
            endcase
        end
        ReadOperand2:
        begin
            case( r_addressingMode )
                Absolute:
                begin
                    if ( r_operation == JMP ) r_mainState_nxt = Fetch;
                    else r_mainState_nxt = Read1;
                end
                AbsoluteIndexed:
                begin
                    r_mainState_nxt = Read1;
                end
                AbsoluteIndirect:
                begin
                    r_mainState_nxt = ReadIndirect1;
                end

                Relative:
                begin
                    r_mainState_nxt = Fetch;
                end

                default:
                begin
                    // TODO - error
                end
            endcase

        end
        ReadMem1:
        begin
            case( r_addressingMode )
                Absolute,
                ZeroPage:
                begin
                    r_mainState_nxt = Fetch;
                end
                ZeroPageIndexed:
                begin
                    r_mainState_nxt = ReadIndirect1;
                end

                IndexedIndirect,
                IndirectIndexed:
                begin
                    r_mainState_nxt = ReadMem2;
                end

                AbsoluteIndexed:
                begin
                    r_mainState_nxt = Read1;
                end

                default:
                begin
                    // TODO - error
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

                default:
                begin
                    // TODO - error
                end
            endcase
        end
        ReadIndirect1:
        begin
            case( r_addressingMode )
                ZeroPageIndexed,
                IndexedIndirect:
                begin
                    r_mainState_nxt = Fetch;
                end

                IndirectIndexed,
                AbsoluteIndirect,
                AbsoluteIndexed:
                begin
                    // TODO - fix addr for IndirectIndexed and AbsoluteIndexed
                    r_mainState_nxt = ReadIndirect2;
                end

                default:
                begin
                    // TODO - error
                end
            endcase
        end
        ReadIndirect2:
        begin
            case( r_addressingMode )
                IndirectIndexed,
                AbsoluteIndirect,
                AbsoluteIndexed:
                begin
                    r_mainState_nxt = Fetch;
                end

                default:
                begin
                    // TODO - error
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
                            if ( r_indexerCarry )
                            begin
                                r_mainState_nxt = Read2;
                            end
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
                            // TODO - error
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
                            // TODO - error
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
                    // TODO - error
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
                    // Always increments r_S
                    r_stackStateCounter_nxt = 2'b01;
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
                            // TODO - error
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
                            // TODO - error
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
                            // TODO - error
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
                        r_mainState_nxt = PcInc; // TODO - fix - Needs to read PC from mem
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
                        // TODO - error
                    end
                endcase
            end
            2'b11:
            begin
                // TODO - error
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
        r_S                 <= 8'h00;
        r_P                 <= 8'h00;
        r_PC                <= 8'h00;

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



endmodule
