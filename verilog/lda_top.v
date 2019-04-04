
module lda_top 
#(parameter NUM_TOPICS = 16, 
  parameter NUM_TOPICS_LOG = 4)(
    input clk,
    input rst,
    input start,
    input data_in, 
    output data_out,
    output done
);

    localparam BRAMSIZE = 131072; 
    localparam DATASIZE = 125528;

    // state machine parameters
    localparam IDLE=4'b000;
    localparam READ=4'b001;
    localparam EXEC=4'b011;
    localparam LOOP=4'b010;
    localparam DONE=4'b110;

    // basic state machine

    wire exec_done;
    wire loop_done;

    reg [3:0] state;
    reg [3:0] state_next;
    wire rst_n; 
    assign rst_n = ~rst;
    
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= 0;
        end
        else begin
            state <= state_next;
        end
    end

    always @ (*) begin
        case (state)
            IDLE:
                if (start)
                    state_next = READ;
                else
                    state_next = state;
            READ: 
                state_next = EXEC; 
            EXEC:
                if (exec_done)
                    state_next = LOOP;
                else 
                    state_next = state;
            LOOP:
                if (loop_done)
                    state_next = DONE;
                else
                    state_next = READ;
            DONE:
                state_next = IDLE;
            default:
                state_next = IDLE;
        endcase
    end

    wire exec;
    assign exec = (state == EXEC) ? 1'b1 : 1'b0;

    wire start_exec;
    posedge_det start_exec_u
    (
        .clk    (clk),
        .sig    (exec),
        .rst_n  (rst_n),
        .pe     (start_exec)
    );

    wire [31:0] ntopic;
    assign      ntopic = 32'h00000010;
    wire [31:0] beta;
    wire [31:0] Vbeta;
    wire [31:0] alpha;
    wire [31:0] Kalpha;
    assign      beta   = 32'h00000014;  // 0.1
    assign      Vbeta  = 32'h00049866;  // 1176.4
    assign      alpha  = 32'h00000080;  // 0.5
    assign      Kalpha = 32'h00003200;  // 32

    reg [31:0] ndsum;
    
    // create memory index
    reg [31:0] ndoc;
    reg [31:0] addr_cnt;
    reg [31:0] words_in_doc;
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            addr_cnt <= 0;
            words_in_doc <= 0;
            ndoc <= 0; 
        end else if (state == LOOP) begin
            addr_cnt <= addr_cnt + 1;
            if (words_in_doc + 1 == ndsum) begin 
                words_in_doc <= 0;
                ndoc <= ndoc + 1;
            end
            else begin 
                words_in_doc <= words_in_doc + 1; 
                ndoc <= ndoc; 
            end
        end else begin
            addr_cnt <= addr_cnt;
            words_in_doc <= words_in_doc; 
        end
    end

    assign loop_done = (addr_cnt == DATASIZE-1) ? 1'b1 : 1'b0;

    
    reg [31:0] word;
    reg [31:0] topic;
    wire [15:0] ndoc_dout;
    wire [15:0] word_dout;
    wire [15:0] topic_dout;
    wire [31:0] topic_new;
    wire [31:0] ndsum_dout;

    sample_word #(NUM_TOPICS, NUM_TOPICS_LOG) sample_word_u (
        .clk            (clk),
        .rst_n          (rst_n),
        .i_start        (start_exec),
        .i_ntopic       (ntopic),       // Q32
        .i_ndoc         (ndoc),             //      ?Q16.16
        .i_word         (word),             //      ?Q16
        .i_topic        (topic),             //      ?Q16
        .i_ndsum        (ndsum),
        .i_beta         (beta),
        .i_Vbeta        (Vbeta),
        .i_alpha        (alpha),
        .i_Kalpha       (Kalpha),
        .o_topic_new    (topic_new),
        .o_done         (exec_done)
    );

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n)
        begin
            word  <= 0;
            topic <= 0;
            ndsum <= 0;
        end
        else begin
            word  <= word_dout;
            topic <= topic_dout;
            ndsum <= ndsum_dout; 
        end
    end
    
    
    ndsum #(32, 10) ndsum_u (
            .clk        (clk),
            .i_wen      (1'b0),
            .i_waddr    (0),
            .i_wdata    (0),
            .i_raddr    (ndoc),
            .o_rdata    (ndsum_dout)
     );

    blk_mem_word bram_word_u (
        .clka   (clk),
        .wea    (1'b0),
        .addra  (0),
        .dina   (0),
        .clkb   (clk),
        .addrb  (addr_cnt),
        .doutb  (word_dout)
    );

    blk_mem_topic bram_topic_u (
        .clka   (clk),
        .wea    (exec_done),
        .addra  (addr_cnt),
        .dina   (topic_new),
        .clkb   (clk),
        .addrb  (addr_cnt),
        .doutb  (topic_dout)
    );

    assign done = (state == DONE) ? 1'b1: 1'b0;
endmodule
