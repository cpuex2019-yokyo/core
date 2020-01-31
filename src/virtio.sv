`default_nettype none

module virtio(
	          input wire [31:0] axi_araddr,
	          output reg        axi_arready,
	          input wire        axi_arvalid,
	          input wire [2:0]  axi_arprot,

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
	          input wire [2:0]  axi_awprot,

	          input wire [31:0] axi_wdata,
	          output reg        axi_wready,
	          input wire [3:0]  axi_wstrb,
	          input wire        axi_wvalid,

	          input wire        clk,
	          input wire        rstn
              );
   task init;
      begin
		 axi_arready <= 1'b1;
		 axi_rdata <= 32'h0;
		 axi_rresp <= 2'b00;
		 axi_rvalid <= 1'b0;
		 axi_bresp <= 2'b00;
		 axi_bvalid <= 1'b0;
		 axi_awready <= 1'b1;
		 axi_wready <= 1'b1;         
      end
   endtask      

   always @(posedge clk) begin
	  if(rstn) begin
         // logic
	  end else begin
         init();         
      end
   end
endmodule

`default_nettype wire
