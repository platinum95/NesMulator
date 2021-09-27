`timescale 1ns / 1ps

`define DECL_SM_REG( NAME, WIDTH, DEFAULT ) \
    reg[ WIDTH-1:0 ] r_NAME_nxt = DEFAULT; \
    reg[ WIDTH-1:0 ] r_NAME = DEFAULT;

module M6502(
    input   wire            i_clk,
    input   wire            i_rst,
    input   wire            i_nmi,
    input   wire            i_irq,
    inout   wire[ 7:0 ]     io_data,
    output  reg[ 16:0 ]    o_addr,
    output  wire            i_rw
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
reg[ 7:0 ] r_INDIRECTL_nxt = 0;
reg[ 7:0 ] r_INDIRECTL = 0;

reg[ 7:0 ] r_INDIRECTH_nxt = 0;
reg[ 7:0 ] r_INDIRECTH = 0;

// Working data
reg[ 7:0 ] r_WORKINGL_nxt = 0;
reg[ 7:0 ] r_WORKINGL = 0;

reg[ 7:0 ] r_WORKINGH_nxt = 0;
reg[ 7:0 ] r_WORKINGH = 0;

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
} AddressingMode;

logic r_addressingMode;
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
logic[ 7:0 ] r_resultantData = 0;

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

    BRK,
    JMP,
    JSR,
    NOP,
    RTI,
    RTS
} Operations;

logic r_operation;

// Decode operation
always_comb
begin
    r_resultantData = 0;
    case( w_c )
        2'b00:
        begin
            // TODO
            r_operation = NOP;
        end

        2'b01:
        begin
            case( w_a )
                0:
                begin
                    r_operation = ORA;
                    r_resultantData = w_aluOut;
                end
                1:
                begin
                    r_operation = AND;
                    r_resultantData = w_aluOut;
                end
                2:
                begin
                    r_operation = EOR;
                    r_resultantData = w_aluOut;
                end
                3:
                begin
                    r_operation = ADC;
                    r_resultantData = w_aluOut;
                end
                4:
                begin
                    r_operation = STA;
                    
                end
                5:
                begin
                    r_operation = LDA;
                    r_resultantData = r_workingDataA;
                end
                6:
                begin
                    r_operation = CMP;
                    r_resultantData = 0;
                end
                7:
                begin
                    r_operation = SBC;
                    r_resultantData = w_aluOut;
                end

            endcase
        end

        2'b10:
        begin
            // TODO - Some of these NOPs are JAMs
            if ( w_b == 0 && w_a != 5 )
            begin
                r_operation = NOP;
            end
            else if ( w_b == 4 )
            begin
                r_operation = NOP;
            end
            else if ( w_b == 6 && !( w_a == 4 || w_a == 5 ) )
            begin
                r_operation = NOP;
            end
            else if ( w_b == 7 && w_a == 4 )
            begin
                r_operation = NOP;
            end
            else
            begin
                case( w_a )
                    0:
                    begin
                        r_operation = ASL;
                        r_resultantData = w_aluOut;
                    end
                    1:
                    begin
                        r_operation = ROL;
                        r_resultantData = w_aluOut;
                    end
                    2:
                    begin
                        r_operation = LSR;
                        r_resultantData = w_aluOut;
                    end
                    3:
                    begin
                        r_operation = ROR;
                        r_resultantData = w_aluOut;
                    end
                    4:
                    begin
                        if ( w_b == 2 )
                        begin
                            r_operation = TXA;
                            r_resultantData = r_A;
                        end
                        else if ( w_b == 6 )
                        begin
                            r_operation = TXS;
                            r_resultantData = r_X;
                        end
                        else
                        begin
                            r_operation = STX;
                            r_resultantData = r_X;
                        end                       
                    end
                    5:
                    begin
                        if ( w_b == 2 )
                        begin
                            r_operation = TAX;
                            r_resultantData = r_A;
                        end
                        else if ( w_b == 6 )
                        begin
                            r_operation = TSX;
                            r_resultantData = r_S;
                        end
                        else
                        begin
                            r_operation = LDX;
                            r_resultantData = r_workingDataA;
                        end
                    end
                    6:
                    begin
                        r_operation = DEC;
                        r_resultantData = w_aluOut;
                    end
                    7:
                    begin
                        r_operation = INC;
                        r_resultantData = w_aluOut;
                    end
                endcase
            end
        end

        2'b11:
        begin
            r_operation = NOP;
        end
    endcase
