`default_nettype none

module clint(
	input wire [31:0] axi_araddr,
	output reg        axi_arready,
	input wire        axi_arvalid,
	input wire [2:0]  axi_arprot,	// ignored

	output reg [31:0] axi_rdata,
	input wire        axi_rready,
	output reg [1:0]  axi_rresp,
	output reg        axi_rvalid,

	input wire        axi_bready,
	output reg [1:0]  axi_bresp,
	output reg        axi_bvalid,

	input wire [31:0] axi_awaddr,
	output reg        axi_awready,
	input wire        axi_awvalid,
	input wire [2:0]  axi_awprot,	// ignored

	input wire [31:0] axi_wdata,
	output reg        axi_wready,
	input wire [3:0]  axi_wstrb,
	input wire        axi_wvalid,

	output reg [63:0] mtime,
	output reg msip,
	output reg mtip,

	input wire clk,
	input wire rstn
);

	localparam msip_addr = 32'h0;
	localparam mtimecmp_addr = 32'h4000;
	localparam mtime_addr = 32'hbff8;		// Read Only

	reg [63:0] mtimecmp;
	reg mtip_enable;

	always @(posedge clk) begin
		if(~rstn) begin
			axi_arready <= 1'b1;
			axi_rdata <= 32'h0;
			axi_rresp <= 2'b00;
			axi_rvalid <= 1'b0;
			axi_bresp <= 2'b00;
			axi_bvalid <= 1'b0;
			axi_awready <= 1'b1;
			axi_wready <= 1'b1;
			mtip_enable <= 1'b1;
			mtip <= 1'b0;
			msip <= 1'b0;
			mtime <= 64'h0;
		end else begin
			mtime <= mtime + 64'h1;
			mtip <= 1'b0;
			if(mtime + 64'h1 >= mtimecmp) begin
				mtip <= mtip_enable;
				mtip_enable <= 1'b0;
			end

			if(axi_arvalid) begin
				axi_rvalid <= 1'b1;
				axi_rresp <= 2'b00;
				if(axi_araddr == msip_addr) begin
					axi_rdata <= {31'h0, msip};
				end else if(axi_araddr == mtimecmp_addr) begin
					axi_rdata <= mtimecmp[31:0];
				end else if(axi_araddr == mtimecmp_addr + 32'h4) begin
					axi_rdata <= mtimecmp[63:32];
				end else if(axi_araddr == mtime_addr) begin
					axi_rdata <= mtime[31:0];
				end else if(axi_araddr == mtime_addr + 32'h4) begin
					axi_rdata <= mtime[63:32];
				end else begin
					axi_rresp <= 2'b10;
				end
			end
			if(axi_rready && axi_rvalid) begin
				axi_rvalid <= 1'b0;
			end
			if(axi_awvalid && axi_wvalid) begin
				axi_bvalid <= 1'b1;
				axi_bresp <= 2'b00;
				if(axi_awaddr == msip_addr) begin
					if(axi_wstrb[0]) msip <= axi_wdata[0];
				end else if(axi_awaddr == mtimecmp_addr) begin
					if(axi_wstrb[0]) mtimecmp[7:0] <= axi_wdata[7:0];
					if(axi_wstrb[1]) mtimecmp[15:8] <= axi_wdata[15:8];
					if(axi_wstrb[2]) mtimecmp[23:16] <= axi_wdata[23:16];
					if(axi_wstrb[3]) mtimecmp[31:24] <= axi_wdata[31:24];
					mtip_enable <= 1'b1;
				end else if(axi_awaddr == mtimecmp_addr + 32'h4) begin
					if(axi_wstrb[0]) mtimecmp[39:32] <= axi_wdata[7:0];
					if(axi_wstrb[1]) mtimecmp[47:40] <= axi_wdata[15:8];
					if(axi_wstrb[2]) mtimecmp[55:48] <= axi_wdata[23:16];
					if(axi_wstrb[3]) mtimecmp[63:56] <= axi_wdata[31:24];
					mtip_enable <= 1'b1;
				end else begin
					axi_bresp <= 2'b10;
				end
			end
			if(axi_bready && axi_bvalid) begin
				axi_bvalid <= 1'b0;
			end
		end
	end
endmodule

`default_nettype wire