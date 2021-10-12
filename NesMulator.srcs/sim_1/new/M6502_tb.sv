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

logic clk;
logic rst;
logic nmi;
logic irq;
logic data;
logic addr;
logic rw;

M6502 m6502 (
    i_clk( clk ),
    i_rst( rst ),
    i_nmi( nmi ),
    i_irq( irq ),
    io_data( data ),
    o_addr( addr ),
    i_rw( rw )
);

initial
begin
    forever
    begin
        #4;
        clk = ~clk;
    end
end

endmodule
