// localmem.v
// Glenn G. Ko
// giko@illinois.edu

module localmem
(
    input           clk,
    input           rst_n,
    input           i_read_req,
    input  [31:0]   i_nw_raddr,
    input  [31:0]   i_nd_raddr,
    input  [31:0]   i_nwsum_raddr,
    input  [31:0]   i_ndsum_raddr,
    output [31:0]   o_nw_rdata,
    output [31:0]   o_nd_rdata,
    output [31:0]   o_nwsum_rdata,
    output [31:0]   o_ndsum_rdata,
    output          o_read_ack,
    input           i_wen,
    input  [31:0]   i_nw_waddr,
    input  [31:0]   i_nd_waddr,
    input  [31:0]   i_nwsum_waddr,
    input  [31:0]   i_ndsum_waddr,
    input  [31:0]   i_nw_wdata,
    input  [31:0]   i_nd_wdata,
    input  [31:0]   i_nwsum_wdata,
    input  [31:0]   i_ndsum_wdata,
    output          o_write_ack
);

    // input buffers
    reg [31:0] nw_raddr   ;
    reg [31:0] nd_raddr   ;
    reg [31:0] nwsum_raddr;
    reg [31:0] ndsum_raddr;
    always @ (posedge clk or negedge rst_n)
        if (!rst_n) begin
            nw_raddr    <= 0;
            nd_raddr    <= 0;
            nwsum_raddr <= 0;
            ndsum_raddr <= 0;
        end
        else begin
            nw_raddr    <= i_nw_raddr;
            nd_raddr    <= i_nd_raddr;
            nwsum_raddr <= i_nwsum_raddr;
            ndsum_raddr <= i_ndsum_raddr;
        end

    // sizes should be modified for different testbench
    wire [31:0] nw_rdata;
    //nw #(32, 20) nw_u (
    nw #(32, 18) nw_u (
        .clk        (clk),
        .i_wen      (i_wen),
        .i_waddr    (i_nw_waddr),
        .i_wdata    (i_nw_wdata),
        .i_raddr    (nw_raddr[19:0]),
        .o_rdata    (nw_rdata)
    );
    wire [31:0] nd_rdata;
    //nd #(32, 17) nd_u (
    nd #(32, 15) nd_u (
        .clk        (clk),
        .i_wen      (i_wen),
        .i_waddr    (i_nd_waddr),
        .i_wdata    (i_nd_wdata),
        .i_raddr    (nd_raddr[14:0]),
        .o_rdata    (nd_rdata)
    );
    wire [31:0] nwsum_rdata;
    nwsum #(32, 7) nwsum_u (
        .clk        (clk),
        .i_wen      (i_wen),
        .i_waddr    (i_nwsum_waddr),
        .i_wdata    (i_nwsum_wdata),
        .i_raddr    (nwsum_raddr[6:0]),
        .o_rdata    (nwsum_rdata)
    );
    wire [31:0] ndsum_rdata;
    ndsum #(32, 10) ndsum_u (
        .clk        (clk),
        .i_wen      (i_wen),
        .i_waddr    (i_ndsum_waddr),
        .i_wdata    (i_ndsum_wdata),
        .i_raddr    (ndsum_raddr[9:0]),
        .o_rdata    (ndsum_rdata)
    );

    // input buffer
    reg read_req;
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n)
            read_req <= 1'b0;
        else 
            read_req <= i_read_req;
    end

    reg read_ack;
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n)
            read_ack <= 1'b0;
        else 
            read_ack <= read_req;
    end

    assign o_nw_rdata    = (read_ack) ? nw_rdata : 32'bz;
    assign o_nd_rdata    = (read_ack) ? nd_rdata : 32'bz;
    assign o_nwsum_rdata = (read_ack) ? nwsum_rdata : 32'bz;
    assign o_ndsum_rdata = (read_ack) ? ndsum_rdata : 32'bz;
    assign o_read_ack    = (read_ack) ? 1'b1 : 1'b0;

    // write req-ack
    reg     write_ack;
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_ack <= 1'b0;
        end
        else if (i_wen) begin
            write_ack <= 1'b1;
        end
        else
            write_ack <= 1'b0;
    end
    assign o_write_ack   = (write_ack) ? 1'b1 : 1'b0;

endmodule
