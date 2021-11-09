`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 10/11/2021 07:38:03 PM
// Design Name: 
// Module Name: M6502_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

//package pack1;
//import "DPI-C" function int myFunction1(input int v, output int o); 
//import "DPI-C" function void myFunction2 (input int v1, input int v2, output int o);
//import "DPI-C" function int myFunction3(input int v, output int o); 
//import "DPI-C" function void myFunction4 (input int v1, input int v2, output int o);
//endpackage

`include "Common.sv"
`include "../M6502Defs.sv"

import M6502Defs::AddressingMode;
import Common::CPUState;

module M6502_tb(
    );

logic clk = 0;
logic rst = 1;
logic nmi = 1;
logic irq = 1;
wire[ 7:0 ] data;
logic[ 15:0 ] addr;
logic rw;

M6502ModelInterface modelInterface();

initial begin
   // modelInterface = new();
    modelInterface.ResetModel();
end

M6502 m6502 (
    .i_clk( clk ),
    .i_rst( rst ),
    .i_nmi( nmi ),
    .i_irq( irq ),
    .io_data( data ),
    .o_addr( addr ),
    .o_rw( rw )
);

initial
begin
    forever
    begin
        #4;
        clk = ~clk;
    end
end

int instructionCount = 0;

always @( negedge clk )
begin
    if ( rst == 1'b1 ) begin
        CPUState referenceState;
        modelInterface.Tick( referenceState );
        ValidateState( GetDutState(), referenceState );
        instructionCount = instructionCount + 1;
    end
end

// Memory Block, 64k bytes
byte MemoryBlock[ 0:16'hFFFF ] = '{ default:0 };

initial
begin
    rst = 0;
    $readmemh( "./6502_functional_test.mem", MemoryBlock );
    #(8 * 10 + 2);
    rst = 1;
end

assign data = rw ? 8'hZZ : MemoryBlock[ addr ];

always_ff @( posedge clk )
begin
    if ( rw == 1 /* && ( addr < 16'h0400 || addr > 16'h3832 ) */ )
    begin
        MemoryBlock[ addr ] <= data;
    end
end

function CPUState GetDutState();
    return '{
        m6502.r_PC,
        m6502.r_A, m6502.r_X, m6502.r_Y, m6502.r_S,
        m6502.r_P
    };
endfunction

function string GetStateString( CPUState state );
    return $sformatf( "PC: %0X\nA: %0X\nX: %0X\nY: %0X\nS: %0X\nP: %0X", state.PC, state.A, state.X, state.Y, state.S, state.P );
endfunction

function void ValidateState( CPUState dutState, CPUState referenceState );
    if ( dutState.PC != referenceState.PC
        || dutState.A != referenceState.A
        || dutState.X != referenceState.X
        || dutState.Y != referenceState.Y
        || dutState.S != referenceState.S
        || dutState.P != referenceState.P ) begin
        $error( "State mismatch detected on instruction %0d\nDUT State:\n%s\n\nReference State:\n%s", instructionCount, GetStateString( dutState ), GetStateString( referenceState ) );
        $fatal;
    end
endfunction;

endmodule
