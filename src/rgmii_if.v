module rgmii_if(
	input reset,
	input speed, // 0 - 10/100M, 1 - 1000M

	// In-band Status
	// Optional in-band link status. 
	// Please read PHY datasheet to make sure if your PHY supports it.
	// If not supported, use MDIO to read link status instead.
	output ibs_up,
	output [1:0] ibs_spd,
	output ibs_dplx,
    output interrupt,

	// RGMII interface
	input rgmii_rxclk, // 125M/25M/2.5M
	input [3:0] rgmii_rxdat,
	input rgmii_rxctl,
	output rgmii_gtxclk, // 125M/25M/2.5M
	output [3:0] rgmii_txdat,
	output rgmii_txctl,

	// GMII interface
	input txclk_x2, // 125M/25M/2.5M, used in 10M/100M mode
	input txclk, // 125M/12.5M/1.25M
	input [7:0] txd,
	input txen,
	input txer,
	output rxclk_x2, // 125M/25M/2.5M
	output rxclk, // 125M/12.5M/1.25M
	output [7:0] rxd,
	output rxdv,
	output rxer,
	output crs,
	output col
);
// RGMII 2.0 requires internal delay been add on transmitter side.
// But chips should support alternative schemes.
// ALIGNED - clock edge aligned with data edge (Source Synchronous)
// DELAYED - clock edge has 2ns delay after data edge (Clock Delayed)
// SYSTEM - clock edge is ahead of data edge (System Synchronous)
parameter RX_MODE = "DELAYED";
parameter TX_MODE = "DELAYED";

rgmii_rx #(.MODE(RX_MODE)) rx_i(
	.reset(reset),
	.speed(speed),
	.ibs_up(ibs_up),
	.ibs_spd(ibs_spd),
	.ibs_dplx(ibs_dplx),
	.rgmii_rxclk(rgmii_rxclk),
	.rgmii_rxdat(rgmii_rxdat),
	.rgmii_rxctl(rgmii_rxctl),
	.rxclk_x2(rxclk_x2),
	.rxclk(rxclk),
	.rxd(rxd),
	.rxdv(rxdv),
	.rxer(rxer),
	.crs(crs)
);

rgmii_tx #(.MODE(TX_MODE)) tx_i(
	.reset(reset),
	.speed(speed),
	.txclk_x2(txclk_x2),
	.txclk(txclk),
	.txd(txd),
	.txen(txen),
	.txer(txer),
	.rgmii_gtxclk(rgmii_gtxclk),
	.rgmii_txdat(rgmii_txdat),
	.rgmii_txctl(rgmii_txctl)
);

// see RGMII v2.0 standard
assign col = txen && (crs || rxdv);

// emulate a link status interrupt from IBS
wire [3:0] ibs_new = {ibs_dplx, ibs_spd, ibs_up};
reg [3:0] ibs_prev;
always @(posedge rxclk)
begin
    ibs_prev <= ibs_new;
end
assign interrupt = ibs_new != ibs_prev;

endmodule
