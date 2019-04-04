// nw.v
// Glenn G. Ko
// giko@illinois.edu

module nd_topic
#(
    parameter   WORDSIZE=32,
                ADDRSIZE=32
)
(
    input                   clk,
    input                   i_wen,
    input  [ADDRSIZE-1:0]   i_addr,
    input  [WORDSIZE-1:0]   i_wdata,
    output [WORDSIZE-1:0]   o_rdata
);

    blk_mem_nd_topic bram_nd_topic_u (
        .clka   (clk),
        .wea    (i_wen),
        .addra  (i_addr),
        .dina   (i_wdata),
        .douta  (o_rdata)
    );

endmodule
