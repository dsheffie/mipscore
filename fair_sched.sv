module fair_sched#(parameter LG_N = 2)(clk, rst, in, y);
   localparam N = 1<<LG_N;
   input logic clk;
   input logic rst;
   input logic [N-1:0] in;
   output logic [LG_N:0] y;

   wire 		 any_valid = |in;
   
   
   logic [LG_N-1:0] 	 r_cnt, n_cnt;

   logic [(2*N)-1:0] 	 t_in2, t_in_shift;
   logic [N-1:0] 	 t_in;
   logic [LG_N:0] 	 t_y;

   always_comb
     begin
	t_in2 = {in, in};
	t_in_shift =  (t_in2 << r_cnt);
	t_in =  t_in_shift[(2*N)-1:N];
     end
   
   always_ff@(posedge clk)
     begin
	if(rst)
	  begin
	     r_cnt <= 'd0;
	  end
	else
	  begin
	     r_cnt <= any_valid ? r_cnt + 'd1 : r_cnt;
	  end
     end // always_ff@ (posedge clk)

   find_first_set#(LG_N) f (.in(t_in), .y(t_y));
   wire [LG_N-1:0] w_yy = t_y[LG_N-1:0] - r_cnt;
   
   always_comb
     begin
	y = {(LG_N+1){1'b1}};
	if(any_valid)
	  begin
	     y = {1'b0, w_yy};
	  end
     end
endmodule
