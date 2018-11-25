`timescale 1ns/1ps
module rgmii_tx(
	input reset,
	input speed, // 0 - 10/100M, 1 - 1000M

	// GMII interface
	input txclk_x2, // 125M/25M/2.5M
	input txclk, // 125M/12.5M/1.25M
	input [7:0] txd,
	input txen,
	input txer,

	// RGMII interface
	output rgmii_gtxclk, // 125M/25M/2.5M
	output [3:0] rgmii_txdat,
	output rgmii_txctl
);

// ALIGNED - output clock edge aligned with data edge (Source Synchronous)
// DELAYED - output clock edge has 2ns delay after data edge (Clock Delayed)
// SYSTEM - output clock edge is ahead of data edge (System Synchronous)
parameter MODE = "ALIGNED"; 

(* ASYNC_REG = "TRUE" *)
reg [3:0] rst_sync;
wire rst_in;
wire clk_out;

reg txctl_r;
reg txctl_f;

reg [3:0] data_r;
reg [3:0] data_f;

reg odd_flag;

assign rst_in = !rst_sync[3];

always @(posedge txclk_x2, posedge reset)
begin
	if(reset)
		rst_sync <= 'b0;
	else
		rst_sync <= {rst_sync, 1'b1};
end

//BUFGMUX_CTRL clk_mux_i(.I0(txclk_x2), .I1(txclk), .S(speed), .O(clk_out_i));
//assign #1 clk_out = clk_out_i; // for simulation purpose
assign clk_out = txclk_x2; // simplified

always @(negedge clk_out, posedge rst_in)
begin
	if(rst_in) begin
		odd_flag <= 1'b0;
		data_r <= 'bx;
		data_f <= 'bx;
		txctl_r <= 1'b0;
		txctl_f <= 1'b0;
	end
	else if(speed) begin
		data_r <= txd[3:0];
		data_f <= txd[7:4];
		txctl_r = txen;
		txctl_f = txen^txer;
	end
	else begin
		if(!odd_flag) begin
			data_r <= txd[3:0];
			data_f <= txd[3:0];
			txctl_r <= txen;
			txctl_f <= txen^txer;
			if(txen) begin
				odd_flag <= 1'b1;
			end
		end
		else begin
			data_r <= txd[7:4];
			data_f <= txd[7:4];
			odd_flag <= 1'b0;
		end
	end
end

ODDR #(.DDR_CLK_EDGE("SAME_EDGE")) d0_oddr_i(
	.D1(data_r[0]), .D2(data_f[0]), .CE(1'b1), .C(clk_out), .S(1'b0), .R(1'b0), .Q(rgmii_txdat[0]));

ODDR #(.DDR_CLK_EDGE("SAME_EDGE")) d1_oddr_i(
	.D1(data_r[1]), .D2(data_f[1]), .CE(1'b1), .C(clk_out), .S(1'b0), .R(1'b0), .Q(rgmii_txdat[1]));

ODDR #(.DDR_CLK_EDGE("SAME_EDGE")) d2_oddr_i(
	.D1(data_r[2]), .D2(data_f[2]), .CE(1'b1), .C(clk_out), .S(1'b0), .R(1'b0), .Q(rgmii_txdat[2]));

ODDR #(.DDR_CLK_EDGE("SAME_EDGE")) d3_oddr_i(
	.D1(data_r[3]), .D2(data_f[3]), .CE(1'b1), .C(clk_out), .S(1'b0), .R(1'b0), .Q(rgmii_txdat[3]));

ODDR #(.DDR_CLK_EDGE("SAME_EDGE")) ctl_oddr_i(
	.D1(txctl_r), .D2(txctl_f), .CE(1'b1), .C(clk_out), .S(1'b0), .R(1'b0), .Q(rgmii_txctl));


generate
if(MODE=="ALIGNED") begin // no internal delay. 
	ODDR #(.DDR_CLK_EDGE("SAME_EDGE")) clk_oddr_i(
		.D1(1'b1), .D2(1'b0), .CE(1'b1), .C(clk_out), .S(1'b0), .R(1'b0), .Q(rgmii_gtxclk));
end
else if(MODE=="DELAYED") begin // about 2ns additional output delay on 7-series HR bank
	wire rgmii_gtxclk_d;
	wire clk_dly;
	(* DONT_TOUCH = "TRUE" *) 
	LUT1 #(.INIT(2'b10)) d1(.I0(clk_out),.O(clk_dly));
	//LDCE d1(.D(clk_out),.GE(1'b1),.G(1'b1),.CLR(1'b0),.Q(clk_dly));

	OBUF clk_obuf_i(.I(clk_dly), .O(rgmii_gtxclk_d));
	assign #2 rgmii_gtxclk = rgmii_gtxclk_d; // simulation only
end
else if(MODE=="SYSTEM") begin // same with "DELAYED" but inverted so the rise-edge will be ahead of data
	wire rgmii_gtxclk_d;
	OBUF clk_obuf_i(.I(!clk_out), .O(rgmii_gtxclkd));
	assign #2 rgmii_gtxclk = rgmii_gtxclk_d; // simulation only
end
endgenerate

endmodule
