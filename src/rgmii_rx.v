`timescale 1ns/1ps
module rgmii_rx(
	input reset,
	input speed, // 0 - 10/100M, 1 - 1000M

	// In-band Status
	output ibs_up,
	output [1:0] ibs_spd,
	output ibs_dplx,

	// RGMII interface
	input rgmii_rxclk, // 125M/25M/2.5M
	input [3:0] rgmii_rxdat,
	input rgmii_rxctl,

	// GMII interface
	output rxclk_x2,
	output rxclk,
	output [7:0] rxd,
	output rxdv,
	output rxer,
	output crs
);

// About in-band status
// Link status indicated when {rxdv,rxer}=={0,0}
// rxd[0]: 0 - link down, 1 - link up
// rxd[2:1]: 00 - 10M, 01 - 100M, 10 - 1000M, 11 - reserved
// rxd[3]: 0 - half duplex, 1 - full duplex

// ALIGNED - input clock edge aligned with data edge (Source Synchronous)
// DELAYED - input clock edge has 2ns delay after data edge (Clock Delayed)
// SYSTEM - input clock edge is ahead of data edge (System Synchronous)
parameter MODE = "DELAYED"; 

wire clk_src;
wire clk_in;
wire clk_div;
wire rxclk_i;
wire [7:0] data_in;
wire rxctl_r;
wire rxctl_f;

wire clk_dly;
wire [3:0] dat_dly;
wire ctl_dly;

reg [3:0] data_0_r;
reg odd_flag;
reg [7:0] data_0;
reg valid_0;
reg error_0;
reg [7:0] data_1;
reg valid_1;
reg error_1;
reg crs_1;

reg up_0, up_1;
reg [1:0] spd_0, spd_1;
reg dplx_0, dplx_1;

(* ASYNC_REG = "TRUE" *)
reg [3:0] rst_sync;
wire rst_in;

//assign rxdv_in = rxctl_r|rxctl_f;
assign rxdv_in = rxctl_r;
assign rxer_in = rxctl_r^rxctl_f;

assign rxd = data_1;
assign rxdv = valid_1;
assign rxer = error_1;
assign crs = crs_1;
assign rxclk_x2 = clk_in;

assign ibs_up = up_1;
assign ibs_spd = spd_1;
assign ibs_dplx = dplx_1;

assign rst_in = !rst_sync[3];

always @(posedge clk_div, posedge reset)
begin
	if(reset)
		rst_sync <= 'b0;
	else
		rst_sync <= {rst_sync, 1'b1};
end

generate
if(MODE=="ALIGNED") begin // Aligned RX clock. Add internal delay
	assign #2 clk_dly = rgmii_rxclk; // simulation only
	//assign clk_src = clk_in;
	BUFIO clk_src_i(.I(clk_dly), .O(clk_src)); // BUFIO has a delay of about 1ns
	BUFR #(.BUFR_DIVIDE("1")) clk_in_i(.I(clk_dly), .CLR(1'b0), .CE(1'b1), .O(clk_in));
	BUFR #(.BUFR_DIVIDE("2")) clk_div_i(.I(clk_dly), .CLR(1'b0), .CE(1'b1), .O(clk_div));
end
else if(MODE=="DELAYED") begin // RX clock already delayed. No internal delay. 
	assign clk_dly = rgmii_rxclk;
	assign clk_src = clk_in;
	//BUFG clk_in_i (.I(clk_dly), .O(clk_in)); // BUFG has smallest delay
	BUFR #(.BUFR_DIVIDE("BYPASS")) clk_in_i(.I(clk_dly), .CLR(1'b0), .CE(1'b1), .O(clk_in));
	BUFR #(.BUFR_DIVIDE("2")) clk_div_i(.I(clk_dly), .CLR(1'b0), .CE(1'b1), .O(clk_div));
end
else if(MODE=="SYSTEM") begin // special case
	assign clk_dly = !rgmii_rxclk;
	assign clk_src = clk_in;
	BUFG clk_in_i (.I(clk_dly), .O(clk_in)); // BUFG has smallest delay
	BUFR #(.BUFR_DIVIDE("2")) clk_div_i(.I(clk_dly), .CLR(1'b0), .CE(1'b1), .O(clk_div));
end

//if(MODE=="SYSTEM") begin
//	ZHOLD_DELAY dat0_dly_i(.DLYFABRIC(), .DLYIFF(dat_dly[0]), .DLYIN(rgmii_rxdat[0]));
//	ZHOLD_DELAY dat1_dly_i(.DLYFABRIC(), .DLYIFF(dat_dly[1]), .DLYIN(rgmii_rxdat[1]));
//	ZHOLD_DELAY dat2_dly_i(.DLYFABRIC(), .DLYIFF(dat_dly[2]), .DLYIN(rgmii_rxdat[2]));
//	ZHOLD_DELAY dat3_dly_i(.DLYFABRIC(), .DLYIFF(dat_dly[3]), .DLYIN(rgmii_rxdat[3]));
//	ZHOLD_DELAY ctl_dly_i(.DLYFABRIC(), .DLYIFF(ctl_dly), .DLYIN(rgmii_rxctl));
//end
//else begin
	assign dat_dly = rgmii_rxdat;
	assign ctl_dly = rgmii_rxctl;
//end
endgenerate

BUFGMUX_CTRL clk_mux_i(.I0(clk_div), .I1(clk_in), .S(speed), .O(rxclk_i));
assign #1 rxclk = rxclk_i; // for simulation purpose

IDDR #(.DDR_CLK_EDGE("SAME_EDGE_PIPELINED")) d0_iddr_i(
	.D(dat_dly[0]),.C(clk_src),.Q1(data_in[0]),.Q2(data_in[4]),.CE(1'b1),.S(1'b0),.R(rst_in));

IDDR #(.DDR_CLK_EDGE("SAME_EDGE_PIPELINED")) d1_iddr_i(
	.D(dat_dly[1]),.C(clk_src),.Q1(data_in[1]),.Q2(data_in[5]),.CE(1'b1),.S(1'b0),.R(rst_in));

IDDR #(.DDR_CLK_EDGE("SAME_EDGE_PIPELINED")) d2_iddr_i(
	.D(dat_dly[2]),.C(clk_src),.Q1(data_in[2]),.Q2(data_in[6]),.CE(1'b1),.S(1'b0),.R(rst_in));

IDDR #(.DDR_CLK_EDGE("SAME_EDGE_PIPELINED")) d3_iddr_i(
	.D(dat_dly[3]),.C(clk_src),.Q1(data_in[3]),.Q2(data_in[7]),.CE(1'b1),.S(1'b0),.R(rst_in));

IDDR #(.DDR_CLK_EDGE("SAME_EDGE_PIPELINED")) ctl_iddr_i(
	.D(ctl_dly),.C(clk_src),.Q1(rxctl_r),.Q2(rxctl_f),.CE(1'b1),.S(1'b0),.R(rst_in));

always @(negedge clk_in, posedge rst_in)
begin
	if(rst_in) begin
		data_0 <= 'b0;
		valid_0 <= 1'b0;
		error_0 <= 1'b0;
		odd_flag <= 1'b0;
		data_0_r <= 'b0;
	end
	else if(speed) begin
		data_0 <= data_in;
		valid_0 <= rxdv_in;
		error_0 <= rxer_in;
		odd_flag <= 1'b0;
	end
	else begin
		if(!odd_flag) begin
			//if(rxdv_in)
				data_0_r[3:0] <= data_in[3:0];

			if(rxdv_in || valid_0) begin
				odd_flag <= 1'b1;
			end
		end
		else begin
			data_0[3:0] <= data_0_r[3:0];
			data_0[7:4] <= data_in[3:0];
			valid_0 <= rxdv_in;
			error_0 <= rxer_in;
			odd_flag <= 1'b0;
		end
	end
end

always @(posedge rxclk, posedge rst_in)
begin
	if(rst_in) begin
		data_1 <= 'b0;
		valid_1 <= 1'b0;
		error_1 <= 1'b0;
		crs_1 <= 1'b0;
	end
	else begin
		data_1 <= data_0;
		valid_1 <= valid_0;
		error_1 <= error_0;
		// in-band CRS status according to RGMII v2.0 standard.
		crs_1 <= valid_0 || (error_0 && (
			data_0==8'h0E || data_0==8'h0F || data_0==8'h1F || data_0==8'hFF));
	end
end

// Optional in-band link status. 
// Please read PHY datasheet to make sure if your PHY supports it.
// If not supported, use MDIO to read link status instead.
always @(negedge clk_in, posedge rst_in)
begin
	if(rst_in) begin
		up_0 <= 1'b0;
		spd_0 <= 2'b10;
		dplx_0 <= 1'b1;
	end
	else if(!rxdv_in && !rxer_in) begin
		up_0 <= data_in[0];
		spd_0 <= data_in[2:1];
		dplx_0 <= data_in[3];
	end
end

always @(posedge clk_in, posedge rst_in)
begin
	if(rst_in) begin
		up_1 <= 1'b0;
		spd_1 <= 2'b10;
		dplx_1 <= 1'b1;
	end
	else begin
		up_1 <= up_0;
		spd_1 <= up_0 ? spd_0 : 2'b10;
		dplx_1 <= up_0 ? dplx_0 : 1'b1;
	end
end

endmodule
