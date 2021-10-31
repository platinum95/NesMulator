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


module M6502_tb(
    );

logic clk = 0;
logic rst = 1;
logic nmi = 1;
logic irq = 1;
wire[ 7:0 ] data;
logic[ 15:0 ] addr;
logic rw;

//import "DPI-C" function void TestDpiFunction ();
//import "DPI-C" pure function int TestDpiFunction2 ();
//import "DPI-C" pure function int test ();

integer test2;
logic[ 7:0 ] test3;
initial
begin
    //TestDpiFunction();
    //test2 = test();//TestDpiFunction2();
    //test3 = test[ 7:0 ];

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

`define NUM_ROMS 1
// ROMs, 512 bytes available each
byte TestROMs[ `NUM_ROMS ][ 0:511 ] = '{ default:0 };

initial
begin
    // TODO - some kind of loop here to load in automatically
    $readmemh( "./test_rom1.mem", TestROMs[ 0 ] );
end

// Test RAM, 512 bytes
byte RAM[ 512 ];

int currentRom = 0;

reg[ 7:0 ] l_sendData;
assign data = rw ? 8'hZZ : l_sendData;
always_comb
begin
    if ( rw == 0 )
    begin
        if ( addr == 16'hFFFF )
        begin
            // End condition
            $finish;
        end
        else if ( addr == 16'hFFFE )
        begin
            $display( "Test ROM jumped to error state" );
            $finish;
        end
        else if ( addr < 511 )
        begin
            l_sendData = TestROMs[ currentRom ][ addr ];
        end
    end
end

always_ff @( posedge clk )
begin
    if ( rw == 1 )
    begin
        if ( addr >= 512 && addr < 1024 )
        begin
            RAM[ addr - 512 ] <= data;
        end
    end
end

initial
begin
    rst = 0;
    #(8 * 10);
    rst = 1;

    #( 8 * 10 );
end

endmodule
