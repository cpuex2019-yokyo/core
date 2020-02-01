`default_nettype none

module plic(
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

	input wire virtio_intr,
	input wire uart_intr,
	output wire external_intr,

	input wire clk,
	input wire rstn
);

	localparam virtio_priority_addr = 32'h4;	// virtio : 1
	localparam uart_priority_addr = 32'h28;		// uart   : 10
	localparam pending_addr = 32'h1000;			// Read Only
	localparam enable_addr = 32'h2000;
	localparam priority_threshold_addr = 32'h200000;
	localparam claim_complete_addr = 32'h200000;

	reg [2:0] virtio_priority, uart_priority;
	reg virtio_pending, uart_pending;
	reg virtio_enable, uart_enable;
	reg [2:0] priority_threshold;
	wire [31:0] claim;
	wire virtio_active, uart_active;
	
	assign virtio_active = virtio_pending && virtio_priority > priority_threshold;
	assign uart_active = uart_pending && uart_priority > priority_threshold;
	assign claim = virtio_active && (~uart_active || virtio_priority >= uart_priority) ? 32'd1 : uart_active ? 32'd10 : 32'd0;
	assign external_intr = claim != 32'd0;

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
			virtio_pending <= 1'b0;
			uart_pending <= 1'b0;
		end else begin
			if(axi_arvalid) begin
				axi_rvalid <= 1'b1;
				axi_rresp <= 2'b00;
				if(axi_araddr == virtio_priority_addr) begin
					axi_rdata <= {29'h0, virtio_priority};
				end else if(axi_araddr == uart_priority_addr) begin
					axi_rdata <= {29'h0, uart_priority};
				end else if(axi_araddr == pending_addr) begin
					axi_rdata <= {21'h0, uart_pending, 8'h0, virtio_pending, 1'b0};
				end else if(axi_araddr == enable_addr) begin
					axi_rdata <= {21'h0, uart_enable, 8'h0, virtio_enable, 1'b0};
				end else if(axi_araddr == priority_threshold_addr) begin
					axi_rdata <= {29'h0, priority_threshold};
				end else if(axi_araddr == claim_complete_addr) begin
					axi_rdata <= claim;
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
				if(axi_awaddr == virtio_priority_addr) begin
					virtio_priority <= axi_wdata[2:0];
				end else if(axi_awaddr == uart_priority_addr) begin
					uart_priority <= axi_wdata[2:0];
				end else if(axi_araddr == enable_addr) begin
					virtio_enable <= axi_wdata[1];
					uart_enable <= axi_wdata[10];
				end else if(axi_awaddr == priority_threshold_addr) begin
					priority_threshold <= axi_wdata;
				end else if(axi_awaddr == claim_complete_addr) begin
					if(axi_wdata == 32'd1) begin
						virtio_pending <= 1'b0;
					end else if(axi_wdata == 32'd10) begin
						uart_pending <= 1'b0;
					end
				end else begin
					axi_bresp <= 2'b10;
				end
			end
			if(axi_bready && axi_bvalid) begin
				axi_bvalid <= 1'b0;
			end

			if(virtio_intr && virtio_enable) begin
				virtio_pending <= 1'b1;
			end
			if(uart_intr && uart_enable) begin
				uart_pending <= 1'b1;
			end
		end
	end
endmodule

`default_nettype wire