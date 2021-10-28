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

endpackage