end

// Signal that input data is ready
logic r_readReady = 1'b0;
always_comb
begin
    r_readReady = 1'b0;
    case( r_addressingMode )
        Implied:
        begin
            r_readReady = ( r_mainState == ReadOperand1 );
        end

        Immediate:
        begin
            r_readReady = ( r_mainState == ReadOperand1 );
        end

        Absolute:
        begin
            r_readReady = ( r_mainState == ReadOperand2 );
        end

        ZeroPage:
        begin
            r_readReady = ( r_mainState == ReadMem1 );
        end

        ZeroPageIndexed:
        begin
            r_readReady = ( r_mainState == ReadIndirect1 );
        end

        AbsoluteIndexed:
        begin
            // Goto Indirect1 if invalid, then Indirect2.
            // Go straight to Indirect2 if valid
            r_readReady = ( r_mainState == ReadIndirect2 );
        end

        Relative:
        begin
            r_readReady = ( r_mainState == ReadOperand1 );
        end

        IndexedIndirect:
        begin
            r_readReady = ( r_mainState == ReadIndirect1 );
        end

        IndirectIndexed:
        begin
            r_readReady = ( r_mainState == ReadIndirect2 );
        end

        AbsoluteIndirect:
        begin
            r_readReady = ( r_mainState == ReadIndirect2 );
        end
    endcase
end


// Signal operation access type, used in conjunction with AddressingMode
enum {
    Access_Read,
    Access_Write,
    Access_ReadWrite
} OperationAccessType;

logic[ 1:0 ] r_operationAccessType = Access_Read;
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

// Register-updating logic.
// TODO -  Remove resultantData and just assign straight from source
always_comb
begin
    r_A_nxt = r_A;
    r_X_nxt = r_X;
    r_Y_nxt = r_Y;
    r_S_nxt = r_S;
    r_P_nxt = r_P;
    r_PC_nxt = r_PC;

    if ( r_mainState == Fetch )
    begin
        // Always inc PC after fetch
        r_PC_nxt = r_PC + 1;
    end
    else if ( ( r_mainState >= ReadOperand1 || r_mainState == ReadOperand2 ) && r_addressingMode != Implied )
    begin
        // Inc PC if the operation has operands
        r_PC_nxt = r_PC + 1;
    end
    else if ( r_mainState == PcInc )
    begin
        r_PC_nxt = r_PC + 1;
    end

    if ( r_readReady )
    begin
        case( r_operation )
            PLA,
            TYA,
            TXA,
            LDA,
            ADC,
            AND,
            ORA,
            SBC:
            begin
                // ALU Operations and register-transfers
                r_A_nxt = r_resultantData;
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
                    r_A_nxt = r_resultantData;
                end
            end

            TSX,
            TAX,
            LDX,
            DEX,
            INX:
            begin
                r_X_nxt = r_resultantData;    
            end

            TAY,
            LDY,
            DEY,
            INY:
            begin
                r_Y_nxt = r_resultantData;    
            end

            PLP:
            begin
                r_P_nxt = r_resultantData;
            end

            TXS:
            begin
                r_S_nxt = r_resultantData;
            end

            PHP,
            PHA:
            begin
                // TODO - Get time to increment, also direction
                if ( r_mainState == 1 )
                begin
                    r_S_nxt = r_S + 1;    
                end
            end

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
            BRK,
            JMP,
            JSR,
            NOP,
            RTI,
            RTS:
            begin
                
            end
            
        endcase
    end
end

/************************
* Main state logic
*************************/
enum {
    Fetch,
    ReadOperand1,
    ReadOperand2,
    ReadMem1,
    ReadMem2,
    ReadIndirect1,
    ReadIndirect2,
    Write,

    // Extra states
    StackRead_IncS,
    StackRead1,
    StackRead2,
    StackRead3,
    StackWrite1,
    StackWrite2,
    StackWrite3,

    PcInc,

    Jam
} MainStates;

reg r_mainState = Fetch;
reg r_mainState_nxt = Fetch;

