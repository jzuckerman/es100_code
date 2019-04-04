// sampler.v
// Joseph Zuckerman
// jzuckerman@college.harvard.edu
// Tree-based sampling for topics
module sampler 
	#(parameter NUM_TOPICS = 16,
	  parameter NUM_TOPICS_LOG = 4)
	(
	input clk,    // Clock
	input rst_n,  // Asynchronous reset active low
	input [31:0] i_ntopic, 
	input [((NUM_TOPICS * 32) -1): 0] i_probs,
	input [((NUM_TOPICS * 32) -1): 0] i_topics,
	input i_start, 
	input [NUM_TOPICS - 1: 0]i_valid, 
	input [((NUM_TOPICS_LOG * 32) -1): 0] i_random,
	output [31:0] o_new_topic, 
	output o_done
	);

	localparam num_immeds = 2 * NUM_TOPICS - 1; 
	localparam IDLE = 1'b0; 
	localparam COMP = 1'b1; 

	wire [31:0] input_topics_temp [0:NUM_TOPICS-1];
	wire [31:0] input_probs_temp [0:NUM_TOPICS-1];
	wire [31:0] input_random_temp [0:NUM_TOPICS_LOG-1];
	wire input_valid_temp [NUM_TOPICS-1: 0] ;
	
	reg [31:0] input_topics [0:NUM_TOPICS - 1];
	reg [31:0] input_probs [0:NUM_TOPICS - 1];
    reg input_valid [NUM_TOPICS-1: 0] ;
    reg enable; 
    reg [31:0] random [0:NUM_TOPICS_LOG - 1];
    reg [31:0] ntopic;
	
	genvar i, j;
	generate
        for (i = 0; i < NUM_TOPICS; i = i + 1) begin 
            assign input_topics_temp[i] = i_topics[(32 * i+ 31):(32*i)];
            assign input_probs_temp[i] = i_probs[(32 * i+ 31):(32*i)];
            assign input_valid_temp[i] = i_valid[i];
        end
        
        for (j = 0; j < NUM_TOPICS_LOG; j = j + 1) begin 
            assign input_random_temp[j] = i_random[(32*j+31):(32*j)];
        end
	endgenerate
	
	wire start;
        posedge_det start_u
        (
            .clk    (clk),
            .sig    (i_start),
            .rst_n  (rst_n),
            .pe     (start)
        );
	
	reg state, next_state;
        always @(posedge clk or negedge rst_n) begin 
            if(!rst_n) begin
                state <= IDLE;
                ntopic <= 0;
            end 
            else begin
                state <= next_state;
                ntopic <= i_ntopic; 
            end
        end
    
        always @(*) begin 
            case (state) 
                IDLE: 
                    if (start)
                        next_state = COMP;
                     else 
                        next_state = IDLE;
                COMP:
                    if (o_done)
                        next_state = IDLE;
                    else 
                        next_state = COMP;
            endcase
        end


	genvar index; 
	for (index = 0; index < NUM_TOPICS; index = index + 1) begin
	   always @(i_probs or i_valid or i_topics or rst_n or ntopic) begin
            if(!rst_n) begin
                input_probs[index] <= 0;
                input_topics[index] <= 0; 
                input_valid[index] <= 0;
            end else begin
                if (index < ntopic) begin
                    input_probs[index] <= input_probs_temp[index];
                    input_topics[index] <= input_topics_temp[index];
                    input_valid[index] <= input_valid_temp[index];
                end else begin 
                    input_probs[index] <= 0;
                    input_topics[index] <= 0; 
                    input_valid[index] <= 0;
                end
            end
        end  
	end
	
	genvar index2; 
    for (index2 = 0; index2 < NUM_TOPICS_LOG; index2 = index2 + 1) begin
       always @(i_random or rst_n) begin
            if(!rst_n) begin
                random[index2] <= 0;
            end else begin
                random[index2] <= input_random_temp[index2];
            end
        end  
    end


	wire [31:0] probs [0:(num_immeds - 1)];
	wire [31:0] topics [0:(num_immeds - 1)];
	wire valid [0:(num_immeds - 1)];

	genvar k;
	generate
       for (k = 0; k < 16; k = k + 1) begin 
            assign probs[num_immeds - NUM_TOPICS + k] = input_probs[k];
	        assign topics[num_immeds - NUM_TOPICS + k] = input_topics[k];
	        assign valid[num_immeds - NUM_TOPICS + k] = input_valid[k];
	   end
	endgenerate
	       
	genvar layer, node, node_index;
	generate
    
		for (layer = 0; layer < NUM_TOPICS_LOG; layer = layer + 1) begin 
			for (node = 0; node < (1 << layer); node = node + 1) begin 	
				localparam integer node_index = (1 << layer) - 1 + node;
				localparam integer child1_index = 2 * node_index + 1; 
				localparam integer child2_index = 2 * node_index + 2; 

				tree_node node (
					.clk(clk), 
					.rst_n(rst_n), 
					.i_start(valid[child1_index]), 
					.i_p1(probs[child1_index]), 
					.i_valid1(valid[child1_index]),
					.i_p2(probs[child2_index]), 
					.i_valid2(valid[child2_index]), 
					.i_topic_1(topics[child1_index]), 
					.i_topic_2(topics[child2_index]), 
					.i_random(random[layer]),
					.o_valid(valid[node_index]),
					.o_topic(topics[node_index]), 
					.o_p_sum(probs[node_index])
				);
			end
		end
	endgenerate
	
	reg [31:0] new_topic; 
	always @(posedge valid[0]) begin 
	   new_topic <= topics[0];
	end

	assign o_new_topic = new_topic; 
	assign o_done = valid[0] & !(state == IDLE);

endmodule