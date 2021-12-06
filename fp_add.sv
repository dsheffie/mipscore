
module zero_detector(
   // Outputs
   distance,
   // Inputs
   a
   );
   parameter LG_W = 5;
   parameter W = 24;
   input logic [W:0] a;
   output logic [LG_W-1:0] distance;
   localparam WW = 1 << LG_W;
   localparam ZP = WW - W - 1;
   logic [ZP-1:0]    t_zp = {ZP{1'b0}};
   logic [WW-1:0]    t_a_pad = {a, t_zp};
   logic [LG_W:0]    t_ffs;
   count_leading_zeros#(.LG_N(LG_W)) zffs (t_a_pad, t_ffs);
   always_comb
     begin
	distance = t_ffs[LG_W-1:0];
	if(t_ffs >= W)
	  begin
	     distance = W;
	  end
     end
endmodule // zero_detector



module fp_add(/*AUTOARG*/
   // Outputs
   y,
   // Inputs
   clk, sub, a, b, en
   );
   parameter W = 32;
   input logic clk;
   input logic sub;
   input logic [W-1:0] a;
   input logic [W-1:0] b;
   input logic	       en;         
   output logic [W-1:0] y;

   localparam FW = (W==32) ? 23 : 52;
   localparam EW = (W==32) ? 8 : 11;
   
   wire 	 cs0_swapped_out;
   wire 	 cs0_complemented_out;
   wire [W:0] 	 cs0_a_out;
   wire [W:0] 	 cs0_b_out;
   wire 	 cs0_a_out_zero;
   wire 	 cs0_b_out_zero;
   wire 	 cs0_a_larger;
   
   wire 	 w_sign_toggle_b = sub ? ~b[W-1] : b[W-1];
   
   wire [W-1:0] 	 w_b = {w_sign_toggle_b, b[W-2:0]};


   // wire 		 a_is_nan, a_is_inf, a_is_denorm, a_is_zero;
   // wire 		 b_is_nan, b_is_inf, b_is_denorm, b_is_zero;
   
   // fp_special_cases #(.W(W)) fsc 
   //   (.in_a(a), .in_b(b), 
   //    .a_is_nan(a_is_nan), .a_is_inf(a_is_inf), .a_is_denorm(a_is_denorm), .a_is_zero(a_is_zero),
   //    .b_is_nan(b_is_nan), .b_is_inf(b_is_inf), .b_is_denorm(b_is_denorm), .b_is_zero(b_is_zero)
   //    );
   
   

   logic [W-1:0] t_aligned_a,t_aligned_b;
   logic [EW-1:0] t_dist_a, t_dist_b;

   
   logic [FW+3:0] t_a_mant,t_b_mant;
   logic [FW+3:0] t_a_align_mant,t_b_align_mant;
   logic [EW:0]   t_align_exp;

   always_comb
     begin
	t_a_mant = {1'b1, a[FW-1:0], 3'd0};
	t_b_mant = {1'b1, b[FW-1:0], 3'd0};
	t_dist_a =  a[W-2:FW] - b[W-2:FW];
	t_dist_b =  b[W-2:FW] - a[W-2:FW];
     end
   
   wire [FW+3:0] w_or_mant_a, w_or_mant_b;
   generate
      assign w_or_mant_a[0] = a[0];
      assign w_or_mant_b[0] = b[0];
      for(genvar i = 1; i < (FW+3); i=i+1)
	begin
	   assign w_or_mant_a[i] = |a[i:0]; //| w_or_mant_a[i-1];
	   assign w_or_mant_b[i] = |b[i:0]; // | w_or_mant_b[i-1];
	end
   endgenerate
   
   wire a_shifted = w_or_mant_a[t_dist_b[LG_FW-1:0]];
   wire b_shifted = w_or_mant_b[t_dist_b[LG_FW-1:0]];
   
   //align inputs
   always_comb
     begin
	t_a_align_mant = t_a_mant;
	t_align_exp = {1'b0,a[W-2:FW]};
	t_b_align_mant = t_b_mant;
	if(a[W-2:FW] > b[W-2:FW])
	  begin
	     t_b_align_mant = (t_b_mant >> t_dist_a) | {{(FW+3){1'b0}}, b_shifted};
	  end
	else if(b[W-2:FW] > a[W-2:FW])
	  begin
	     t_a_align_mant = (t_a_mant >> t_dist_b) |{{(FW+3){1'b0}}, a_shifted};
	     t_align_exp = {1'b0,b[W-2:FW]};
	  end
     end // always_comb


   
   //perform add
   logic [FW+4:0] t_align_sum;
   logic 	  t_align_sign;
   
   always_comb
     begin
	t_align_sum = {1'b0, t_a_align_mant} + t_b_align_mant;
	t_align_sign = a[W-1];
	if(a[W-1] != w_b[W-1])
	  begin
	     if(t_a_align_mant > t_b_align_mant)
	       begin
		  t_align_sum = {1'b0, t_a_align_mant} - t_b_align_mant;
		  t_align_sign = a[W-1];
	       end
	     else
	       begin
		  t_align_sum = {1'b0, t_b_align_mant} - t_a_align_mant;
		  t_align_sign = w_b[W-1];
	       end
	  end
     end // always_comb

   //check add
   logic [FW:0] t_add_mant;
   logic [EW:0] t_add_exp;
   logic 	t_guard,t_round,t_sticky;
   
   always_comb
     begin
	t_add_mant = t_align_sum[FW+3:3];
	t_guard = t_align_sum[2];
	t_round = t_align_sum[1];
	t_sticky = t_align_sum[0];
	t_add_exp = t_align_exp;
	if(t_align_sum[FW+4])
	  begin
	     t_add_mant = t_align_sum[FW+4:4];
	     t_guard = t_align_sum[3];
	     t_round = t_align_sum[2];
	     t_sticky = t_align_sum[1] | t_align_sum[0];
	     t_add_exp = t_align_exp + 'd1;
	  end
     end
   //normalize
   logic [FW:0] t_norm1_add_mant;
   logic [EW:0] t_norm1_add_exp;
   logic 	t_norm1_guard,t_norm1_round,t_norm1_sticky;

   localparam LG_FW = FW==23 ? 5 : 6;
   wire [LG_FW-1:0] w_shft_lft_dist;
   localparam ZP = (EW+1) - LG_FW;
   
   zero_detector #(.LG_W(LG_FW), .W(FW)) zd 
     (.distance(w_shft_lft_dist), .a(t_add_mant));
   
   wire [EW:0] 	    w_shift_dist = {{ZP{1'b0}}, w_shft_lft_dist};   
   
   
   
   always_comb
     begin
	t_norm1_add_mant = t_add_mant;
	t_norm1_add_exp = t_add_exp;
	t_norm1_guard = t_guard;
	t_norm1_round = t_round;
	t_norm1_sticky = t_sticky;
	
	if(t_add_mant[FW] == 1'b0 && (t_add_exp != 'd0))
	  begin
	     //how to handle guard, sticky, round
	     t_norm1_add_exp = t_add_exp - w_shift_dist;
	     if(w_shift_dist == 'd1)
	       begin
		  t_norm1_guard = t_norm1_round;
		  t_norm1_round = 1'b0;		  
	       end
	     else
	       begin
		  t_norm1_guard = 1'b0;
		  t_norm1_round = 1'b0;
	       end
	     if(w_shift_dist == 'd1)
	       begin
		  t_norm1_add_mant = {t_add_mant[FW-1:0], t_guard};
	       end
	     else
	       begin
		  t_norm1_add_mant = {t_add_mant[FW-2:0], t_guard, t_round} << (w_shift_dist - 'd2);
	       end
	  end
     end

   logic [FW:0] t_norm2_add_mant;
   logic [EW:0] t_norm2_add_exp;
   logic 	t_norm2_guard,t_norm2_round,t_norm2_sticky;

   always_comb
     begin
	t_norm2_add_mant = t_norm1_add_mant;
	t_norm2_add_exp = t_norm1_add_exp;
	t_norm2_guard = t_norm1_guard;
	t_norm2_round = t_norm1_round;
	t_norm2_sticky = t_norm1_sticky;
	//if(t_norm1_add_exp == 'd0)
	//begin
	//end
     end

   logic [FW:0] t_round_add_mant;
   logic [EW:0] t_round_add_exp;

   always_comb
     begin
	t_round_add_mant = t_norm2_add_mant;
	t_round_add_exp = t_norm2_add_exp;
	if (t_norm2_guard && (t_norm2_round | t_norm2_sticky | t_norm2_add_mant[0])) 
	  begin
	     t_round_add_mant = t_norm2_add_mant + 'd1;
	  end
     end


   wire [W-1:0] w_y = {t_align_sign, 
		       t_round_add_exp[EW-1:0],
		       t_round_add_mant[FW-1:0]
		       };
   
   always_ff@(negedge clk)
     begin
   	if(en && (FW == 52))
   	  begin
    	     $display("IN : a sign %b exp = %d, a frac = %x", 
   		      a[W-1], a[W-2:FW], a[FW-1:0]);
   	     $display("IN : b sign %b exp = %d, b frac = %x", 
   		      w_b[W-1], b[W-2:FW], b[FW-1:0]);
	     
   	     $display("t_a_align_mant = %x", t_a_align_mant);
   	     $display("t_b_align_mant = %x", t_b_align_mant);

   	     $display("t_add_mant = %b, dist = %d", t_add_mant, w_shft_lft_dist);
		      
   	     $display("\tnorm2 = sign %b exp %d, frac %x (t_dist_a = %d, t_dist_b = %d)",
   		      t_align_sign,
   		      t_norm2_add_exp[EW-1:0],
   		      t_norm2_add_mant[FW-1:0],
   		      t_dist_a,
   		      t_dist_b);

	     $display("\ta_shifted %b, b_shifted %b", a_shifted, b_shifted);
   	     $display("\trounded frac %x", t_round_add_mant[FW-1:0]);	     
   	  end
     end
   
   
   shiftreg #(.W(W), .D(4)) sr0 (.clk(clk), .in(w_y), .out(y));
   
     
endmodule // sp_add
