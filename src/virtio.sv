`default_nettype none
`include "def.sv"
`include "virtio_params.sv"

module virtio(
	          input wire        clk,
	          input wire        rstn,

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

              // bus for mem
              output reg        mem_request_enable,
              output reg        mem_mode,
              output reg [31:0] mem_addr,
              output reg [31:0] mem_wdata,
              output reg [3:0]  mem_wstrb, 
              input wire        mem_response_enable,
              input wire [31:0] mem_data,

              // bus for disk
              output reg        disk_request_enable,
              output reg        disk_mode,
              output reg [31:0] disk_addr,
              output reg [31:0] disk_wdata,
              output reg [3:0]  disk_wstrb, 
              input wire        disk_response_enable,
              input wire [31:0] disk_data,

              // general
              output reg        virtio_interrupt
              );

   // registers
   // TODO: set appropriate value for those registers.
   wire [31:0]                  magic_value = 32'h74726976;
   wire [31:0]                  version = 32'h01;
   wire [31:0]                  device_id = 32'h02;
   wire [31:0]                  vendor_id = 32'h554d4551;
   wire [31:0]                  host_features = 32'h00;
   (* mark_debug = "true" *) reg [31:0]                   host_features_sel;
   (* mark_debug = "true" *) reg [31:0]                   guest_features;
   (* mark_debug = "true" *) reg [31:0]                   guest_features_sel;
   (* mark_debug = "true" *) reg [31:0]                   guest_page_size;
   (* mark_debug = "true" *) reg [31:0]                   queue_sel;
   wire [31:0]                  queue_num_max = (queue_sel == 32'b0)? 32'd8 : 32'd0;
   (* mark_debug = "true" *) reg [31:0]                   queue_num;
   (* mark_debug = "true" *) reg [31:0]                   queue_align;
   (* mark_debug = "true" *) reg [31:0]                   queue_pfn;

   // TODO: although xv6 uses legacy interface and the interface does not include QueueReady register in the MMIO model, xv6 has a macro for QueueReady.
   // It is not used in xv6, but I do not know whether it is in Linux.
   // So I have to inspect Linux src further more...
   (* mark_debug = "true" *) reg [31:0]                   queue_ready;
   
   (* mark_debug = "true" *) reg [31:0]                   queue_notify;
   wire [31:0]                  interrupt_status;
   (* mark_debug = "true" *) reg [31:0]                   interrupt_ack;
   // NOTE: This register does not follow the naming convention of virtio spec.
   // This is because "status" is too ambigious ...  there are a lot of statuses!
   (* mark_debug = "true" *) reg [31:0]                   device_status;

   (* mark_debug = "true" *) reg [31:0] _addr;
   (* mark_debug = "true" *) reg [31:0] _data;   
   (* mark_debug = "true" *) reg [3:0]  _wstrb;   
   
   // mmio interface
   ///////////////////////
      
   task init_interface;
      begin
         // mmio registers
         host_features_sel <= 32'b0;
         guest_features <= 32'b0;
         guest_features_sel <= 32'b0;
         queue_sel <= 32'b0;
         queue_num <= 32'b0;
         queue_align <= 32'b0;
         queue_pfn <= 32'b0;
         queue_ready <= 32'b0;
         queue_notify <= 32'b0;
         interrupt_ack <= 32'b0;
         device_status <= 32'b0;
         
         // axi backup
         _addr <= 32'b0;
         _data <= 32'b0;
         _wstrb <= 4'b0;                       

         // axi interface
		 core_arready <= 1'b1;
         
		 core_rdata <= 32'h0;
		 core_rresp <= 2'b00;
		 core_rvalid <= 1'b0;
         
		 core_bresp <= 2'b00;
		 core_bvalid <= 1'b0;
         
		 core_awready <= 1'b1;
         
		 core_wready <= 1'b1;

         // connection to controller
         controller_notified <= 1'b0;        
      end
   endtask

   function [31:0] read_reg(input [31:0] addr);
      begin
         case(addr)
           32'h00: read_reg = magic_value;
           32'h04: read_reg = version;
           32'h08: read_reg = device_id;
           32'h0c: read_reg = vendor_id;
           32'h10: read_reg = host_features;
           32'h14: read_reg = host_features_sel;
           32'h34: read_reg = queue_num_max;           
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
   
   always @(posedge clk) begin
	  if(rstn) begin
         if (core_arready && core_arvalid) begin
            core_arready <= 1'b0;
            
            core_rvalid <= 1'b1;
            core_rdata <= read_reg(core_araddr);
            core_rresp <= 2'b0;            
         end

         if (core_rvalid && core_rready) begin
            core_rvalid <= 1'b0;
            core_arready <= 1'b1;            
         end
         
         if (core_awready && core_awvalid) begin
            core_awready <= 1'b0;
            
            _addr <= core_awaddr;               
         end
         
         if (core_wready && core_wvalid) begin
            core_wready <= 1'b0;
            
            _data <= core_wdata;
            _wstrb <= core_wstrb;               
         end
         
         if (!core_awready && !core_wready) begin
            write_reg(_addr, _data);
            // NOTE: is it okay?
            controller_notified <= (_addr == 32'h50);
            core_bvalid <= 1;
            core_bresp <= 2'b0;               
         end else begin
            controller_notified <= 1'b0;                           
         end

         if (core_bvalid && core_bready) begin
            core_bvalid <= 1'b0;

            core_awready <= 1'b1;            
            core_wready <= 1'b1;            
         end      
	  end else begin
         init_interface();         
      end
   end

   
   // disk controller
   ///////////////////////
   //    
   typedef enum reg [5:0]       {
                                 // waiting state
                                 WAITING_NOTIFICATION,

                                 // main loop
                                 START_TO_HANDLE,
                                 WAITING_MEM_AVAIL_IDX,
                                 LOAD_FIRST_INDEX,
                                 LOAD_FIRST_DESC,
                                 HANDLE_FIRST_DESC,
                                 LOAD_SECOND_DESC,
                                 HANDLE_SECOND_DESC,
                                 LOAD_THIRD_DESC,
                                 HANDLE_THIRD_DESC,
                                 CONTROL_DISK,   
                                 WRITE_STATUS,
                                 WRITE_USED,

                                 // final state
                                 RAISE_IRQ                                 
                                 } controller_state_t;
   (* mark_debug = "true" *) controller_state_t controller_state;
   const controller_state_t cstate_base = WAITING_NOTIFICATION;      
   (* mark_debug = "true" *) reg                          controller_notified;

   // idx cache
   (* mark_debug = "true" *) reg [15:0] avail_idx;
   (* mark_debug = "true" *) reg [15:0] used_idx;
   
   // given virtqueue 
   wire [31:0] desc_head = {queue_pfn[19:0], 12'b0};
   wire [31:0] avail_head = {queue_pfn[19:0], 12'b0} + {queue_num[27:0], 4'b0};
   wire [31:0] used_head = avail_head + (QUEUE_ALIGN - avail_head[11:0]);

   // loaded data
   VRingDesc desc;   
   OutHDR outhdr;   
   (* mark_debug = "true" *) reg [15:0]  first_idx;   
   (* mark_debug = "true" *) reg [15:0]  second_idx;   
   (* mark_debug = "true" *) reg [15:0]  third_idx;   
   (* mark_debug = "true" *) reg [31:0]  buffer_addr;   
   (* mark_debug = "true" *) reg [31:0]  buffer_len;   
   (* mark_debug = "true" *) reg [31:0]  status_addr;
   
   // desc manipulation   
   (* mark_debug = "true" *) reg [3:0]   load_desc_microstate;
   task load_desc(input [31:0] desc_idx, input [5:0] callback_state);
      begin
         if (load_desc_microstate == 0) begin
            load_desc_microstate <= 1;            
            desc.addr[63:32] <= 32'b0;
            mem_request_enable <= 1;
            mem_mode <= MEMREQ_READ;                  
            mem_addr <= desc_head + 16 * (desc_idx % queue_num) + 0;
         end else if (load_desc_microstate == 1) begin
            if (mem_response_enable) begin
               load_desc_microstate <= 2;
               desc.addr[31:0] <= to_le32(mem_data);               
               mem_request_enable <= 1;
               mem_mode <= MEMREQ_READ;
               mem_addr <= desc_head + 16 * (desc_idx % queue_num) + 8;               
            end else begin
               mem_request_enable <= 0;            
            end
         end else if (load_desc_microstate == 2) begin
            if (mem_response_enable) begin
               load_desc_microstate <= 3;
               desc.len <= to_le32(mem_data);               
               mem_request_enable <= 1;
               mem_mode <= MEMREQ_READ;
               mem_addr <= desc_head + 16 * (desc_idx % queue_num) + 12;               
            end else begin
               mem_request_enable <= 0;            
            end
         end else if (load_desc_microstate == 3) begin
            if (mem_response_enable) begin
               load_desc_microstate <= 0;
               desc.flags <= to_le16(mem_data[31:16]);               
               desc.next <= to_le16(mem_data[15:0]);               
               controller_state <= cstate_base.next(callback_state);               
            end else begin
               mem_request_enable <= 0;            
            end
         end
      end
   endtask  

   // outhdr manipulation
   (* mark_debug = "true" *) reg [3:0]   load_outhdr_microstate;
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
               outhdr.btype[31:0] <= to_le32(mem_data);               
               mem_request_enable <= 1;
               mem_mode <= MEMREQ_READ;
               mem_addr <= desc.addr[31:0] + 8;
            end else begin
               mem_request_enable <= 0;            
            end
         end else if (load_outhdr_microstate == 2) begin
            if (mem_response_enable) begin
               load_outhdr_microstate <= 3;
               outhdr.sector[31:0] <= to_le32(mem_data);               
               mem_request_enable <= 1;
               mem_mode <= MEMREQ_READ;
               mem_addr <= desc.addr[31:0] + 12;
            end else begin
               mem_request_enable <= 0;            
            end
         end else if (load_outhdr_microstate == 3) begin
            if (mem_response_enable) begin
               load_outhdr_microstate <= 0;
               controller_state <= LOAD_SECOND_DESC;               
               outhdr.sector[63:32] <= to_le32(mem_data);               
            end else begin
               mem_request_enable <= 0;
            end
         end
      end
   endtask

   // actual disk control
   (* mark_debug = "true" *) enum reg [3:0] {
                                             CDISK_INIT, 
                                             CDISK_R_DISK,
                                             CDISK_R_DISK_STARTUP, 
                                             CDISK_R_MEM,
                                             CDISK_R_MEM_STARTUP,
                                             CDISK_W_DISK,
                                             CDISK_W_MEM
                                             } cdisk_microstate;   
   (* mark_debug = "true" *) reg [6:0]      cdisk_loop_index;
   (* mark_debug = "true" *) reg [31:0]     cdisk_buf [0:127];
   (* mark_debug = "true" *) reg [31:0]     wrote_size;      
   
   task load_disk(input startup);
      begin
         if (startup) begin
            cdisk_loop_index <= 0;
            disk_request_enable <= 1'b1;
            disk_mode <= MEMREQ_READ;
            disk_addr <= {outhdr.sector[22:0], 9'b0};            
         end else begin
            if (disk_response_enable) begin
               if (cdisk_loop_index == 127) begin
                  cdisk_microstate <= CDISK_W_MEM;
                  write_mem(1);                  
               end else begin
                  cdisk_buf[cdisk_loop_index] <=  to_le32(disk_data);                  
                  cdisk_loop_index <= cdisk_loop_index + 1;
                  
                  disk_request_enable <= 1'b1;
                  disk_mode <= MEMREQ_READ;
                  disk_addr <= {outhdr.sector[22:0], 9'b0} + 4 * (cdisk_loop_index+1);
               end
            end else begin
               disk_request_enable <= 1'b0;                           
            end
         end
      end
   endtask

   task write_mem(input startup);
      begin
         if (startup) begin
            cdisk_loop_index <= 0;
            mem_request_enable <= 1'b1;
            mem_mode <= MEMREQ_WRITE;
            mem_wdata <= cdisk_buf[0];
            mem_wstrb <= 4'b1111;
            mem_addr <= buffer_addr;            
         end else begin
            if (mem_response_enable) begin
               if (cdisk_loop_index == 127) begin
                  if (wrote_size + 32'd512 == buffer_len) begin
                     cdisk_microstate <= CDISK_INIT;
                     controller_state <= WRITE_STATUS;
                  end else begin
                     wrote_size <= wrote_size + 32'd512;                     
                     cdisk_microstate <= CDISK_R_DISK_STARTUP;
                     outhdr.sector <= outhdr.sector + 1;                     
                     buffer_addr <= buffer_addr + 32'd512;                     
                  end
               end else begin
                  cdisk_loop_index <= cdisk_loop_index + 1;               
                  mem_request_enable <= 1'b1;
                  mem_mode <= MEMREQ_WRITE;
                  mem_wdata <= cdisk_buf[cdisk_loop_index + 1];
                  mem_wstrb <= 4'b1111;
                  mem_addr <= buffer_addr + 4 * (cdisk_loop_index+1);
               end                  
            end else begin
               disk_request_enable <= 1'b0;                           
            end
         end
      end
   endtask
   
   task load_mem(input startup);
      begin
         if (startup) begin
            cdisk_loop_index <= 0;
            mem_request_enable <= 1'b1;
            mem_mode <= MEMREQ_READ;
            mem_addr <= buffer_addr;
         end else begin
            if (mem_response_enable) begin
               if (cdisk_loop_index == 127) begin
                  cdisk_microstate <= CDISK_W_DISK;
                  write_disk(1);                  
               end else begin
                  // TODO: endian! it should not be change data endian.
                  cdisk_buf[cdisk_loop_index] <= mem_data;                  
                  cdisk_loop_index <= cdisk_loop_index + 1;
                  
                  mem_request_enable <= 1'b1;
                  mem_mode <= MEMREQ_READ;
                  mem_addr <= buffer_addr + 4 * (cdisk_loop_index+1);
               end                  
            end else begin
               mem_request_enable <= 1'b0;                           
            end
         end
      end
   endtask

   task write_disk(input startup);
      begin
         if (startup) begin
            cdisk_loop_index <= 0;
            disk_request_enable <= 1'b1;
            disk_mode <= MEMREQ_WRITE;
            disk_wdata <= cdisk_buf[0];
            disk_wstrb <= 4'b1111;
            disk_addr <= {outhdr.sector[22:0], 9'b0};            
         end else begin
            if (disk_response_enable) begin
               if (cdisk_loop_index == 127) begin
                  if (wrote_size + 32'd512 == buffer_len) begin
                     cdisk_microstate <= CDISK_INIT;
                     controller_state <= WRITE_STATUS;                     
                  end else begin
                     wrote_size <= wrote_size + 32'd512;                     
                     cdisk_microstate <= CDISK_R_MEM_STARTUP;
                     outhdr.sector <= outhdr.sector + 1;                     
                     buffer_addr <= buffer_addr + 32'd512;                     
                  end
               end else begin
                  cdisk_loop_index <= cdisk_loop_index + 1;               
                  disk_request_enable <= 1'b1;
                  disk_mode <= MEMREQ_WRITE;
                  disk_wdata <= cdisk_buf[cdisk_loop_index + 1];
                  disk_wstrb <= 4'b1111;
                  disk_addr <= {outhdr.sector[22:0], 9'b0} + 4 * (cdisk_loop_index+1);
               end                  
            end else begin
               disk_request_enable <= 1'b0;                           
            end
         end
      end
   endtask
   
   task control_disk;
      begin
         if (cdisk_microstate == CDISK_INIT) begin
            cdisk_loop_index <= 0;            
            if (outhdr.btype == VIRTIO_BLK_T_IN) begin
               cdisk_microstate <= CDISK_R_DISK_STARTUP;
            end else begin
               cdisk_microstate <= CDISK_R_MEM_STARTUP;
            end
         end else if (cdisk_microstate == CDISK_R_DISK_STARTUP) begin
            cdisk_microstate <= CDISK_R_DISK;            
            load_disk(1);            
         end else if (cdisk_microstate == CDISK_R_DISK) begin
            load_disk(0);            
         end else if (cdisk_microstate == CDISK_R_MEM_STARTUP) begin
            cdisk_microstate <= CDISK_R_MEM;            
            load_mem(1);
         end else if (cdisk_microstate == CDISK_R_MEM) begin
            load_mem(0);            
         end else if (cdisk_microstate == CDISK_W_DISK) begin
            write_disk(0);            
         end else if (cdisk_microstate == CDISK_W_MEM) begin
            write_mem(0);            
         end
      end
   endtask

   // wstatus   
   (* mark_debug = "true" *) enum reg [3:0] {
                                             WSTATUS_INIT, 
                                             WSTATUS_WAITING
                                             } wstatus_microstate;   
   task write_status;
      begin
         if (wstatus_microstate == WSTATUS_INIT) begin
            wstatus_microstate <= WSTATUS_WAITING;
            mem_request_enable <= 1'b1;
            mem_mode <= MEMREQ_WRITE;
            mem_wdata <= 32'b0; // TODO(linux): this seems to be correct, but I haven't seen any specs...
            case (status_addr[1:0])
              2'b00: mem_wstrb <= 4'b1000;
              2'b01: mem_wstrb <= 4'b0100;
              2'b10: mem_wstrb <= 4'b0010;
              2'b11: mem_wstrb <= 4'b0001;
            endcase
            mem_addr <= {status_addr[31:2], 2'b0};
         end else if (wstatus_microstate == WSTATUS_WAITING) begin
            mem_request_enable <= 1'b0;                 
            if (mem_response_enable) begin
               controller_state <= WRITE_USED;               
               wstatus_microstate <= WSTATUS_INIT;
            end
         end
      end
   endtask
   

   
   // notify   
   (* mark_debug = "true" *) enum reg [3:0] {
                                             NOTIFY_INIT, 
                                             NOTIFY_WAITING, 
                                             NOTIFY_WAITING2, 
                                             NOTIFY_WAITING3
                                             } notify_microstate;   
   task write_used;
      begin
         if (notify_microstate == NOTIFY_INIT) begin
            notify_microstate <= NOTIFY_WAITING;
            // write to used->id
            mem_request_enable <= 1'b1;
            mem_mode <= MEMREQ_WRITE;
            mem_wdata <= {16'b0, to_le16(used_idx)};
            mem_wstrb <= 4'b0011;
            mem_addr <= used_head + 32'd0; // we'd like to sh to used_head + 32'd0
         end else if (notify_microstate == NOTIFY_WAITING) begin
            mem_request_enable <= 1'b0;                 
            if (mem_response_enable) begin
               notify_microstate <= NOTIFY_WAITING2;
               // write to used[used_idx-1].id
               mem_request_enable <= 1'b1;
               mem_mode <= MEMREQ_WRITE;
               mem_wdata <= to_le32({16'b0, first_idx});
               mem_wstrb <= 4'b1111;
               mem_addr <= used_head + 4 + 8 * (used_idx-1);
            end
         end else if (notify_microstate == NOTIFY_WAITING2) begin
            mem_request_enable <= 1'b0;                 
            if (mem_response_enable) begin
               notify_microstate <= NOTIFY_WAITING3;
               // write to used[used_idx-1].len
               mem_request_enable <= 1'b1;
               mem_mode <= MEMREQ_WRITE;
               mem_wdata <= 32'b0; // TODO(linux): set appropriate value
               mem_wstrb <= 4'b1111;
               mem_addr <= used_head + 4 + 8 * (used_idx-1) + 4;
            end
         end else if (notify_microstate == NOTIFY_WAITING3) begin
            mem_request_enable <= 1'b0;                 
            if (mem_response_enable) begin
               controller_state <= START_TO_HANDLE;               
               notify_microstate <= NOTIFY_INIT;
            end
         end
      end
   endtask

   integer i;   
   task init_cdisk_buf;
      begin
         for(i = 0; i < 128; i = i + 1) begin
            cdisk_buf[i] = 32'b0;
         end
      end
   endtask      
      
   task init_controller;
      begin
         controller_state <= WAITING_NOTIFICATION;

         // info on desc
         avail_idx <= 32'h0;         
         used_idx <= 32'h0;

         first_idx <= 16'b0;
         second_idx <= 16'b0;
         third_idx <= 16'b0;
                  
         buffer_addr <= 32'b0;
         buffer_len <= 32'b0;         
         status_addr <= 32'b0; 
         
         // buf
         init_cdisk_buf();         

         // microstates
         load_desc_microstate <= 0;
         load_outhdr_microstate <= 0;         
         cdisk_microstate <= CDISK_INIT;
         cdisk_loop_index <= 0;
         notify_microstate <= NOTIFY_INIT;
         wstatus_microstate <= WSTATUS_INIT;         

         // interrupt signal to plic
         virtio_interrupt <= 1'b0;

         // mem interface
         mem_request_enable <= 1'b0;
         mem_mode <= 1'b0;
         mem_addr <= 32'b0;
         mem_wdata <= 32'b0;
         mem_wstrb <= 4'b0;               
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
            mem_mode <= MEMREQ_READ;            
            mem_addr <= avail_head + 32'd0;  // we'd like to lh from avail_head + 32'd2
            
            controller_state <= WAITING_MEM_AVAIL_IDX;            
         end else if (controller_state == WAITING_MEM_AVAIL_IDX) begin
            if (mem_response_enable) begin
               // TODO: check for unaligned mem access
               avail_idx <= to_le16(mem_data[15:0]);
               if (used_idx != to_le16(mem_data[15:0])) begin
                  used_idx <= used_idx + 1;
                  controller_state <= LOAD_FIRST_INDEX;

                  mem_request_enable <= 1;
                  mem_mode <= MEMREQ_READ;            
                  mem_addr <= avail_head + 4 + 2 * (used_idx % queue_num);    
               end else begin
                  controller_state <= RAISE_IRQ;
               end
            end else begin
               mem_request_enable <= 0;
            end
         end else if (controller_state == LOAD_FIRST_INDEX) begin
            mem_request_enable <= 0;
            if (mem_response_enable) begin
               // TODO: check for unaligned mem access            
               first_idx <= to_le16(mem_data[31:16]);
               controller_state <= LOAD_FIRST_DESC;
            end
         end else if (controller_state == LOAD_FIRST_DESC) begin
            // this change state to HANDLE_FIRST_DESC when finished
            load_desc(first_idx, HANDLE_FIRST_DESC);
         end else if (controller_state == HANDLE_FIRST_DESC) begin
            // this change state to LOAD_SECOND_DESC when finished
            second_idx <= desc.next;            
            load_outhdr();            
         end else if (controller_state == LOAD_SECOND_DESC) begin
            // this change state to HANDLE_SECOND_DESC when finished
            load_desc(second_idx, HANDLE_SECOND_DESC);
         end else if (controller_state == HANDLE_SECOND_DESC) begin
            third_idx <= desc.next;
            buffer_len <= desc.len;            
            buffer_addr <= desc.addr[31:0];
            controller_state <= LOAD_THIRD_DESC;            
         end else if (controller_state == LOAD_THIRD_DESC) begin
            // this change state to LOAD_THIRD_DESC when finished
            load_desc(third_idx, HANDLE_THIRD_DESC);
         end else if (controller_state == HANDLE_THIRD_DESC) begin
            status_addr <= desc.addr[31:0];            
            controller_state <= CONTROL_DISK;
            wrote_size <= 32'b0;            
         end else if (controller_state == CONTROL_DISK) begin
            // this change state to WRITE_STATUS when finished
            control_disk();            
         end else if (controller_state == WRITE_STATUS) begin
            // write_status() change state to WRITE_USED when finished
            write_status();            
         end else if (controller_state == WRITE_USED) begin
            // write_used() change state to START_TO_HANDLE when finished
            write_used();            
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
