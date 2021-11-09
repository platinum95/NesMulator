`timescale 1ns / 1ps

`include "Common.sv"

import Common::CPUState;

module M6502ModelInterface();

import "DPI-C" function void ResetModel();
import "DPI-C" function void Tick( output CPUState state );
export "DPI-C" function svMemoryRead;
export "DPI-C" function svMemoryWrite;


// Memory Block, 64k bytes
byte MemoryBlock[ 0:16'hFFFF ] = '{ default:0 };

function byte svMemoryRead( input shortint address );
    logic[15:0] addr = address;
    $display( "Ref: Reading 0x%0X from 0x%0X", MemoryBlock[ addr ], addr );
    return MemoryBlock[ addr ];
endfunction

function svMemoryWrite( input shortint address, byte value );
$display( "Ref: Writing 0x%0X to 0x%0X", value, address );
    MemoryBlock[ address ] = value;
endfunction

initial
begin
    $readmemh( "./6502_functional_test.mem", MemoryBlock );
end

endmodule
