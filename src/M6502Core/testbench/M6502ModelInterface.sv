`timescale 1ns / 1ps

module M6502ModelInterface();

typedef struct {
    byte PC;
    byte A, X, Y, S;
    byte P;
} CPUState;

import "DPI-C" function void ResetModel();
import "DPI-C" function void Tick();
export "DPI-C" function svMemoryRead;
export "DPI-C" function svMemoryWrite;

function svMemoryRead( input shortint address );
    byte value;

    return value;
endfunction

function svMemoryWrite( input shortint address, byte value );
endfunction


endmodule