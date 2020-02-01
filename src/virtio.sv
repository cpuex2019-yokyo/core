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
   
   wire [31:0]                  magic_value = 32'h74726976; // 0x00
   wire [31:0]                  version = 32'h01; // 0x04
   wire [31:0]                  device_id = 32'h02; // 0x08
   wire [31:0]                  vendor_id = 32'h554d4551; // 0x0c
   wire [31:0]                  host_features; // 0x10
   reg [31:0]                   host_features_sel; // 0x14
   reg [31:0]                   guest_features; // 0x20
   reg [31:0]                   guest_features_sel; // 0x24
   reg [31:0]                   guest_page_size; //0x28
   reg [31:0]                   queue_sel; //0x30
   wire [31:0]                  queue_num_max; //0x34
   reg [31:0]                   queue_num; //0x38
   reg [31:0]                   queue_align; //0x3c
   reg [31:0]                   queue_pfn; // 0x40

   // TODO: although xv6 uses legacy interface and the interface does not include QueueReady register in the MMIO model, xv6 has a macro for QueueReady.
   // It is not used in xv6, but I do not know whether it is in Linux.
   // So I have to inspect Linux src further more...
   reg [31:0]                   queue_ready; // 0x44
   
   reg [31:0]                   queue_notify; // 0x50
   wire [31:0]                  interrupt_status; // 0x60
   reg [31:0]                   interrupt_ack; //0x64
   // This register does not follow the naming convention of virtio spec.
   // This is because "state" is too ambigious ...  there are a lot of states!
   reg [31:0]                   device_status; //0x70

   enum reg [3:0]               {WAITING_QUERY, WAITING_RREADY, WAITING_BREADY} interface_state;
   enum reg [5:0]               { HOGE, FOOBAR } controller_state;   

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

   function read_reg(input [31:0] addr);
      begin
         case(addr)
           32'h00: read_reg = magic_value;
           32'h04: read_reg = version;
           32'h08: read_reg = device_id;
           32'h0c: read_reg = vendor_id;
           32'h10: read_reg = host_features;
           32'h14: read_reg = host_features_sel;
           32'h35: read_reg = queue_num_max;           
           32'h40: read_reg = queue_pfn;
           32'h70: read_reg = device_status;           
         endcase            
      end
   endfunction

   task write_reg(input [31:0] addr, input [31:0] data);
      begin
         case(addr)
           32'h14: host_features_sel <= data;
           32'h20: guest_features <= data;
           32'h24: guest_features_sel <= data;
           32'h28: guest_page_size <= data;
           32'h30: queue_sel <= data;
           32'h38: queue_num <= data;
           32'h3c: queue_align <= data;
           32'h40: queue_pfm <= data;
           32'h50: queue_notify <= data; // TODO: invoke the FSM
           32'h64: interrupt_ack <= data;
           32'h70: device_status <= data;           
         endcase
      end
   endtask

   reg [31:0] _addr;
   reg [31:0] _data;   
   reg [3:0]  _wstrb;
   
   // this module assumes that only CPU access to this controller.
   always @(posedge clk) begin
	  if(rstn) begin
         if (interface_state == WAITING_QUERY) begin
            if(axi_arvalid) begin
               axi_arready <= 0;
               
               interface_state <= WAITING_RREADY;               
               axi_rvalid <= 1;
               axi_rdata <= read_reg(axi_araddr);               
            end else if (axi_awvalid) begin
               axi_awready <= 0;
               
               _addr <= axi_awaddr;               
            end else if (axi_wvalid) begin
               axi_wready <= 0;
               
               _addr <= axi_wdata;
               _wstrb <= axi_wstrb;               
            end else if (!axi_awready && !axi_wready) begin
               interface_state <= WAITING_BREADY;

               write_reg(_addr, _data);
               axi_bvalid <= 1;
               axi_bresp <= 2'b0;               
            end
         end else if (interface_state == WAITING_RREADY) begin
            if(axi_rready) begin
               axi_arready <= 1;
               
               interface_state <= WAITING_QUERY;        
               axi_rvalid <= 0;
            end        
         end else if (interface_state == WAITING_BREADY) begin
            if (axi_bready) begin
               axi_awready <= 1;
               
               state <= WAITING_QUERY;               
               axi_wready <= 1;
            end       
         end
	  end else begin
         init();         
      end
   end

   always @(posedge clk) begin
   end
   
endmodule

`default_nettype wire
