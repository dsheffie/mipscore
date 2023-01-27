module decode_mips32 (
	in_64b_fpreg_mode,
	insn,
	pc,
	insn_pred,
	pht_idx,
	insn_pred_target,
	uop
);
	input wire in_64b_fpreg_mode;
	input wire [31:0] insn;
	input wire [63:0] pc;
	input wire insn_pred;
	input wire [15:0] pht_idx;
	input wire [63:0] insn_pred_target;
	output reg [206:0] uop;
	reg [5:0] opcode = insn[31:26];
	reg is_nop = insn == 32'd0;
	reg is_ehb = insn == 32'd192;
	localparam ZP = 1;
	localparam FCR_ZP = 3;
	reg [5:0] rs = {{ZP {1'b0}}, insn[25:21]};
	reg [5:0] rt = {{ZP {1'b0}}, insn[20:16]};
	reg [5:0] rd = {{ZP {1'b0}}, insn[15:11]};
	reg [5:0] fs = {{ZP {1'b0}}, insn[15:11]};
	reg [5:0] ft = {{ZP {1'b0}}, insn[20:16]};
	reg [5:0] fd = {{ZP {1'b0}}, insn[10:6]};
	reg [5:0] shamt = {{ZP {1'b0}}, insn[10:6]};
	always @(*) begin
		uop[206-:8] = 8'd160;
		uop[198-:6] = 'd0;
		uop[190-:6] = 'd0;
		uop[182-:6] = 'd0;
		uop[174-:6] = 'd0;
		uop[192] = 1'b0;
		uop[184] = 1'b0;
		uop[176] = 1'b0;
		uop[191] = 1'b0;
		uop[183] = 1'b0;
		uop[175] = 1'b0;
		uop[166] = 1'b0;
		uop[162] = 1'b0;
		uop[165] = 1'b0;
		uop[161] = 1'b0;
		uop[164-:2] = 'd0;
		uop[160-:2] = 'd0;
		uop[168] = 1'b0;
		uop[167] = 1'b0;
		uop[158] = 1'b0;
		uop[157] = 1'b0;
		uop[156-:16] = 16'd0;
		uop[140-:48] = {48 {1'b0}};
		uop[92-:64] = pc;
		uop[23] = 1'b0;
		uop[22] = 1'b0;
		uop[28-:5] = 'd0;
		uop[21] = 1'b0;
		uop[19] = 1'b0;
		uop[15-:16] = pht_idx;
		uop[18] = 1'b0;
		uop[17] = 1'b0;
		uop[20] = 1'b0;
		uop[16] = 1'b0;
		case (opcode)
			6'd0:
				case (insn[5:0])
					6'd0: begin
						uop[198-:6] = rt;
						uop[192] = 1'b1;
						uop[190-:6] = shamt;
						uop[174-:6] = rd;
						uop[168] = rd != 'd0;
						uop[206-:8] = (is_nop || is_ehb ? 8'd156 : 8'd0);
						uop[20] = 1'b1;
					end
					6'd1: begin
						if (rd == 'd0) begin
							uop[206-:8] = 8'd156;
							uop[168] = 1'b0;
						end
						else begin
							uop[174-:6] = rd;
							uop[198-:6] = rs;
							uop[192] = 1'b1;
							uop[190-:6] = rd;
							uop[184] = 1'b1;
							uop[182-:6] = {{FCR_ZP {1'b0}}, insn[20:18]};
							uop[162] = 1'b1;
							uop[206-:8] = (insn[16] ? 8'd145 : 8'd144);
							uop[168] = 1'b1;
						end
						uop[20] = 1'b1;
					end
					6'd2: begin
						uop[198-:6] = rt;
						uop[192] = 1'b1;
						uop[190-:6] = shamt;
						uop[174-:6] = rd;
						uop[168] = rd != 'd0;
						uop[206-:8] = (rd == 'd0 ? 8'd156 : 8'd1);
						uop[20] = 1'b1;
					end
					6'd3: begin
						uop[198-:6] = rt;
						uop[192] = 1'b1;
						uop[190-:6] = shamt;
						uop[174-:6] = rd;
						uop[168] = rd != 'd0;
						uop[206-:8] = (rd == 'd0 ? 8'd156 : 8'd2);
						uop[20] = 1'b1;
					end
					6'd4: begin
						uop[198-:6] = rt;
						uop[192] = 1'b1;
						uop[190-:6] = rs;
						uop[184] = 1'b1;
						uop[174-:6] = rd;
						uop[168] = rd != 'd0;
						uop[206-:8] = (rd == 'd0 ? 8'd156 : 8'd3);
						uop[20] = 1'b1;
					end
					6'd5: begin
						uop[206-:8] = 8'd155;
						uop[23] = 1'b1;
						uop[158] = 1'b0;
						uop[22] = 1'b1;
						uop[174-:6] = 'd2;
						uop[168] = 1'b1;
						uop[198-:6] = 'd31;
						uop[192] = 1'b1;
						uop[156-:16] = {1'b0, insn[21:7]};
						uop[20] = 1'b1;
					end
					6'd6: begin
						uop[198-:6] = rt;
						uop[192] = 1'b1;
						uop[190-:6] = rs;
						uop[184] = 1'b1;
						uop[174-:6] = rd;
						uop[168] = rd != 'd0;
						uop[206-:8] = (rd == 'd0 ? 8'd156 : 8'd4);
						uop[20] = 1'b1;
					end
					6'd7: begin
						uop[198-:6] = rt;
						uop[192] = 1'b1;
						uop[190-:6] = rs;
						uop[184] = 1'b1;
						uop[174-:6] = rd;
						uop[168] = rd != 'd0;
						uop[206-:8] = (rd == 'd0 ? 8'd156 : 8'd5);
						uop[20] = 1'b1;
					end
					6'd8: begin
						uop[198-:6] = rs;
						uop[192] = 1'b1;
						uop[158] = 1'b1;
						uop[206-:8] = 8'd6;
						uop[156-:16] = insn_pred_target[15:0];
						uop[140-:48] = insn_pred_target[63:16];
						uop[19] = 1'b1;
						uop[20] = 1'b1;
					end
					6'd9: begin
						uop[198-:6] = rs;
						uop[192] = 1'b1;
						uop[158] = 1'b1;
						uop[206-:8] = 8'd7;
						uop[168] = rd != 'd0;
						uop[174-:6] = rd;
						uop[156-:16] = insn_pred_target[15:0];
						uop[140-:48] = insn_pred_target[63:16];
						uop[19] = 1'b1;
						uop[20] = 1'b1;
					end
					6'd10: begin
						uop[198-:6] = rt;
						uop[192] = 1'b1;
						uop[190-:6] = rs;
						uop[184] = 1'b1;
						uop[182-:6] = rd;
						uop[176] = 1'b1;
						uop[174-:6] = rd;
						uop[168] = rd != 'd0;
						uop[206-:8] = (rd == 'd0 ? 8'd156 : 8'd62);
						uop[20] = 1'b1;
					end
					6'd11: begin
						uop[198-:6] = rt;
						uop[192] = 1'b1;
						uop[190-:6] = rs;
						uop[184] = 1'b1;
						uop[182-:6] = rd;
						uop[176] = 1'b1;
						uop[174-:6] = rd;
						uop[168] = rd != 'd0;
						uop[206-:8] = (rd == 'd0 ? 8'd156 : 8'd61);
						uop[20] = 1'b1;
					end
					6'd12: begin
						uop[206-:8] = 8'd8;
						uop[198-:6] = 'd7;
						uop[192] = 1'b1;
						uop[190-:6] = 'd2;
						uop[184] = 1'b1;
						uop[174-:6] = 'd2;
						uop[168] = 1'b1;
						uop[22] = 1'b1;
						uop[23] = 1'b1;
						uop[20] = 1'b1;
					end
					6'd13: begin
						uop[206-:8] = 8'd101;
						uop[23] = 1'b1;
						uop[20] = 1'b1;
					end
					6'd15: begin
						uop[206-:8] = 8'd100;
						uop[18] = 1'b1;
						uop[20] = 1'b1;
					end
					6'd16: begin
						uop[206-:8] = (rd == 'd0 ? 8'd156 : 8'd9);
						uop[174-:6] = rd;
						uop[168] = rd != 'd0;
						uop[161] = 1'b1;
						uop[20] = 1'b1;
					end
					6'd17: begin
						uop[206-:8] = 8'd10;
						uop[198-:6] = rs;
						uop[192] = 1'b1;
						uop[161] = 1'b1;
						uop[165] = 1'b1;
						uop[20] = 1'b1;
					end
					6'd18: begin
						uop[206-:8] = (rd == 'd0 ? 8'd156 : 8'd25);
						uop[174-:6] = rd;
						uop[168] = rd != 'd0;
						uop[161] = 1'b1;
						uop[20] = 1'b1;
					end
					6'd19: begin
						uop[206-:8] = 8'd26;
						uop[198-:6] = rs;
						uop[192] = 1'b1;
						uop[161] = 1'b1;
						uop[165] = 1'b1;
						uop[20] = 1'b1;
					end
					6'd20: begin
						uop[198-:6] = rt;
						uop[192] = 1'b1;
						uop[190-:6] = rs;
						uop[184] = 1'b1;
						uop[174-:6] = rd;
						uop[168] = rd != 'd0;
						uop[206-:8] = (rd == 'd0 ? 8'd156 : 8'd86);
						uop[20] = 1'b1;
					end
					6'd22: begin
						uop[198-:6] = rt;
						uop[192] = 1'b1;
						uop[190-:6] = rs;
						uop[184] = 1'b1;
						uop[174-:6] = rd;
						uop[168] = rd != 'd0;
						uop[206-:8] = (rd == 'd0 ? 8'd156 : 8'd87);
						uop[20] = 1'b1;
					end
					6'd23: begin
						uop[198-:6] = rt;
						uop[192] = 1'b1;
						uop[190-:6] = rs;
						uop[184] = 1'b1;
						uop[174-:6] = rd;
						uop[168] = rd != 'd0;
						uop[206-:8] = (rd == 'd0 ? 8'd156 : 8'd88);
						uop[20] = 1'b1;
					end
					6'd24: begin
						uop[198-:6] = rs;
						uop[192] = 1'b1;
						uop[190-:6] = rt;
						uop[184] = 1'b1;
						uop[165] = 1'b1;
						uop[206-:8] = 8'd11;
						uop[20] = 1'b1;
					end
					6'd25: begin
						uop[198-:6] = rs;
						uop[192] = 1'b1;
						uop[190-:6] = rt;
						uop[184] = 1'b1;
						uop[165] = 1'b1;
						uop[206-:8] = 8'd12;
						uop[20] = 1'b1;
					end
					6'd26: begin
						uop[198-:6] = rs;
						uop[192] = 1'b1;
						uop[190-:6] = rt;
						uop[184] = 1'b1;
						uop[165] = 1'b1;
						uop[206-:8] = 8'd13;
						uop[20] = 1'b1;
					end
					6'd27: begin
						uop[198-:6] = rs;
						uop[192] = 1'b1;
						uop[190-:6] = rt;
						uop[184] = 1'b1;
						uop[165] = 1'b1;
						uop[206-:8] = 8'd14;
						uop[20] = 1'b1;
					end
					6'd33: begin
						uop[198-:6] = rt;
						uop[192] = 1'b1;
						uop[190-:6] = rs;
						uop[184] = 1'b1;
						uop[174-:6] = rd;
						uop[168] = rd != 'd0;
						uop[206-:8] = (rd == 'd0 ? 8'd156 : 8'd16);
						uop[20] = 1'b1;
					end
					6'd45: begin
						uop[198-:6] = rt;
						uop[192] = 1'b1;
						uop[190-:6] = rs;
						uop[184] = 1'b1;
						uop[174-:6] = rd;
						uop[168] = rd != 'd0;
						uop[206-:8] = (rd == 'd0 ? 8'd156 : 8'd77);
						uop[20] = 1'b1;
					end
					6'd35: begin
						uop[198-:6] = rs;
						uop[192] = 1'b1;
						uop[190-:6] = rt;
						uop[184] = 1'b1;
						uop[174-:6] = rd;
						uop[168] = rd != 'd0;
						uop[206-:8] = (rd == 'd0 ? 8'd156 : 8'd18);
						uop[20] = 1'b1;
					end
					6'd36: begin
						uop[198-:6] = rt;
						uop[192] = 1'b1;
						uop[190-:6] = rs;
						uop[184] = 1'b1;
						uop[174-:6] = rd;
						uop[168] = rd != 'd0;
						uop[206-:8] = (rd == 'd0 ? 8'd156 : 8'd19);
						uop[20] = 1'b1;
					end
					6'd37:
						if (rs == 'd0) begin
							uop[198-:6] = rt;
							uop[192] = 1'b1;
							uop[174-:6] = rd;
							uop[168] = rd != 'd0;
							uop[206-:8] = (rd == 'd0 ? 8'd156 : 8'd154);
							uop[20] = 1'b1;
						end
						else begin
							uop[198-:6] = rt;
							uop[192] = 1'b1;
							uop[190-:6] = rs;
							uop[184] = 1'b1;
							uop[174-:6] = rd;
							uop[168] = rd != 'd0;
							uop[206-:8] = (rd == 'd0 ? 8'd156 : 8'd20);
							uop[20] = 1'b1;
						end
					6'd38: begin
						uop[198-:6] = rt;
						uop[192] = 1'b1;
						uop[190-:6] = rs;
						uop[184] = 1'b1;
						uop[174-:6] = rd;
						uop[168] = rd != 'd0;
						uop[206-:8] = (rd == 'd0 ? 8'd156 : 8'd21);
						uop[20] = 1'b1;
					end
					6'd39: begin
						uop[198-:6] = rt;
						uop[192] = 1'b1;
						uop[190-:6] = rs;
						uop[184] = 1'b1;
						uop[174-:6] = rd;
						uop[168] = rd != 'd0;
						uop[206-:8] = (rd == 'd0 ? 8'd156 : 8'd22);
						uop[20] = 1'b1;
					end
					6'd42: begin
						uop[198-:6] = rt;
						uop[192] = 1'b1;
						uop[190-:6] = rs;
						uop[184] = 1'b1;
						uop[174-:6] = rd;
						uop[168] = rd != 'd0;
						uop[206-:8] = (rd == 'd0 ? 8'd156 : 8'd23);
						uop[20] = 1'b1;
					end
					6'd43: begin
						uop[198-:6] = rt;
						uop[192] = 1'b1;
						uop[190-:6] = rs;
						uop[184] = 1'b1;
						uop[174-:6] = rd;
						uop[168] = rd != 'd0;
						uop[206-:8] = (rd == 'd0 ? 8'd156 : 8'd24);
						uop[20] = 1'b1;
					end
					6'd47: begin
						uop[198-:6] = rt;
						uop[192] = 1'b1;
						uop[190-:6] = rs;
						uop[184] = 1'b1;
						uop[174-:6] = rd;
						uop[168] = rd != 'd0;
						uop[206-:8] = (rd == 'd0 ? 8'd156 : 8'd79);
						uop[20] = 1'b1;
					end
					6'd52: begin
						uop[206-:8] = 8'd156;
						uop[20] = 1'b1;
					end
					6'd56: begin
						uop[198-:6] = rt;
						uop[192] = 1'b1;
						uop[190-:6] = shamt;
						uop[174-:6] = rd;
						uop[168] = rd != 'd0;
						uop[206-:8] = (rd == 'd0 ? 8'd156 : 8'd80);
						uop[20] = 1'b1;
					end
					6'd58: begin
						uop[198-:6] = rt;
						uop[192] = 1'b1;
						uop[190-:6] = shamt;
						uop[174-:6] = rd;
						uop[168] = rd != 'd0;
						uop[206-:8] = (rd == 'd0 ? 8'd156 : 8'd81);
						uop[20] = 1'b1;
					end
					6'd59: begin
						uop[198-:6] = rt;
						uop[192] = 1'b1;
						uop[190-:6] = shamt;
						uop[174-:6] = rd;
						uop[168] = rd != 'd0;
						uop[206-:8] = (rd == 'd0 ? 8'd156 : 8'd82);
						uop[20] = 1'b1;
					end
					6'd60: begin
						uop[198-:6] = rt;
						uop[192] = 1'b1;
						uop[190-:6] = shamt;
						uop[174-:6] = rd;
						uop[168] = rd != 'd0;
						uop[206-:8] = (rd == 'd0 ? 8'd156 : 8'd83);
						uop[20] = 1'b1;
					end
					6'd62: begin
						uop[198-:6] = rt;
						uop[192] = 1'b1;
						uop[190-:6] = shamt;
						uop[174-:6] = rd;
						uop[168] = rd != 'd0;
						uop[206-:8] = (rd == 'd0 ? 8'd156 : 8'd84);
						uop[20] = 1'b1;
					end
					6'd63: begin
						uop[198-:6] = rt;
						uop[192] = 1'b1;
						uop[190-:6] = shamt;
						uop[174-:6] = rd;
						uop[168] = rd != 'd0;
						uop[206-:8] = (rd == 'd0 ? 8'd156 : 8'd85);
						uop[20] = 1'b1;
					end
					default:
						;
				endcase
			6'd1: begin
				uop[198-:6] = rs;
				uop[192] = 1'b1;
				uop[158] = 1'b1;
				uop[156-:16] = insn[15:0];
				uop[19] = 1'b1;
				uop[20] = 1'b1;
				uop[21] = insn_pred;
				case (rt[4:0])
					'd0: uop[206-:8] = 8'd55;
					'd1: uop[206-:8] = 8'd56;
					'd2: begin
						uop[206-:8] = 8'd57;
						uop[157] = 1'b1;
					end
					'd3: begin
						uop[206-:8] = 8'd58;
						uop[157] = 1'b1;
					end
					'd17: begin
						uop[206-:8] = (rs == 'd0 ? 8'd95 : 8'd96);
						uop[168] = 1'b1;
						uop[174-:6] = 'd31;
						uop[190-:6] = 'd31;
						uop[184] = (rs == 'd0 ? 1'b0 : 1'b1);
					end
					default: uop[206-:8] = 8'd160;
				endcase
			end
			6'd2: begin
				uop[206-:8] = 8'd39;
				uop[19] = 1'b1;
				uop[20] = 1'b1;
				uop[158] = 1'b1;
			end
			6'd3: begin
				uop[206-:8] = 8'd40;
				uop[158] = 1'b1;
				uop[156-:16] = insn[15:0];
				uop[140-:48] = {{38 {1'b0}}, insn[25:16]};
				uop[168] = 1'b1;
				uop[174-:6] = 'd31;
				uop[21] = 1'b1;
				uop[19] = 1'b1;
				uop[20] = 1'b1;
			end
			6'd4: begin
				uop[206-:8] = 8'd27;
				uop[168] = 1'b0;
				uop[174-:6] = 'd0;
				uop[198-:6] = rs;
				uop[192] = 1'b1;
				uop[190-:6] = rt;
				uop[184] = 1'b1;
				uop[158] = 1'b1;
				uop[156-:16] = insn[15:0];
				uop[21] = insn_pred;
				uop[19] = 1'b1;
				uop[20] = 1'b1;
			end
			6'd5: begin
				uop[206-:8] = 8'd28;
				uop[168] = 1'b0;
				uop[174-:6] = 'd0;
				uop[198-:6] = rs;
				uop[192] = 1'b1;
				uop[190-:6] = rt;
				uop[184] = 1'b1;
				uop[158] = 1'b1;
				uop[156-:16] = insn[15:0];
				uop[21] = insn_pred;
				uop[19] = 1'b1;
				uop[20] = 1'b1;
			end
			6'd6: begin
				uop[206-:8] = 8'd29;
				uop[168] = 1'b0;
				uop[174-:6] = 'd0;
				uop[198-:6] = rs;
				uop[192] = 1'b1;
				uop[158] = 1'b1;
				uop[156-:16] = insn[15:0];
				uop[21] = insn_pred;
				uop[19] = 1'b1;
				uop[20] = 1'b1;
			end
			6'd7: begin
				uop[206-:8] = 8'd30;
				uop[168] = 1'b0;
				uop[174-:6] = 'd0;
				uop[198-:6] = rs;
				uop[192] = 1'b1;
				uop[158] = 1'b1;
				uop[156-:16] = insn[15:0];
				uop[21] = insn_pred;
				uop[19] = 1'b1;
				uop[20] = 1'b1;
			end
			6'd9:
				if (rs == 'd0) begin
					uop[206-:8] = (rt == 'd0 ? 8'd156 : 8'd153);
					uop[168] = rt != 'd0;
					uop[20] = 1'b1;
					uop[174-:6] = rt;
					uop[156-:16] = insn[15:0];
				end
				else begin
					uop[206-:8] = (rt == 'd0 ? 8'd156 : 8'd32);
					uop[192] = 1'b1;
					uop[198-:6] = rs;
					uop[168] = rt != 'd0;
					uop[20] = 1'b1;
					uop[174-:6] = rt;
					uop[156-:16] = insn[15:0];
				end
			6'd10: begin
				uop[206-:8] = (rt == 'd0 ? 8'd156 : 8'd33);
				uop[192] = 1'b1;
				uop[198-:6] = rs;
				uop[168] = rt != 'd0;
				uop[174-:6] = rt;
				uop[20] = 1'b1;
				uop[156-:16] = insn[15:0];
			end
			6'd11: begin
				uop[206-:8] = (rt == 'd0 ? 8'd156 : 8'd34);
				uop[192] = 1'b1;
				uop[198-:6] = rs;
				uop[168] = rt != 'd0;
				uop[174-:6] = rt;
				uop[20] = 1'b1;
				uop[156-:16] = insn[15:0];
			end
			6'd12: begin
				uop[206-:8] = (rt == 'd0 ? 8'd156 : 8'd35);
				uop[192] = 1'b1;
				uop[198-:6] = rs;
				uop[168] = rt != 'd0;
				uop[174-:6] = rt;
				uop[20] = 1'b1;
				uop[156-:16] = insn[15:0];
			end
			6'd13: begin
				uop[206-:8] = (rt == 'd0 ? 8'd156 : 8'd36);
				uop[192] = 1'b1;
				uop[198-:6] = rs;
				uop[168] = rt != 'd0;
				uop[174-:6] = rt;
				uop[20] = 1'b1;
				uop[156-:16] = insn[15:0];
			end
			6'd14: begin
				uop[206-:8] = (rt == 'd0 ? 8'd156 : 8'd37);
				uop[192] = 1'b1;
				uop[198-:6] = rs;
				uop[168] = rt != 'd0;
				uop[174-:6] = rt;
				uop[20] = 1'b1;
				uop[156-:16] = insn[15:0];
			end
			6'd15: begin
				uop[206-:8] = (rt == 'd0 ? 8'd156 : 8'd38);
				uop[168] = rt != 'd0;
				uop[174-:6] = rt;
				uop[20] = 1'b1;
				uop[156-:16] = insn[15:0];
			end
			6'd16:
				if (insn[25] && (insn[5:0] == 6'd24)) begin
					uop[206-:8] = 8'd150;
					uop[20] = 1'b1;
					uop[23] = 1'b1;
					uop[22] = 1'b1;
				end
				else if (insn[25] && (insn[5:0] == 6'd32)) begin
					uop[206-:8] = 8'd159;
					uop[20] = 1'b1;
					uop[23] = 1'b1;
					uop[22] = 1'b1;
				end
				else if ((insn[25:21] == 5'b01011) && (insn[15:0] == 16'b0110000000000000)) begin
					uop[206-:8] = 8'd157;
					uop[20] = 1'b1;
					uop[174-:6] = rt;
					uop[168] = rt != 'd0;
					uop[198-:6] = 'd12;
					uop[23] = 1'b1;
					uop[22] = 1'b1;
				end
				else if ((insn[25:21] == 5'b01011) && (insn[15:0] == 16'b0110000000100000)) begin
					uop[206-:8] = 8'd158;
					uop[20] = 1'b1;
					uop[174-:6] = rt;
					uop[168] = rt != 'd0;
					uop[198-:6] = 'd12;
					uop[23] = 1'b1;
					uop[22] = 1'b1;
				end
				else
					case (insn[25:21])
						5'd0: begin
							uop[206-:8] = 8'd41;
							uop[174-:6] = rt;
							uop[168] = 1'b1;
							uop[198-:6] = rd;
							uop[20] = 1'b1;
							uop[23] = 1'b1;
							uop[22] = 1'b1;
						end
						5'd4: begin
							uop[206-:8] = 8'd42;
							uop[174-:6] = rd;
							uop[198-:6] = rt;
							uop[192] = 1'b1;
							uop[23] = 1'b1;
							uop[158] = 1'b0;
							uop[20] = 1'b1;
							uop[22] = 1'b1;
						end
						default:
							;
					endcase
			6'd17:
				if (insn[25:21] == 5'd8) begin
					uop[162] = 1'b1;
					uop[158] = 1'b1;
					uop[156-:16] = insn[15:0];
					uop[21] = insn_pred;
					uop[19] = 1'b1;
					uop[20] = 1'b1;
					uop[182-:6] = {{FCR_ZP {1'b0}}, insn[20:18]};
					case (insn[17:16])
						2'b00: uop[206-:8] = 8'd131;
						2'b01: uop[206-:8] = 8'd129;
						2'b10: begin
							uop[206-:8] = 8'd130;
							uop[157] = 1'b1;
						end
						2'b11: begin
							uop[206-:8] = 8'd128;
							uop[157] = 1'b1;
						end
					endcase
				end
				else if ((insn[25:21] == 5'd0) && (insn[10:0] == 11'd0)) begin
					uop[174-:6] = rt;
					uop[168] = 1'b1;
					if (in_64b_fpreg_mode) begin
						uop[206-:8] = 8'd43;
						uop[190-:6] = rd;
					end
					else begin
						uop[206-:8] = 8'd152;
						uop[190-:6] = {{ZP {1'b0}}, rd[4:1], 1'b0};
						uop[140-:48] = {{47 {1'b0}}, rd[0]};
					end
					uop[183] = 1'b1;
					uop[18] = 1'b1;
				end
				else if ((insn[25:21] == 5'd4) && (insn[10:0] == 11'd0)) begin
					uop[198-:6] = rt;
					uop[192] = 1'b1;
					if (in_64b_fpreg_mode) begin
						uop[206-:8] = 8'd44;
						uop[174-:6] = rd;
					end
					else begin
						uop[206-:8] = 8'd151;
						uop[174-:6] = {{ZP {1'b0}}, rd[4:1], 1'b0};
						uop[190-:6] = {{ZP {1'b0}}, rd[4:1], 1'b0};
						uop[140-:48] = {{47 {1'b0}}, rd[0]};
						uop[183] = 1;
					end
					uop[167] = 1'b1;
					uop[156-:16] = insn[15:0];
					uop[18] = 1'b1;
				end
			6'd20: begin
				uop[206-:8] = 8'd53;
				uop[168] = 1'b0;
				uop[174-:6] = 'd0;
				uop[198-:6] = rs;
				uop[192] = 1'b1;
				uop[190-:6] = rt;
				uop[184] = 1'b1;
				uop[158] = 1'b1;
				uop[157] = 1'b1;
				uop[156-:16] = insn[15:0];
				uop[19] = 1'b1;
				uop[21] = insn_pred;
				uop[20] = 1'b1;
			end
			6'd21: begin
				uop[206-:8] = 8'd54;
				uop[168] = 1'b0;
				uop[174-:6] = 'd0;
				uop[198-:6] = rs;
				uop[192] = 1'b1;
				uop[190-:6] = rt;
				uop[184] = 1'b1;
				uop[158] = 1'b1;
				uop[157] = 1'b1;
				uop[156-:16] = insn[15:0];
				uop[19] = 1'b1;
				uop[21] = insn_pred;
				uop[20] = 1'b1;
			end
			6'd22: begin
				uop[206-:8] = 8'd60;
				uop[168] = 1'b0;
				uop[174-:6] = 'd0;
				uop[198-:6] = rs;
				uop[192] = 1'b1;
				uop[158] = 1'b1;
				uop[157] = 1'b1;
				uop[156-:16] = insn[15:0];
				uop[19] = 1'b1;
				uop[21] = insn_pred;
				uop[20] = 1'b1;
			end
			6'd23: begin
				uop[206-:8] = 8'd59;
				uop[168] = 1'b0;
				uop[174-:6] = 'd0;
				uop[198-:6] = rs;
				uop[192] = 1'b1;
				uop[158] = 1'b1;
				uop[157] = 1'b1;
				uop[156-:16] = insn[15:0];
				uop[19] = 1'b1;
				uop[21] = insn_pred;
				uop[20] = 1'b1;
			end
			6'd25: begin
				uop[206-:8] = (rt == 'd0 ? 8'd156 : 8'd78);
				uop[192] = 1'b1;
				uop[198-:6] = rs;
				uop[168] = rt != 'd0;
				uop[174-:6] = rt;
				uop[20] = 1'b1;
				uop[156-:16] = insn[15:0];
			end
			6'd26: begin
				uop[206-:8] = 8'd91;
				uop[198-:6] = rs;
				uop[192] = 1'b1;
				uop[190-:6] = rt;
				uop[184] = 1'b1;
				uop[174-:6] = rt;
				uop[168] = 1'b1;
				uop[156-:16] = insn[15:0];
				uop[18] = 1'b1;
			end
			6'd27: begin
				uop[206-:8] = 8'd92;
				uop[198-:6] = rs;
				uop[192] = 1'b1;
				uop[190-:6] = rt;
				uop[184] = 1'b1;
				uop[174-:6] = rt;
				uop[168] = 1'b1;
				uop[156-:16] = insn[15:0];
				uop[18] = 1'b1;
			end
			6'd28:
				case (insn[5:0])
					6'd0: begin
						uop[206-:8] = 8'd66;
						uop[198-:6] = rt;
						uop[192] = 1'b1;
						uop[190-:6] = rs;
						uop[184] = 1'b1;
						uop[165] = 1'b1;
						uop[161] = 1'b1;
						uop[20] = 1'b1;
					end
					6'd2: begin
						uop[206-:8] = (rd == 'd0 ? 8'd156 : 8'd68);
						uop[198-:6] = rt;
						uop[192] = 1'b1;
						uop[190-:6] = rs;
						uop[184] = 1'b1;
						uop[174-:6] = rd;
						uop[168] = rd != 'd0;
						uop[20] = 1'b1;
					end
					6'd4: begin
						uop[206-:8] = 8'd69;
						uop[198-:6] = rt;
						uop[192] = 1'b1;
						uop[190-:6] = rs;
						uop[184] = 1'b1;
						uop[165] = 1'b1;
						uop[161] = 1'b1;
						uop[20] = 1'b1;
					end
					6'd32: begin
						uop[206-:8] = (rd == 'd0 ? 8'd156 : 8'd70);
						uop[198-:6] = rs;
						uop[192] = 1'b1;
						uop[174-:6] = rd;
						uop[168] = rd != 'd0;
						uop[20] = 1'b1;
					end
					default:
						;
				endcase
			6'd31:
				case (insn[5:0])
					6'd0: begin
						uop[206-:8] = 8'd64;
						uop[198-:6] = rs;
						uop[192] = 1'b1;
						uop[174-:6] = rt;
						uop[168] = 1'b1;
						uop[156-:16] = insn[15:0];
						uop[20] = 1'b1;
					end
					6'd4: begin
						uop[206-:8] = 8'd65;
						uop[198-:6] = rt;
						uop[192] = 1'b1;
						uop[190-:6] = rs;
						uop[184] = 1'b1;
						uop[174-:6] = rt;
						uop[168] = 1'b1;
						uop[156-:16] = insn[15:0];
						uop[20] = 1'b1;
					end
					6'd32: begin
						uop[206-:8] = (insn[10:6] == 5'd16 ? 8'd75 : 8'd76);
						uop[174-:6] = rd;
						uop[168] = 1'b1;
						uop[198-:6] = rt;
						uop[192] = 1'b1;
						uop[20] = 1'b1;
					end
					6'd59: begin
						uop[206-:8] = 8'd98;
						uop[174-:6] = rt;
						uop[168] = 1'b1;
						uop[198-:6] = rd;
						uop[20] = 1'b1;
					end
					default:
						;
				endcase
			6'd32: begin
				uop[206-:8] = 8'd46;
				uop[198-:6] = rs;
				uop[192] = 1'b1;
				uop[174-:6] = rt;
				uop[168] = rt != 'd0;
				uop[156-:16] = insn[15:0];
				uop[18] = 1'b1;
			end
			6'd33: begin
				uop[206-:8] = 8'd48;
				uop[198-:6] = rs;
				uop[192] = 1'b1;
				uop[174-:6] = rt;
				uop[168] = rt != 'd0;
				uop[156-:16] = insn[15:0];
				uop[18] = 1'b1;
			end
			6'd34: begin
				uop[206-:8] = 8'd71;
				uop[198-:6] = rs;
				uop[192] = 1'b1;
				uop[190-:6] = rt;
				uop[184] = 1'b1;
				uop[174-:6] = rt;
				uop[168] = rt != 'd0;
				uop[156-:16] = insn[15:0];
				uop[18] = 1'b1;
			end
			6'd35: begin
				uop[206-:8] = 8'd45;
				uop[198-:6] = rs;
				uop[192] = 1'b1;
				uop[174-:6] = rt;
				uop[168] = rt != 'd0;
				uop[156-:16] = insn[15:0];
				uop[18] = 1'b1;
			end
			6'd36: begin
				uop[206-:8] = 8'd47;
				uop[198-:6] = rs;
				uop[192] = 1'b1;
				uop[174-:6] = rt;
				uop[168] = rt != 'd0;
				uop[156-:16] = insn[15:0];
				uop[18] = 1'b1;
			end
			6'd37: begin
				uop[206-:8] = 8'd49;
				uop[198-:6] = rs;
				uop[192] = 1'b1;
				uop[174-:6] = rt;
				uop[168] = rt != 'd0;
				uop[156-:16] = insn[15:0];
				uop[18] = 1'b1;
			end
			6'd38: begin
				uop[206-:8] = 8'd72;
				uop[198-:6] = rs;
				uop[192] = 1'b1;
				uop[190-:6] = rt;
				uop[184] = 1'b1;
				uop[174-:6] = rt;
				uop[168] = rt != 'd0;
				uop[156-:16] = insn[15:0];
				uop[18] = 1'b1;
			end
			6'd40: begin
				uop[206-:8] = 8'd50;
				uop[198-:6] = rs;
				uop[192] = 1'b1;
				uop[190-:6] = rt;
				uop[184] = 1'b1;
				uop[156-:16] = insn[15:0];
				uop[18] = 1'b1;
				uop[16] = 1'b1;
			end
			6'd41: begin
				uop[206-:8] = 8'd51;
				uop[198-:6] = rs;
				uop[192] = 1'b1;
				uop[190-:6] = rt;
				uop[184] = 1'b1;
				uop[156-:16] = insn[15:0];
				uop[18] = 1'b1;
				uop[16] = 1'b1;
			end
			6'd42: begin
				uop[206-:8] = 8'd73;
				uop[198-:6] = rs;
				uop[192] = 1'b1;
				uop[190-:6] = rt;
				uop[184] = 1'b1;
				uop[156-:16] = insn[15:0];
				uop[18] = 1'b1;
				uop[16] = 1'b1;
			end
			6'd43: begin
				uop[206-:8] = 8'd52;
				uop[198-:6] = rs;
				uop[192] = 1'b1;
				uop[190-:6] = rt;
				uop[184] = 1'b1;
				uop[156-:16] = insn[15:0];
				uop[18] = 1'b1;
				uop[16] = 1'b1;
			end
			6'd44: begin
				uop[206-:8] = 8'd93;
				uop[198-:6] = rs;
				uop[192] = 1'b1;
				uop[190-:6] = rt;
				uop[184] = 1'b1;
				uop[156-:16] = insn[15:0];
				uop[18] = 1'b1;
				uop[16] = 1'b1;
			end
			6'd45: begin
				uop[206-:8] = 8'd94;
				uop[198-:6] = rs;
				uop[192] = 1'b1;
				uop[190-:6] = rt;
				uop[184] = 1'b1;
				uop[156-:16] = insn[15:0];
				uop[18] = 1'b1;
				uop[16] = 1'b1;
			end
			6'd46: begin
				uop[206-:8] = 8'd74;
				uop[198-:6] = rs;
				uop[192] = 1'b1;
				uop[190-:6] = rt;
				uop[184] = 1'b1;
				uop[156-:16] = insn[15:0];
				uop[18] = 1'b1;
				uop[16] = 1'b1;
			end
			6'd48: begin
				uop[206-:8] = 8'd45;
				uop[198-:6] = rs;
				uop[192] = 1'b1;
				uop[174-:6] = rt;
				uop[168] = rt != 'd0;
				uop[156-:16] = insn[15:0];
				uop[18] = 1'b1;
			end
			6'd49: begin
				uop[198-:6] = rs;
				uop[192] = 1'b1;
				if (in_64b_fpreg_mode) begin
					uop[206-:8] = 8'd105;
					uop[174-:6] = rt;
				end
				else begin
					uop[206-:8] = 8'd106;
					uop[174-:6] = {{ZP {1'b0}}, rt[4:1], 1'b0};
					uop[190-:6] = {{ZP {1'b0}}, rt[4:1], 1'b0};
					uop[183] = 1;
					uop[140-:48] = {{47 {1'b0}}, rt[0]};
				end
				uop[167] = 1'b1;
				uop[156-:16] = insn[15:0];
				uop[18] = 1'b1;
			end
			6'd51: begin
				uop[206-:8] = 8'd156;
				uop[20] = 1'b1;
			end
			6'd53: begin
				uop[206-:8] = 8'd103;
				uop[198-:6] = rs;
				uop[192] = 1'b1;
				uop[174-:6] = rt;
				uop[167] = 1'b1;
				uop[156-:16] = insn[15:0];
				uop[18] = 1'b1;
			end
			6'd55: begin
				uop[206-:8] = 8'd89;
				uop[198-:6] = rs;
				uop[192] = 1'b1;
				uop[174-:6] = rt;
				uop[168] = rt != 'd0;
				uop[156-:16] = insn[15:0];
				uop[18] = 1'b1;
			end
			6'd57: begin
				if (in_64b_fpreg_mode) begin
					uop[206-:8] = 8'd104;
					uop[190-:6] = rt;
				end
				else begin
					uop[206-:8] = 8'd107;
					uop[190-:6] = {{ZP {1'b0}}, rt[4:1], 1'b0};
					uop[140-:48] = {{47 {1'b0}}, rt[0]};
				end
				uop[198-:6] = rs;
				uop[192] = 1'b1;
				uop[183] = 1'b1;
				uop[156-:16] = insn[15:0];
				uop[18] = 1'b1;
				uop[16] = 1'b1;
			end
			6'd61: begin
				uop[206-:8] = 8'd102;
				uop[198-:6] = rs;
				uop[192] = 1'b1;
				uop[190-:6] = rt;
				uop[183] = 1'b1;
				uop[156-:16] = insn[15:0];
				uop[18] = 1'b1;
				uop[16] = 1'b1;
			end
			6'd63: begin
				uop[206-:8] = 8'd90;
				uop[198-:6] = rs;
				uop[192] = 1'b1;
				uop[190-:6] = rt;
				uop[184] = 1'b1;
				uop[156-:16] = insn[15:0];
				uop[18] = 1'b1;
				uop[16] = 1'b1;
			end
			default:
				;
		endcase
	end
endmodule
