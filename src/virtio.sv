`default_nettype none
`include "def.sv"
`include "virtio_params.sv"

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
              output reg        mem_request_enable,
              output reg        mem_mode,
              output reg [31:0] mem_addr,
              output reg [31:0] mem_wdata,
              output reg [3:0]  mem_wstrb, 
              input wire        mem_response_enable,
              input wire [31:0] mem_data,

              // general
	          input wire        clk,
	          input wire        rstn,

              output reg        virtio_interrupt
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
                                 START_TO_HANDLE,
                                 WAITING_MEM_AVAIL_IDX,
                                 WAITING_MEM_AVAIL_IDX,
                                 LOAD_FIRST_DESC,
                                 HANDLE_FIRST_DESC,
                                 LOAD_SECOND_DESC,
                                 HANDLE_SECOND_DESC,
                                 LOAD_THIRD_DESC,
                                 HANDLE_THIRD_DESC,

                                 // TODO: add appropriate states for disk controlling
                                 CONTROL_DISK,
   
                                 RAISE_IRQ                                 
                                 } controller_state;

   reg                          controller_notified;
   
   task init_interface;
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

         controller_notified <= 1'b0;        
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
           32'h50: queue_notify <= data;
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
               controller_notified <= (_addr == 32'h50);
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
               core_wready <= 1;
               
               interface_state <= WAITING_QUERY;
               controller_notified <= 1'b0;               
               core_bvalid <= 1'b0;               
            end       
         end
	  end else begin
         init_interface();         
      end
   end


   // avail idx cache
   reg [31:0] avail_idx;
   reg [31:0] used_idx;

   // given virtqueue 
   wire [31:0] desc_head = {queue_pfn[19:0], 12'b0};
   wire [31:0] avail_head = {queue_pfn[19:0], 12'b0} + {queue_num[27:0], 4'b0};
   wire [31:0] used_head = avail_head + (QUEUE_ALIGN - avail_head[11:0]);

   // current descriptor head
   wire [31:0] desc_base <= desc_head + 16 * ((used_idx-1) mod queue_num);

   // loaded data
   VRingDesc desc;   
   OutHDR outhdr;   
   reg [31:0] buffer_addr;   
   reg [31:0] status_addr;
   
   // on descriptor
   ///////////////////////
   
   reg [3:0] load_outhdr_microstate;
   task load_desc(input [5:0] callback_state);
      begin
         if (load_desc_microstate == 0) begin
            load_desc_microstate <= 1;            
            desc.addr[63:32] <= 32'b0;
            mem_request_enable <= 1;
            mem_mode <= MEMREQ_READ;                  
            mem_addr <= desc_base + 4;
         end else if (load_desc_microstate == 1) begin
            if (mem_response_enable) begin
               load_desc_microstate <= 2;
               desc.addr[31:0] <= mem_data;               
               mem_request_enable <= 1;
               mem_mode <= MEMREQ_MODE;
               mem_addr <= desc_base + 8;               
            end else begin
               mem_request_enable <= 0;            
            end
         end else if (microstate == 2) begin
            if (mem_response_enable) begin
               load_desc_microstate <= 3;
               desc.len <= mem_data;               
               mem_request_enable <= 1;
               mem_mode <= MEMREQ_MODE;
               mem_addr <= desc_base + 12;               
            end else begin
               mem_request_enable <= 0;            
            end
         end else if (microstate == 3) begin
            if (mem_response_enable) begin
               load_desc_microstate <= 0;
               desc.flags <= mem_data[31:16];
               desc.next <= mem_data[15:0];               
               controller_state <= callback_state;               
            end else begin
               mem_request_enable <= 0;            
            end
         end
      end
   endtask  

   // on outhdr
   ///////////////////////
   
   reg [3:0]   load_desc_microstate;
   task load_outhdr;            
      begin
         if (load_outhdr_microstate == 0) begin
            load_outhdr_microstate <= 1;
            outhdr.reserved <= 32'b0;            
            mem_request_enable <= 1;
            mem_mode <= MEMREQ_READ;                  
            mem_addr <= desc.addr[31:0];            
         end else if (load_outhdr_microstate == 1) begin
            if (mem_response_enable) begin
               load_outhdr_microstate <= 2;
               outhdr.btype[31:0] <= mem_data;               
               mem_request_enable <= 1;
               mem_mode <= MEMREQ_MODE;
               mem_addr <= desc.addr[31:0] + 8;
            end else begin
               mem_request_enable <= 0;            
            end
         end else if (load_outhdr_microstate == 2) begin
            if (mem_response_enable) begin
               load_outhdr_microstate <= 3;
               outhdr.sector[63:32] <= mem_data;               
               mem_request_enable <= 1;
               mem_mode <= MEMREQ_MODE;
               mem_addr <= desc.addr[31:0] + 12;
            end else begin
               mem_request_enable <= 0;            
            end
         end else if (load_outhdr_microstate == 2) begin
            if (mem_response_enable) begin
               load_outhdr_microstate <= 0;
               controller_state <= LOAD_SECOND_DESC;               
               outhdr.sector[31:0] <= mem_data;               
            end else begin
               mem_request_enable <= 0;            
            end
         end
      end
   endtask
   
   task init_controller;
      begin
         avail_idx <= 32'h0;         
         used_idx <= 32'h0;
         load_desc_microstate <= 0;         
         virtio_interrupt <= 1'b0;         
      end
   endtask

   
   always @(posedge clk) begin
      if(rstn) begin
         if(controller_state == WAITING_NOTIFICATION) begin
            virtio_interrupt <= 1'b0;            
            if(controller_notified) begin
               controller_state <= START_TO_HANDLE;
            end
         end else if (controller_state == START_TO_HANDLE) begin
            mem_request_enable <= 1;
            // *(avail_head + 2)            
            mem_mode <= MEMREQ_READ;            
            mem_addr <= {avail_head[31:4], 4'd2}; 
            
            controller_state <= WAITING_MEM_AVAIL_IDX;            
         end else if (controller_state == WAITING_MEM_AVAIL_IDX) begin
            request_enable <= 0;
            if (mem_response_enable) begin
               avail_idx <= mem_data;
               if (used_idx != avail_idx) begin
                  used_idx <= used_idx + 1;
                  controller_state <= LOAD_FIRST_DESC;                  
               end else begin
                  controller_state <= RAISE_IRQ;                  
               end
            end
         end else if (controller_state == LOAD_FIRST_DESC) begin
            load_desc(HANDLE_FIRST_DESC);
         end else if (controller_state == HANDLE_FIRST_DESC) begin
            load_outhdr();            
         end else if (controller_state == LOAD_SECOND_DESC) begin
            load_desc(HANDLE_SECOND_DESC);
         end else if (controller_state == HANDLE_SECOND_DESC) begin
            buffer_addr <= desc.addr[31:0];
            controller_state <= LOAD_THIRD_DESC;            
         end else if (controller_state == LOAD_THIRD_DESC) begin
            load_desc(HANDLE_THIRD_DESC);
         end else if (controller_state == HANDLE_THIRD_DESC) begin
            status_addr <= desc.addr[31:0];            
            controller_state <= CONTROL_DISK;
         end else if (controller_state == CONTROL_DISK) begin
            // TODO: we have to use AXI Quad SPI or something like that!
            // when completed, controller_state <= START_TO_HANDLE should be executed (due to multiple req).
         end else if (controller_state == RAISE_IRQ) begin
            virtio_interrupt <= 1'b1;            
            controller_state <= WAITING_NOTIFICATION;            
         end
      end else begin 
         init_controller();
      end
   end
   
endmodule

`default_nettype wire
