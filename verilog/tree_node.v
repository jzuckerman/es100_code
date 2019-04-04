module tree_node (
	input clk,
	input rst_n, 
	input i_start, 
	input [31:0] i_p1,
	input i_valid1,
	input [31:0] i_p2,
	input i_valid2, 
	input [31:0] i_topic_1, 
	input [31:0] i_topic_2, 
	input [31:0] i_random,
	output o_valid, 
	output [31:0] o_topic,
	output [31:0] o_p_sum
);

    parameter IDLE = 1'b0; 
    parameter COMP = 1'b1; 
    
	wire en; 
	reg [63:0] p1;
	reg valid1;
	reg [63:0] p2;
	reg valid2; 
	reg [31:0] topic_1; 
	reg [31:0] topic_2; 
	reg [31:0] random;

//buffer inputs
	always @ (posedge clk or negedge rst_n)
    begin
        if (!rst_n) begin
            p1      	<= 0;
            valid1 		<= 0;
            p2     		<= 0;
            valid2    <= 0;
            random    <= 0;
        end
        else begin
            p1      	<= i_p1;
            valid1 		<= i_valid1;
            p2     		<= i_p2;
            valid2    <= i_valid2;
            random    <= i_random;
        end
    end

    reg state; 
    reg next_state; 
    
    always @(posedge i_valid1 or negedge rst_n) begin 
        if (!rst_n)
            topic_1 <= 0; 
        else 
            topic_1 <= i_topic_1; 
    end
    
    always @(posedge i_valid2 or negedge rst_n) begin 
            if (!rst_n)
                topic_2 <= 0; 
            else 
                topic_2 <= i_topic_2; 
        end
        
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state; 
    end
    
    always @(*) begin
        case (state) 
            IDLE: 
                if (i_start)
                    next_state <= COMP;
                else
                    next_state <= IDLE;
            COMP: 
                if (o_valid)
                    next_state <= IDLE;
                else 
                    next_state <= COMP;             
            default:
                next_state <= IDLE; 
        endcase             
    end
    
    assign en = (state == COMP) ? 1'b1 : 1'b0;

      reg [31:0] p_sum;  // number of bits? 
      reg en_mu; 
    
      always @ (posedge clk or negedge rst_n)
        begin
            if (!rst_n) begin 
                p_sum <= 0;
                en_mu <= 0; 
            end 
            else if (state == COMP) begin 
                p_sum <= p1 + p2; 
                en_mu <= 1; 
            end 
            else begin 
                en_mu <= 0;
                p_sum <= p_sum; 
            end 
        end
    
      reg [63:0] norm_rand; 
      reg en_t_out;
      
      always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            norm_rand <= 0;
            en_t_out <= 0; 
        end 
        else if (en_mu) begin
            norm_rand <= random * p_sum;
            en_t_out <= 1; 
        end
        else begin
            en_t_out <= 0;
            norm_rand <= norm_rand; 
        end
      end
      
      posedge_det valid_posedge_u
      (
          .clk    (clk),
          .sig    (en_t_out),
          .rst_n  (rst_n),
          .pe     (o_valid)
       );
       
    
      assign o_topic = en_t_out ? (norm_rand[63:32] < p1 ? topic_1 : topic_2) : 32'bz;
      assign o_p_sum = p_sum;

endmodule // tree_node
