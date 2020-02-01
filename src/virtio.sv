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
   endtask // init
   
   wire [31:0] magic_valuee = 32'h74726976; // 0x00
   wire [31:0] version = 32'h01; // 0x04
   wire [31:0] device_id = 32'h02; // 0x08
   wire [31:0] vendor_id = 32'h554d4551; // 0x0c
   reg [31:0]  host_features; // 0x10
   reg [31:0]  host_features_sel; // 0x14
   reg [31:0]  guest_features; // 0x20
   reg [31:0]  guest_features_sel; // 0x24
   reg [31:0]  guest_page_size; //0x28
   reg [31:0]  queue_sel; //0x30
   reg [31:0]  queue_num_max; //0x34
   reg [31:0]  queue_num; //0x38
   reg [31:0]  queue_align; //0x3c
   reg [31:0]  queue_pfn; // 0x40
   
   reg [31:0]  queue_ready; // 0x44
   
   reg [31:0]  queue_notify; // 0x50
   reg [31:0]  interrupt_status; // 0x60
   reg [31:0]  interrupt_ack; //0x64
   reg [31:0]  status; //0x70

   enum reg [5:0] { HOGE, FOOBAR } state;   

   always @(posedge clk) begin
	  if(rstn) begin
         // logic
	  end else begin
         init();         
      end
   end
endmodule

`default_nettype wire
