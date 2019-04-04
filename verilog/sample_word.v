// sample_word.v
// Joseph Zuckerman
// jzuckerman@college.harvard.edu
// Sample One Word
module sample_word 
    #(parameter NUM_TOPICS = 16, 
      parameter NUM_TOPICS_LOG = 4)(
	input clk,    // Clock
	input rst_n,  // Asynchronous reset active low
	input           i_start,
    input [31:0]    i_ntopic,       // Q32
    input [31:0]    i_ndoc,         //      ?Q16.16
    input [31:0]    i_word,         //      ?Q16
    input [31:0]    i_topic,        //      ?Q16
    input [31:0]    i_ndsum,
    input [31:0]    i_beta,
    input [31:0]    i_Vbeta,
    input [31:0]    i_alpha,
    input [31:0]    i_Kalpha,
    output [31:0]   o_topic_new,
    output          o_done
	
);

	reg         start;
    reg [31:0]  ntopic;
    reg [31:0]  ndoc;
    reg [31:0]  word;
    reg [31:0]  topic;
    reg [31:0]  beta;
    reg [31:0]  Vbeta;
    reg [31:0]  alpha;
    reg [31:0]  Kalpha;
    reg [31:0]  ndsum; 

    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            start       <= 0;
            ntopic      <= 0;
            ndoc        <= 0;
            word        <= 0;
            topic       <= 0;
            beta        <= 0;
            Vbeta       <= 0;
            alpha       <= 0;
            Kalpha      <= 0;
            ndsum <= 0; 
        end
        else if (i_start) begin
            start       <= 1'b1;
            ntopic      <= i_ntopic;
            ndoc        <= i_ndoc;
            word        <= i_word;
            topic       <= i_topic;
            beta        <= i_beta;
            Vbeta       <= i_Vbeta;
            alpha       <= i_alpha;
            Kalpha      <= i_Kalpha;
            ndsum <= i_ndsum; 
        end else
            start       <= 1'b0; 
    end

    localparam IDLE  = 2'b00;
    localparam SAMP  = 2'b01;
    localparam DONE  = 2'b11;
    localparam NUM_BITS = 32 * NUM_TOPICS;

    reg [2:0] state, state_next;

    always @(posedge clk or negedge rst_n) begin : proc_ 
        if(!rst_n) begin
            state <= 0;
        end else begin
            state  <= state_next;
        end
    end

    wire [NUM_TOPICS -1 : 0] samp_done; 

    always @ (*) begin
        case(state)
            IDLE:
                if (start)
                    state_next = SAMP;
                else 
                    state_next = state;
            SAMP:
                if (samp_done[0])
                    state_next = DONE;
                else
                    state_next = state;
            DONE:
                state_next = IDLE;
            default:
                state_next = state;
        endcase
    end
    
    wire samp;
    assign samp = (state == SAMP) ? 1'b1 : 1'b0;

    // local memory variables
    reg [31:0] ndsum_raddr;
    wire [31:0] ndsum_waddr;
    wire [31:0] ndsum_wdata;

    wire lmem_read_ack;
    wire lmem_write_ack;

    wire start_samp;
    posedge_det start_samp_u
    (
        .clk    (clk),
        .sig    (samp),
        .rst_n  (rst_n),
        .pe     (start_samp)
    );


    reg  [31:0] new_topic; 
    wire [31:0] new_topic_temp;
    wire new_topic_valid; 
    
    
    wire [31:0] nw [0:NUM_TOPICS-1];
    wire [31:0] nw_sum [0:NUM_TOPICS-1];
    wire [31:0] nd [0:NUM_TOPICS-1];
    wire mem_valid [0:NUM_TOPICS-1];
    
    wire [NUM_TOPICS-1:0] prob_valid;
    wire [31:0] probs [0:NUM_TOPICS-1];
    
    wire [NUM_BITS - 1: 0] samp_probs, samp_topics;

    genvar topic_num; 
    generate
        for (topic_num = 0; topic_num < NUM_TOPICS; topic_num = topic_num + 1) begin 
           
           assign samp_topics[(32*topic_num+31):(32*topic_num)] = topic_num;
           
           topic_mem #(topic_num) topic_mem_u(
                .clk(clk),    // Clock
                .rst_n(rst_n),  // Asynchronous reset active low
                .start(start_samp),
                .i_topic(topic), 
                .i_word(word),
                .i_ndoc(ndoc),
                .i_my_topic(topic_num),
                .i_new_topic(new_topic_temp), 
                .i_topic_valid(new_topic_valid),
                .o_nw(nw[topic_num]), 
                .o_nw_sum(nw_sum[topic_num]), 
                .o_nd(nd[topic_num]),
                .o_valid(mem_valid[topic_num]),
                .o_done(samp_done[topic_num])
            );

            find_p find_p_u(
                .clk(clk),
                .rst_n(rst_n),
                .i_start(mem_valid[topic_num]),
                .i_nw(nw[topic_num]),
                .i_beta(beta),     
                .i_nwsum(nw_sum[topic_num]),  
                .i_Vbeta(Vbeta),    
                .i_nd(nd[topic_num]),     
                .i_alpha(alpha),    
                .i_ndsum(ndsum),  
                .i_Kalpha(Kalpha),   
                .o_valid(prob_valid[topic_num]),
                .o_p(probs[topic_num])      
            );
                   
            assign samp_probs[(32*topic_num+31):(32*topic_num)] = probs[topic_num];
      
        end
    endgenerate

    wire [31:0] randoms [0:NUM_TOPICS_LOG - 1];
    wire [(NUM_TOPICS_LOG * 32) - 1: 0] samp_rands;
    genvar layer; 
    generate
        for (layer = 0; layer < NUM_TOPICS_LOG; layer = layer + 1) begin 
            localparam integer seed = 1 << layer; 
            rng rng_u (
                .clk        (start),
                .reset      (rst_n),
                .loadseed_i (start_samp && state == IDLE),
                .seed_i     (seed),
                .number_o   (randoms[layer])
            );
          assign samp_rands[(layer*32+31):(layer*32)] = randoms[layer];
        end
    endgenerate

    sampler #(NUM_TOPICS, NUM_TOPICS_LOG) sample_u
    (
        .clk(clk),    // Clock
        .rst_n(rst_n),  // Asynchronous reset active low
        .i_ntopic(ntopic),
        .i_probs(samp_probs),
        .i_topics(samp_topics),
        .i_start(prob_valid[0]), 
        .i_valid(prob_valid), 
        .i_random(samp_rands),
        .o_new_topic(new_topic_temp), 
        .o_done(new_topic_valid)
    );
    
    always @ (negedge new_topic_valid) begin 
        new_topic <= new_topic_temp; 
    end

    /* ndsum_mem ndsum_table(
        .clk(clk),
        .rst_n(rst_n),
        .i_read_req(),
        .i_ndsum_raddr(),
        .o_ndsum_rdata(),
        .o_read_ack(),
        .i_wen(),
        .i_ndsum_waddr(),
        .i_ndsum_wdata(),
        .o_write_ack()
    ); */

    
    wire word_done;
    assign word_done = (state == DONE) ? 1'b1:1'b0;
    assign o_topic_new = new_topic; 
    assign o_done = word_done;

endmodule