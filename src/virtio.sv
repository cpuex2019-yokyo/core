`default_nettype none

module virtio(
              // bus for core
	          input wire [31:0] core_araddr,
	          output reg        core_arready,
	          input wire        core_arvalid,
	          input wire [2:0]  core_arprot,

	          output reg [31:0] core_rdata,
	          input wire        core_rready,
	          output reg [1:0]  core_rresp,
	          output reg        core_rvalid,

	          input wire        core_bready,
	          output reg [1:0]  core_bresp,
	          output reg        core_bvalid,

	          input wire [31:0] core_awaddr,
	          output reg        core_awready,
	          input wire        core_awvalid,
	          input wire [2:0]  core_awprot,

	          input wire [31:0] core_wdata,
	          output reg        core_wready,
	          input wire [3:0]  core_wstrb,
	          input wire        core_wvalid,

              // bus
              output reg        request_enable,
              output reg        mode,
              output reg [31:0] addr,
              output reg [31:0] wdata,
              output reg [3:0]  wstrb, 
              input wire        response_enable,
              input wire [31:0] data,

              // general
	          input wire        clk,
	          input wire        rstn,

              output reg       virtio_interrupt
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
   // NOTE: This register does not follow the naming convention of virtio spec.
   // This is because "state" is too ambigious ...  there are a lot of states!
   reg [31:0]                   device_status; //0x70

   enum reg [3:0]               {
                                 WAITING_QUERY, 
                                 WAITING_RREADY, 
                                 WAITING_BREADY
                                 } interface_state;
   
   enum reg [5:0]               {
                                 WAITING_NOTIFICATION, 
                                 COLLECT_DESCRIPTOR,
                                 WAITING_DISC,
                                 RAISE_IRQ                                 
                                 } controller_state;

   enum reg [5:0]               {
                                 
                                 } collecting_state;
   


   task init;
      begin
		 core_arready <= 1'b1;         
		 core_rdata <= 32'h0;
		 core_rresp <= 2'b00;
		 core_rvalid <= 1'b0;         
		 core_bresp <= 2'b00;
		 core_bvalid <= 1'b0;         
		 core_awready <= 1'b1;         
		 core_wready <= 1'b1;

         request_enable <= 1'b0;
         mode <= 1'b0;
         addr <= 32'b0;
         wdata <= 32'b0;
         wstrb <= 4'b0;         

         virtio_interrupt <= 1'b0;         
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
           32'h40: queue_pfn <= data;
           32'h50: begin
              queue_notify <= data;
              controller_state <= COLLECT_DESCRIPTOR;
              
           end
           32'h64: interrupt_ack <= data;
           32'h70: device_status <= data;           
         endcase
      end
   endtask

   reg [31:0] _addr;
   reg [31:0] _data;   
   reg [3:0]  _wstrb;

   wire [31:0] desc_head = {queue_pfn[19:0], 12'b0};
   wire [31:0] avail_head = {queue_pfn[19:0], 12'b0} + {queue_num[27:0], 4'b0};
   wire [31:0] used_head = avail_head + (QUEUE_ALIGN - avail_head[11:0]);   
   
   // this module assumes that only CPU access to this controller.
   always @(posedge clk) begin
	  if(rstn) begin
         if (interface_state == WAITING_QUERY) begin
            if(core_arvalid) begin
               core_arready <= 0;
               
               interface_state <= WAITING_RREADY;               
               core_rvalid <= 1;
               core_rdata <= read_reg(core_araddr);               
            end else if (core_awvalid) begin
               core_awready <= 0;
               
               _addr <= core_awaddr;               
            end else if (core_wvalid) begin
               core_wready <= 0;
               
               _addr <= core_wdata;
               _wstrb <= core_wstrb;               
            end else if (!core_awready && !core_wready) begin
               interface_state <= WAITING_BREADY;

               write_reg(_addr, _data);
               core_bvalid <= 1;
               core_bresp <= 2'b0;               
            end
         end else if (interface_state == WAITING_RREADY) begin
            if(core_rready) begin
               core_arready <= 1;
               
               interface_state <= WAITING_QUERY;        
               core_rvalid <= 0;
            end        
         end else if (interface_state == WAITING_BREADY) begin
            if (core_bready) begin
               core_awready <= 1;
               
               state <= WAITING_QUERY;               
               core_wready <= 1;
            end       
         end
	  end else begin
         init();         
      end
   end

   always @(posedge clk) begin
      if(rstn) begin
         if(controller_state == WAITING_NOTIFICATION) begin
            // Do nothing.
         end else if (controller_state == COLLECT_DESCRIPTOR) begin
         end else if (controller_state == RAISE_IRQ) begin
            controller_state <= WAITING_NOTIFICATION;            
         end
      end
   end
   
endmodule

`default_nettype wire
