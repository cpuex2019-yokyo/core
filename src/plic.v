`default_nettype none

module plic(
	        input wire [31:0] axi_araddr,
	        output reg        axi_arready,
	        input wire        axi_arvalid,
	        input wire [2:0]  axi_arprot, // ignored

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
	        input wire [2:0]  axi_awprot, // ignored

	        input wire [31:0] axi_wdata,
	        output reg        axi_wready,
	        input wire [3:0]  axi_wstrb,
	        input wire        axi_wvalid,

	        input wire        virtio_intr,
	        input wire        uart_intr,

            input wire [1:0]  cpu_mode,

            // S-mode external interrupt
	        output wire       external_intr_s,

            // M-mode external interrupt
	        output wire       external_intr_m,

	        input wire        clk,
	        input wire        rstn
            );

   localparam virtio_priority_addr = 32'h4;	// virtio : 1
   localparam uart_priority_addr = 32'h28; // uart   : 10   
   localparam pending_addr = 32'h1000; // Read Only
   
   localparam senable_addr = 32'h2080;
   localparam spriority_threshold_addr = 32'h201000;
   localparam sclaim_scomplete_addr = 32'h201004;

   localparam menable_addr = 32'h2000;
   localparam mpriority_threshold_addr = 32'h200000;
   localparam mclaim_mcomplete_addr = 32'h200004;
   
   // general configuration
   reg [2:0]                  virtio_priority, uart_priority;   
   reg                        virtio_pending, uart_pending; // TODO: should pending bit be different between s-mode intr and m-mode one?

   // registers for S-mode
   reg                        virtio_senable, uart_senable;
   reg [2:0]                  spriority_threshold;
   wire [31:0]                sclaim;
   wire                       virtio_sactive, uart_sactive;
   
   assign virtio_sactive = virtio_pending && virtio_priority > priority_threshold && cpu_mode <= 2'b01; 
   assign uart_sactive = uart_pending && uart_priority > priority_threshold && cpu_mode <= 2'b01; 
   assign sclaim = virtio_sactive && (~uart_sactive || virtio_priority >= uart_priority) ? 32'd1 : uart_sactive ? 32'd10 : 32'd0;
   assign external_intr_s = sclaim != 32'd0;

   // registers for M-mode
   reg                        virtio_menable, uart_menable;
   reg [2:0]                  mpriority_threshold;
   wire [31:0]                mclaim;
   wire                       virtio_mactive, uart_mactive;
   
   assign virtio_mactive = virtio_pending && virtio_priority > priority_threshold;
   assign uart_mactive = uart_pending && uart_priority > priority_threshold;
   assign mclaim = virtio_mactive && (~uart_mactive || virtio_priority >= uart_priority) ? 32'd1 : uart_mactive ? 32'd10 : 32'd0;
   assign external_intr_m = mclaim != 32'd0;
   
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
		 
		 priority_threshold <= 3'b0;
		 virtio_pending <= 1'b0;
		 uart_pending <= 1'b0;
		 virtio_priority <= 3'b0;
		 uart_priority <= 3'b0;
         
		 virtio_senable <= 1'b0;
		 uart_senable <= 1'b0;
         
		 virtio_menable <= 1'b0;
		 uart_menable <= 1'b0;         
	  end else begin
		 if(axi_arvalid) begin
			axi_rvalid <= 1'b1;
			axi_rresp <= 2'b00;
            axi_rdata <= axi_araddr == virtio_priority_addr? {29'h0, virtio_priority}:
                         axi_araddr == uart_priority_addr: {29'h0, uart_priority}:
                         axi_araddr == pending_addr? {21'h0, uart_pending, 8'h0, virtio_pending, 1'b0}:
                         // for S-mode
                         axi_araddr == senable_addr? {21'h0, uart_senable, 8'h0, virtio_senable, 1'b0}:
                         axi_araddr == spriority_threshold_addr? {29'h0, spriority_threshold}:
                         axi_araddr == sclaim_scomplete_addr? sclaim:
                         // for M-mode
                         axi_araddr == menable_addr? {21'h0, uart_menable, 8'h0, virtio_menable, 1'b0}:
                         axi_araddr == mpriority_threshold_addr? {29'h0, mpriority_threshold}:
                         axi_araddr == mclaim_mcomplete_addr? mclaim:
                         32'b0;
            // TODO: axi_rresp
		 end
		 if(axi_rready && axi_rvalid) begin
			axi_rvalid <= 1'b0;
		 end
		 if(axi_awvalid && axi_wvalid) begin
			axi_bvalid <= 1'b1;
			axi_bresp <= 2'b00;
			if(axi_awaddr == virtio_priority_addr) begin // general
			   virtio_priority <= axi_wdata[2:0];
			end else if(axi_awaddr == uart_priority_addr) begin
			   uart_priority <= axi_wdata[2:0];
			end else if(axi_awaddr == senable_addr) begin // for S-mode
			   virtio_senable <= axi_wdata[1];
			   uart_senable <= axi_wdata[10];
			end else if(axi_awaddr == spriority_threshold_addr) begin
			   spriority_threshold <= axi_wdata;
			end else if(axi_awaddr == sclaim_scomplete_addr) begin
			   if(axi_wdata == 32'd1) begin
				  virtio_pending <= 1'b0;
			   end else if(axi_wdata == 32'd10) begin
				  uart_pending <= 1'b0;
			   end
			end else if(axi_awaddr == menable_addr) begin // for M-mode
			   virtio_menable <= axi_wdata[1];
			   uart_menable <= axi_wdata[10];
			end else if(axi_awaddr == mpriority_threshold_addr) begin
			   mpriority_threshold <= axi_wdata;
			end else if(axi_awaddr == mclaim_mcomplete_addr) begin
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

         // TODO: should pending bit be different between s-mode intr and m-mode one?
		 if(virtio_intr && (virtio_menable|virtio_senable)) begin
			virtio_pending <= 1'b1;
		 end
		 if(uart_intr && (uart_menable|uart_senable)) begin
			uart_pending <= 1'b1;
		 end
	  end
   end
endmodule

`default_nettype wire
