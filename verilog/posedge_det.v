// posedge_det.v
// Glenn G. Ko
// giko@illinois.edu
// positive edge detector

module posedge_det
(
    input   clk,
    input   sig,
    input   rst_n, 
    output  pe
);

    reg sig_d;
    always @ (posedge clk or negedge rst_n) begin 
        if (!rst_n)
            sig_d <= 0;
        else
            sig_d <= sig;
    end
    assign pe = sig & ~ sig_d;

endmodule

