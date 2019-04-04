// ndsum.v
// Glenn G. Ko
// giko@illinois.edu

module ndsum
#(
    parameter   WORDSIZE=32,
                ADDRSIZE=32
)
(
    input                   clk,
    input                   i_wen,
    input  [ADDRSIZE-1:0]   i_waddr,
    input  [WORDSIZE-1:0]   i_wdata,
    input  [ADDRSIZE-1:0]   i_raddr,
    output [WORDSIZE-1:0]   o_rdata
);

    blk_mem_ndsum bram_ndsum_u (
        .clka   (clk),
        .wea    (i_wen),
        .addra  (i_waddr),
        .dina   (i_wdata),
        .clkb   (clk),
        .addrb  (i_raddr),
        .doutb  (o_rdata)
    );

endmodule
