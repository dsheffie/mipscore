module tlb (
	clk,
	reset,
	iside_req,
	dside_req,
	iside_paddr,
	dside_paddr,
	iside_rsp_valid,
	dside_rsp_valid,
	tlb_rsp,
	iside_tlb_miss,
	dside_tlb_miss,
	tlb_hit
);
	input wire clk;
	input wire reset;
	input wire iside_req;
	input wire dside_req;
	input wire [51:0] iside_paddr;
	input wire [51:0] dside_paddr;
	output wire iside_rsp_valid;
	output wire dside_rsp_valid;
	output wire [56:0] tlb_rsp;
	output wire iside_tlb_miss;
	output wire dside_tlb_miss;
	output wire tlb_hit;
	reg [1:0] n_state;
	reg [1:0] r_state;
	reg r_iside_rsp_valid;
	reg r_dside_rsp_valid;
	reg n_iside_rsp_valid;
	reg n_dside_rsp_valid;
	reg r_got_iside;
	reg r_got_dside;
	reg n_got_iside;
	reg n_got_dside;
	reg r_tlb_hit;
	reg n_tlb_hit;
	reg r_iside_tlb_miss;
	reg n_iside_tlb_miss;
	reg r_dside_tlb_miss;
	reg n_dside_tlb_miss;
	reg [56:0] n_tlb_rsp;
	reg [56:0] r_tlb_rsp;
	assign iside_rsp_valid = r_iside_rsp_valid;
	assign dside_rsp_valid = r_dside_rsp_valid;
	assign tlb_rsp = r_tlb_rsp;
	assign iside_tlb_miss = r_iside_tlb_miss;
	assign dside_tlb_miss = r_dside_tlb_miss;
	assign tlb_hit = r_tlb_hit;
	always @(*) begin
		n_iside_rsp_valid = 1'b0;
		n_dside_rsp_valid = 1'b0;
		n_got_iside = r_got_iside | iside_req;
		n_got_dside = r_got_dside | dside_req;
		n_tlb_rsp = r_tlb_rsp;
		n_tlb_hit = 1'b0;
		n_iside_tlb_miss = 1'b0;
		n_dside_tlb_miss = 1'b0;
		n_state = r_state;
		case (r_state)
			2'd0: begin
				n_iside_tlb_miss = n_got_iside;
				n_dside_tlb_miss = n_got_dside;
				if (n_got_iside)
					n_state = 2'd1;
				else if (n_got_dside)
					n_state = 2'd2;
			end
			2'd1: begin
				n_state = 2'd0;
				n_got_iside = 1'b0;
				n_iside_rsp_valid = 1'b1;
				n_tlb_rsp[0] = 1'b1;
				n_tlb_rsp[56-:52] = iside_paddr;
				n_tlb_rsp[4] = 1'b0;
				n_tlb_rsp[3] = 1'b0;
				n_tlb_rsp[2] = 1'b1;
				n_tlb_rsp[1] = 1'b0;
			end
			2'd2: begin
				n_state = 2'd0;
				n_got_dside = 1'b0;
				n_dside_rsp_valid = 1'b1;
				n_tlb_rsp[0] = 1'b1;
				n_tlb_rsp[56-:52] = dside_paddr;
				n_tlb_rsp[4] = 1'b1;
				n_tlb_rsp[3] = 1'b1;
				n_tlb_rsp[2] = 1'b0;
				n_tlb_rsp[1] = 1'b0;
			end
			default:
				;
		endcase
	end
	always @(posedge clk) r_tlb_rsp <= n_tlb_rsp;
	always @(posedge clk)
		if (reset) begin
			r_state <= 2'd0;
			r_iside_rsp_valid <= 1'b0;
			r_dside_rsp_valid <= 1'b0;
			r_got_iside <= 1'b0;
			r_got_dside <= 1'b0;
			r_tlb_hit <= 1'b0;
			r_iside_tlb_miss <= 1'b0;
			r_dside_tlb_miss <= 1'b0;
		end
		else begin
			r_state <= n_state;
			r_iside_rsp_valid <= n_iside_rsp_valid;
			r_dside_rsp_valid <= n_dside_rsp_valid;
			r_got_iside <= n_got_iside;
			r_got_dside <= n_got_dside;
			r_tlb_hit <= n_tlb_hit;
			r_iside_tlb_miss <= n_iside_tlb_miss;
			r_dside_tlb_miss <= n_dside_tlb_miss;
		end
	reg [31:0] r_cycle;
	always @(posedge clk) r_cycle <= (reset ? 'd0 : r_cycle + 'd1);
endmodule
