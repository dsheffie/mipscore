module utlb (
	clk,
	reset,
	flush,
	req,
	addr,
	tlb_rsp,
	tlb_rsp_valid,
	hit_entry,
	hit
);
	input wire clk;
	input wire reset;
	input wire flush;
	input wire req;
	input wire [56:0] tlb_rsp;
	input wire tlb_rsp_valid;
	input wire [63:0] addr;
	output reg hit;
	output reg [56:0] hit_entry;
	parameter ISIDE = 0;
	localparam N_TLB_ENTRIES = 8;
	reg [56:0] entries [7:0];
	wire [7:0] t_hit_vec;
	reg r_hit;
	wire [3:0] t_hit_pos;
	wire [3:0] t_repl_pos;
	reg [2:0] r_repl;
	reg [7:0] r_p_mru;
	reg [7:0] n_p_mru;
	reg [63:0] r_addr;
	always @(posedge clk)
		if (reset) begin
			r_repl <= 'd0;
			r_addr <= addr;
		end
		else begin
			r_repl <= (req & (t_hit_vec == 'd0) ? r_repl + 'd1 : r_repl);
			r_addr <= (req ? addr : r_addr);
		end
	genvar i;
	generate
		for (i = 0; i < N_TLB_ENTRIES; i = i + 1) begin : genblk1
			assign t_hit_vec[i] = (entries[i][0] ? entries[i][56-:52] == addr[63:12] : 1'b0);
		end
	endgenerate
	always @(posedge clk)
		if (reset)
			r_p_mru <= 'd0;
		else
			r_p_mru <= (&n_p_mru == 1'b1 ? 'd0 : n_p_mru);
	always @(*) begin
		n_p_mru = r_p_mru;
		if (req)
			n_p_mru = n_p_mru | t_hit_vec;
	end
	find_first_set #(3) hit0(
		.in(t_hit_vec),
		.y(t_hit_pos)
	);
	find_first_set #(3) repl0(
		.in(~r_p_mru),
		.y(t_repl_pos)
	);
	always @(posedge clk)
		if (reset) begin
			r_hit <= 1'b0;
			begin : sv2v_autoblock_1
				integer i;
				for (i = 0; i < N_TLB_ENTRIES; i = i + 1)
					begin
						entries[i][56-:52] = 'd0;
						entries[i][0] = 1'b0;
					end
			end
		end
		else begin
			r_hit <= req & (t_hit_vec != 'd0);
			if (flush) begin : sv2v_autoblock_2
				integer i;
				for (i = 0; i < N_TLB_ENTRIES; i = i + 1)
					entries[i][0] = 1'b0;
			end
			else if (tlb_rsp_valid)
				entries[t_repl_pos[2:0]] <= tlb_rsp;
		end
	reg [31:0] r_cycle;
	always @(posedge clk) r_cycle <= (reset ? 'd0 : r_cycle + 'd1);
	always @(posedge clk) hit_entry <= entries[t_hit_pos[2:0]];
	always @(*) hit = r_hit;
endmodule
