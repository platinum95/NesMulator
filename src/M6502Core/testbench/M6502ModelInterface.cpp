#include "O2.h"

#include <iostream>
#include <svdpi.h>
#include <vector>
// IO Funcs for memory access through SV
extern "C" {
    char svMemoryRead( short int address );
    void svMemoryWrite( short int address, char value );
} // extern "C"

struct CPUState {
    short int PC;
	char A, X, Y, S;
    char P;
};

class M6502Model : public O2::CPU {
public:
    M6502Model() 
    : O2::CPU( [this]( uint16_t addr ) 
        {
            auto val = static_cast<uint8_t>( svMemoryRead( static_cast<short int>( addr ) ) );
            //std::cout << "Reading 0x" << std::hex << static_cast<uint32_t>( val ) << " from 0x" << std::hex << addr << std::endl;
            return val; 
        },
               [this]( uint16_t addr, uint8_t val ) { svMemoryWrite( static_cast<short int>( addr ), static_cast<char>( val ) ); } ) {}

    CPUState GetCPUState() {
        cpuState = CPUState {
            .PC = static_cast<short int>( PC ),
            .A = static_cast<char>( A ),
            .X = static_cast<char>( X ),
            .Y = static_cast<char>( Y ),
            .S = static_cast<char>( S ),
            .P = static_cast<char>( CompressStatus() )
        };

        return cpuState;
    }

private:
    uint8_t CompressStatus() {
        uint8_t status = 0;
        for( uint8_t i = 0; i < 8; ++i ) {
            status |= ( ( P[ i ] ? 0x01 : 0x00 ) << i );
        }
        return status;
    }

    // Passed by reference to SV, so need to keep in memory here
    CPUState cpuState;
};

static M6502Model m6502Model;

extern "C" {

DPI_DLLESPEC
void ResetModel() {
    std::cout << "M6502ModelInterface::ResetModel" << std::endl;
    m6502Model.unhalt();
    m6502Model.unraise( O2::RESET );
    m6502Model.PC = 0x400;
}

void Tick( CPUState* state ) {
    //std::cout << "M6502ModelInterface::Tick" << std::endl;
    m6502Model.cycle();
    *state = m6502Model.GetCPUState();
}


} // extern "C"
