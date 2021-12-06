module ext_mask(x,sz,y);
   input logic [31:0] x;
   input logic [4:0]  sz;
   output logic [31:0] y;

   always_comb
     begin
	case(sz)
	  5'd0:
	    y = {31'd0, x[0]};	    
	  5'd1:
	    y = {30'd0, x[1:0]};
	  5'd2:
	    y = {29'd0, x[2:0]};
	  5'd3:
	    y = {28'd0, x[3:0]};
	  5'd4:
	    y = {27'd0, x[4:0]};
	  5'd5:
	    y = {26'd0, x[5:0]};
	  5'd6:
	    y = {25'd0, x[6:0]};
	  5'd7:
	    y = {24'd0, x[7:0]};
	  5'd8:
	    y = {23'd0, x[8:0]};
	  5'd9:
	    y = {22'd0, x[9:0]};
	  5'd10:
	    y = {21'd0, x[10:0]};
	  5'd11:
	    y = {20'd0, x[11:0]};	  	  	  
	  5'd12:
	    y = {19'd0, x[12:0]};
	  5'd13:
	    y = {18'd0, x[13:0]};
	  5'd14:
	    y = {17'd0, x[14:0]};
	  5'd15:
	    y = {16'd0, x[15:0]};
	  5'd16:
	    y = {15'd0, x[16:0]};
	  5'd17:
	    y = {14'd0, x[17:0]};	  
	  5'd18:
	    y = {13'd0, x[18:0]};
	  5'd19:
	    y = {12'd0, x[19:0]};
	  5'd20:
	    y = {11'd0, x[20:0]};
	  5'd21:
	    y = {10'd0, x[21:0]};
	  5'd22:
	    y = {9'd0,  x[22:0]};
	  5'd23:
	    y = {8'd0,  x[23:0]};
	  5'd24:
	    y = {7'd0,  x[24:0]};
	  5'd25:
	    y = {6'd0,  x[25:0]};
	  5'd26:
	    y = {5'd0,  x[26:0]};
	  5'd27:
	    y = {4'd0,  x[27:0]};	  	  	  	  	  
	  5'd28:
	    y = {3'd0,  x[28:0]};	  	  	  	  	  
	  5'd29:
	    y = {2'd0,  x[29:0]};	  	  	  	  	  
	  5'd30:
	    y = {1'd0,  x[30:0]};
	  5'd31:
	    y = x;
	endcase // case (sz)
     end // always_comb
endmodule // ext_mask
