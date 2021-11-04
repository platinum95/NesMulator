`timescale 1ns / 1ps

package M6502Defs;

typedef enum 
{
    AluOperation_ADC,
    AluOperation_INC,
    AluOperation_DEC,
    AluOperation_SBC,
    AluOperation_CMP,
    AluOperation_AND,
    AluOperation_OR,
    AluOperation_EOR,
    AluOperation_ASL,
    AluOperation_ROL,
    AluOperation_ROR,
    AluOperation_LSR
} AluOperation;

typedef enum {
    CARRY_BIT = 0,
    ZERO_BIT = 1,
    INTERRUPT_BIT = 2,
    DECIMAL_BIT = 3,
    BREAK_BIT = 4,
    OVERFLOW_BIT = 6,
    NEGATIVE_BIT = 7
} StatusBits;

typedef enum {
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

typedef enum {
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
} Operation;

typedef enum {
    Access_Read,
    Access_Write,
    Access_ReadWrite
} AccessType;

endpackage
