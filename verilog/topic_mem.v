// sampler.v
// Joseph Zuckerman
// jzuckerman@college.harvard.edu
// per-topic memory of counts, including increment and decrement logic
module topic_mem #(parameter MY_TOPIC = 0) (
	input clk,    // Clock
	input rst_n,  // Asynchronous reset active low
	input start,
	input [31:0] i_topic, 
	input [31:0] i_word,
	input [31:0] i_ndoc,
	input [31:0] i_my_topic,
	input [31:0] i_new_topic, 
	input i_topic_valid,
	output [31:0] o_nw, 
	output [31:0] o_nw_sum, 
	output [31:0] o_nd,
	output o_valid,
	output o_done
);

// state machine 
// 0. idle
// 1. read 
// 2. subtract
// 3. sample (wait)
// 4. add 
// 5. write
// 6. done 

 localparam IDLE  = 3'b000;
 localparam READ  = 3'b001; 
 localparam SUBT  = 3'b011;
 localparam WAIT  = 3'b010;
 localparam ADD   = 3'b110;
 localparam WRIT  = 3'b100;
 localparam DONE  = 3'b101; 

reg [2:0] state, next_state;

always @(posedge clk or negedge rst_n) begin : proc_ 
	if(!rst_n) begin
		state <= 0;
	end else begin
		state  <= next_state;
	end
end

always @ (*) begin 
	case (state)
		IDLE: 
			if (start)
				next_state = READ;
			else
			    next_state = state; 
		READ: 
			next_state = SUBT; 
		SUBT: 
			next_state = WAIT; 
		WAIT: 
			if (i_topic_valid)
				next_state = ADD; 
		    else 
		        next_state = state;
		ADD: 
			next_state = WRIT; 
		WRIT: 
			next_state = DONE; 
		DONE:
			next_state = IDLE; 
		default:
		  next_state = state;
	endcase // state
end

    wire state_wait; 
    assign state_wait = (state == WAIT) ? 1'b1 : 1'b0; 
   
    wire valid;
    posedge_det start_samp_u
    (
        .clk    (clk),
        .sig    (state_wait),
        .rst_n  (rst_n),
        .pe     (valid)
    );


reg [31:0] topic, word, ndoc, my_topic; 
always @(posedge clk or negedge rst_n) begin 
	if(!rst_n) begin
		topic <= 0;
		word <= 0;
		ndoc <= 0;
		my_topic <= 0;
	end 
	else if (state == IDLE) begin
		topic <= i_topic;
		word <= i_word;
		ndoc <= i_ndoc;
		my_topic <= i_my_topic;
	end
end

reg [31:0] new_topic; 
always @(negedge i_topic_valid) begin 
    new_topic <= i_new_topic; 
end


reg [31:0] nw_cur, nd_cur;
reg [31:0] nw_sum_cur [0:0];

initial begin
    $readmemh("../init/nwsum.memh", nw_sum_cur, MY_TOPIC*2, (MY_TOPIC + 1)*2);
end

wire [31:0] nw_rdata, nd_rdata;
reg needs_write; 
always @(posedge clk or negedge rst_n) begin 
	if(!rst_n) begin
		nw_cur <= 0;
		nw_sum_cur[0] <= 0; 
		nd_cur <= 0;
		needs_write <= 1'b0;
	end 
	else if (state == READ) begin
		nw_cur <= nw_rdata;
		nd_cur <= nd_rdata;
	end
	else if (state == SUBT && topic == my_topic) begin 
		if (nw_cur > 0)
		  nw_cur <= nw_cur - 1; 
		else
		  nw_cur <= 0; 
		if (nw_sum_cur[0] > 0)
		  nw_sum_cur[0] <= nw_sum_cur[0] - 1;
		else 
		  nw_sum_cur[0] <= 0;
		if (nd_cur > 0)
		  nd_cur <= nd_cur - 1; 
		else
		  nd_cur <= 0; 
		
		needs_write <= 1'b1;
	end
	else if (state == ADD && new_topic == my_topic) begin 
		nw_cur <= nw_cur + 1; 
		nw_sum_cur[0] <= nw_sum_cur[0] + 1; 
		nd_cur <= nd_cur + 1; 
		needs_write <= 1'b1;
	end
	else if (state == DONE)
		needs_write <= 1'b0; 
end

wire wen;
assign wen = needs_write & ((state == WRIT) ? 1'b1 : 1'b0); 

nw_topic #(32, 14) nw_topic_u (
	.clk   (clk),
    .i_wen    (wen),
    .i_addr  (word),
    .i_wdata   (nw_cur),
    .o_rdata  (nw_rdata)
    );

nd_topic #(32, 10) nd_topic_u(
	.clk   (clk),
    .i_wen   (wen),
    .i_addr  (ndoc),
    .i_wdata   (nd_cur),
    .o_rdata  (nd_rdata)
	); 

assign o_done = (state == DONE);
assign o_nw = (state == WAIT) ? nw_cur : 32'bz; 
assign o_nw_sum = (state == WAIT) ? nw_sum_cur[0] : 32'bz;
assign o_nd = (state == WAIT) ? nd_cur : 32'bz; 
assign o_valid = valid; 


endmodule