// Output address logic
always_comb
begin
    case ( r_mainState )
        Fetch:
        begin
            o_addr = r_PC;
        end

        ReadOperand1:
        begin
            // if ( stack )
            // begin
            //     o_addr = r_S;                
            // end
            // else
            // begin
            o_addr = r_PC;
            // end
        end

        ReadOperand2:
        begin
            o_addr = r_PC;
        end

        ReadMem1:
        begin
            o_addr = w_operandAddress;
        end

        ReadMem2:
        begin
            o_addr = w_operandAddress + 1; // TODO - boundaries for some addressing modes
        end

        ReadIndirect1:
        begin
            o_addr = { r_EFFECTIVEH_ADDR, r_EFFECTIVEL_ADDR };
        end

        ReadIndirect2:
        begin
            o_addr = { r_EFFECTIVEH_ADDR, r_EFFECTIVEL_ADDR } + 1; // TODO - boundaries for some addressing modes
        end

        Write:
        begin
            if ( r_addressingMode == Implied )
            begin
                o_addr = { 0, r_S };
            end
            else
            begin
                o_addr = { r_EFFECTIVEH_ADDR, r_EFFECTIVEL_ADDR };
            end
        end

        default:
        begin
            // TODO - error
            o_addr = 0;
        end
    endcase
end

// Opcode capturing.
// TODO - may need to be moved to single block that captures/sets io_data
always_comb
begin
    r_OPCODE_nxt = r_OPCODE;
    if ( r_mainState == Fetch )
    begin
        r_OPCODE_nxt = io_data;
    end
end

// Next-state logic
always_comb
begin
    r_mainState_nxt = r_mainState;

    case ( r_mainState )
        Fetch:
        begin
            r_mainState_nxt = ReadOperand1;
        end

        ReadOperand1:
        begin
            case( r_addressingMode )
                Implied,
                Immediate:
                begin
                    case ( r_operation )
                        BRK,
                        PHA,
                        PHP:
                        begin
                            r_mainState_nxt = StackWrite1;
                        end
                        PLA,
                        PLP:
                        begin
                            r_mainState_nxt = StackRead_IncS;
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
                    r_mainState_nxt = Fetch;
                end

                AbsoluteIndexed:
                begin
                    r_mainState_nxt = ReadMem1;
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
                    // TODO - fix addr
                    r_mainState_nxt = ReadIndirect1;
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

        Write:
        begin

        end


        StackRead_IncS:
        begin
           r_mainState_nxt = StackRead1; 
        end
        StackRead1:
        begin
            case( r_operation )
                PLA,
                PLP:
                begin
                    r_mainState_nxt = Fetch;
                end

                RTS,
                RTI:
                begin
                    r_mainState_nxt = StackRead2;
                end

                default:
                begin
                    // TODO - error
                end
            endcase
        end
        StackRead2:
        begin
            case( r_operation )
                RTS:
                begin
                    r_mainState_nxt = PcInc;
                end

                RTI:
                begin
                    r_mainState_nxt = StackRead3;
                end

                default:
                begin
                    // TODO - error
                end
            endcase
        end
        StackRead3:
        begin
            case( r_operation )
                RTI:
                begin
                    r_mainState_nxt = PcInc;
                end

                default:
                begin
                    // TODO - error
                end
            endcase            
        end
        StackWrite1:
        begin
            case( r_operation )
                PHA,
                PHP:
                begin
                    r_mainState_nxt = Fetch;
                end

                JSR,
                BRK:
                begin
                    r_mainState_nxt = StackWrite2;
                end
            endcase
        end
        StackWrite2:
        begin
            case( r_operation )
                JSR:
                begin
                    r_mainState_nxt = PcInc; // TODO - fix - Needs to read PC from mem
                end
                BRK:
                begin
                    r_mainState_nxt = StackWrite3;
                end

                default:
                begin
                    // TODO - error
                end
            endcase
        end
        StackWrite3:
        begin
            case( r_operation )
                BRK:
                begin
                    r_mainState_nxt = PcInc; // TODO - fix - Needs to read PC from 0xFFFE
                end

                default:
                begin
                    // TODO - error
                end
            endcase
        end

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
        r_mainState <= Fetch;
    end
    else
    begin
        r_mainState <= r_mainState_nxt;
    end
end


/***********************************
* Operational logic
************************************/
always_comb
begin
    case( r_mainState )
        Fetch:
        begin

        end

        Write:
        begin
            
        end
    endcase

end



endmodule
