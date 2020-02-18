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
               output reg [31:0] m_spi_araddr,
               input wire        m_spi_arready,
               output reg        m_spi_arvalid,
               output reg [2:0]  m_spi_arprot,

               input wire [31:0] m_spi_rdata,
               output reg        m_spi_rready,
               input wire [1:0]  m_spi_rresp,
               input wire        m_spi_rvalid,

               output reg        m_spi_bready,
               input wire [1:0]  m_spi_bresp,
               input wire        m_spi_bvalid,

               output reg [31:0] m_spi_awaddr,
               input wire        m_spi_awready,
               output reg        m_spi_awvalid,
               output reg [2:0]  m_spi_awprot,

               output reg [31:0] m_spi_wdata,
               input wire        m_spi_wready,
               output reg [3:0]  m_spi_wstrb,
               output reg        m_spi_wvalid,

              // general
              output reg        virtio_interrupt
              );

   // TODO: set appropriate value for those registers.
   wire [31:0]                  magic_value = 32'h74726976;
   wire [31:0]                  version = 32'h01;
   wire [31:0]                  device_id = 32'h02;
   wire [31:0]                  vendor_id = 32'h554d4551;
   wire [31:0]                  host_features = 32'h00;
   reg [31:0]                   host_features_sel;
   reg [31:0]                   guest_features;
   reg [31:0]                   guest_features_sel;
   reg [31:0]                   guest_page_size;
   reg [31:0]                   queue_sel;
   wire [31:0]                  queue_num_max;
   reg [31:0]                   queue_num;
   reg [31:0]                   queue_align;
   reg [31:0]                   queue_pfn;

   // TODO: although xv6 uses legacy interface and the interface does not include QueueReady register in the MMIO model, xv6 has a macro for QueueReady.
   // It is not used in xv6, but I do not know whether it is in Linux.
   // So I have to inspect Linux src further more...
   reg [31:0]                   queue_ready;
   
   reg [31:0]                   queue_notify;
   wire [31:0]                  interrupt_status;
   reg [31:0]                   interrupt_ack;
   // NOTE: This register does not follow the naming convention of virtio spec.
   // This is because "state" is too ambigious ...  there are a lot of states!
   reg [31:0]                   device_status;

   enum reg [3:0]               {
                                 WAITING_QUERY, 
                                 WAITING_RREADY, 
                                 WAITING_BREADY
                                 } interface_state;
   
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
                                 WRITE_USED,

                                 // final state
                                 RAISE_IRQ                                 
                                 } controller_state_t;
   controller_state_t controller_state;
   const controller_state_t cstate_base = WAITING_NOTIFICATION;
   
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

         controller_notified <= 1'b0;        
      end
   endtask

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
               
               _data <= core_wdata;
               _wstrb <= core_wstrb;               
            end else if (!core_awready && !core_wready) begin
               interface_state <= WAITING_BREADY;
               // TODO: _wstrb
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


   reg [15:0] avail_idx;
   reg [15:0] used_idx;

   // given virtqueue 
   wire [31:0] desc_head = {queue_pfn[19:0], 12'b0};
   wire [31:0] avail_head = {queue_pfn[19:0], 12'b0} + {queue_num[27:0], 4'b0};
   wire [31:0] used_head = avail_head + (QUEUE_ALIGN - avail_head[11:0]);

   // loaded data
   VRingDesc desc;   
   OutHDR outhdr;   
   reg [15:0]  first_idx;   
   reg [15:0]  second_idx;   
   reg [15:0]  third_idx;   
   reg [31:0]  buffer_addr;   
   reg [31:0]  status_addr;
   
   // on descriptor
   ///////////////////////
   
   reg [3:0]   load_desc_microstate;
   task load_desc(input [31:0] desc_idx, input [5:0] callback_state);
      begin
         if (load_desc_microstate == 0) begin
            load_desc_microstate <= 1;            
            desc.addr[63:32] <= 32'b0;
            mem_request_enable <= 1;
            mem_mode <= MEMREQ_READ;                  
            mem_addr <= desc_head + 16 * (desc_idx % queue_num) + 4;
         end else if (load_desc_microstate == 1) begin
            if (mem_response_enable) begin
               load_desc_microstate <= 2;
               desc.addr[31:0] <= mem_data;               
               mem_request_enable <= 1;
               mem_mode <= MEMREQ_READ;
               mem_addr <= desc_head + 16 * (desc_idx % queue_num) + 8;               
            end else begin
               mem_request_enable <= 0;            
            end
         end else if (load_desc_microstate == 2) begin
            if (mem_response_enable) begin
               load_desc_microstate <= 3;
               desc.len <= mem_data;               
               mem_request_enable <= 1;
               mem_mode <= MEMREQ_READ;
               mem_addr <= desc_head + 16 * (desc_idx % queue_num) + 12;               
            end else begin
               mem_request_enable <= 0;            
            end
         end else if (load_desc_microstate == 3) begin
            if (mem_response_enable) begin
               load_desc_microstate <= 0;
               desc.flags <= mem_data[31:16];
               desc.next <= mem_data[15:0];               
               controller_state <= cstate_base.next(callback_state);               
            end else begin
               mem_request_enable <= 0;            
            end
         end
      end
   endtask  

   // on outhdr
   ///////////////////////
   
   reg [3:0]   load_outhdr_microstate;
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
               mem_mode <= MEMREQ_READ;
               mem_addr <= desc.addr[31:0] + 8;
            end else begin
               mem_request_enable <= 0;            
            end
         end else if (load_outhdr_microstate == 2) begin
            if (mem_response_enable) begin
               load_outhdr_microstate <= 3;
               outhdr.sector[63:32] <= mem_data;               
               mem_request_enable <= 1;
               mem_mode <= MEMREQ_READ;
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

   // disk control
   ///////////////////////
   
   enum reg [3:0] {
                   CDISK_INIT, 
                   CDISK_R_DISK, 
                   CDISK_R_MEM, 
                   CDISK_W_DISK, 
                   CDISK_W_MEM
                   } cdisk_microstate;   
   reg [6:0]      cdisk_loop_index;
   reg [31:0]     cdisk_buf [0:127];

   enum reg [3:0] {
      SPI_IDLE,
      SPI_PREPARE,
      SPI_ERASE,
      SPI_PROGRAM,
      SPI_WIP,
      SPI_READ
   } spi_mode;

   enum reg [3:0] {
      SPI_STATE_COMMAND,
      SPI_STATE_ENABLE,
      SPI_STATE_WIP,
      SPI_STATE_READ,
      SPI_STATE_DISABLE
   } spi_state;

   reg [7:0] spi_phase;
   reg [1:0] spi_rep;
   reg [1:0] spi_prepare_state;
   reg [1:0] spi_wip_state;
   reg spi_wenable;

   task spi_command();
      begin
         spi_phase <= spi_phase + 8'h1;
         if(spi_phase == 8'hf9) begin
            m_spi_awaddr <= 32'h60;
            m_spi_wdata <= 32'h1e6;
         end else if(spi_phase == 8'hfa || spi_phase == 8'hfb) begin
            m_spi_awaddr <= 32'h70;
            m_spi_wdata <= 32'h1;
         end else if(spi_phase == 8'hfc) begin
            m_spi_awaddr <= 32'h68;
            if(spi_mode == SPI_PREPARE) begin
               m_spi_wdata <= 32'h06;
               spi_state <= SPI_STATE_ENABLE;
               spi_phase <= 8'h0;
            end else if(spi_mode == SPI_ERASE) begin
               m_spi_wdata <= 32'h20;
            end else if(spi_mode == SPI_PROGRAM) begin
               m_spi_wdata <= 32'h02;
            end else if(spi_mode == SPI_WIP) begin
               m_spi_wdata <= 32'h05;
            end else if(spi_mode == SPI_READ) begin
               m_spi_wdata <= 32'h03;
            end
         end else if(spi_phase == 8'hfd) begin
            if(spi_mode == SPI_WIP) begin
               m_spi_wdata <= 32'hff;
               spi_state <= SPI_STATE_ENABLE;
               spi_phase <= 32'h0;
            end else begin
               m_spi_wdata <= {24'h0, outhdr.sector[14:7]};
            end
         end else if(spi_phase == 8'hfe) begin
            m_spi_wdata <= {24'h0, outhdr.sector[6:0], spi_rep[1]};
         end else if(spi_phase == 8'hff) begin
            m_spi_wdata <= {24'h0, spi_rep[0], 7'h0};
            if(spi_mode == SPI_ERASE) begin
               spi_state <= SPI_STATE_ENABLE;
               spi_phase <= 8'h0;
            end
         end else if(spi_phase < 8'h80) begin
            m_spi_wdata <= spi_mode == SPI_PROGRAM ? {24'h0, cdisk_buf[{spi_rep, spi_phase[6:2]}][{spi_phase[1:0], 3'h0} +: 5'h8]} : 32'hff;
            if(spi_phase == 8'h7f) begin
               spi_state <= SPI_STATE_ENABLE;
               spi_phase <= 8'h0;
               if(spi_mode == SPI_PROGRAM) spi_rep <= spi_rep + 2'h1;
            end
         end
      end
   endtask

   task spi_enable();
      begin
         if(spi_phase == 8'h0) begin
            m_spi_awaddr <= 32'h70;
            m_spi_wdata <= 32'h0;
            spi_phase <= 8'h1;
         end else if(spi_phase == 8'h1) begin
            m_spi_awaddr <= 32'h60;
            m_spi_wdata <= 32'h86;
            spi_wenable <= 1'b0;
            spi_phase <= 8'h2;
         end else if(spi_phase == 8'h2) begin
            m_spi_arvalid <= 1'b1;
            m_spi_rready <= 1'b1;
            m_spi_araddr <= 32'h20;
            spi_phase <= 8'h3;
         end else begin
            if(m_spi_rready && m_spi_rvalid && ~m_spi_rresp[1]) begin
               if(m_spi_rdata[2]) begin
                  m_spi_rready <= 1'b0;
                  spi_phase <= 8'h0;
                  if(spi_mode == SPI_WIP) begin
                     spi_state <= SPI_STATE_WIP;
                  end else if(spi_mode == SPI_READ) begin
                     spi_state <= SPI_STATE_READ;
                     spi_phase <= 8'hfc;
                     m_spi_arvalid <= 1'b1;
                     m_spi_rready <= 1'b1;
                     m_spi_araddr <= 32'h6c;
                  end else begin
                     spi_wenable <= 1'b1;
                     spi_state <= SPI_STATE_DISABLE;
                  end
               end else begin
                  m_spi_arvalid <= 1'b1;
               end
            end
         end
      end
   endtask

   task spi_disable();
      begin
         if(spi_phase == 8'h0) begin
            m_spi_awaddr <= 32'h60;
            m_spi_wdata <= 32'h1e6;
            spi_phase <= 8'h1;
         end else if(spi_phase == 8'h1) begin
            m_spi_awaddr <= 32'h70;
            m_spi_wdata <= 32'h1;
            spi_phase <= 8'h2;
         end else if(spi_phase == 8'h2) begin
            m_spi_awaddr <= 32'h20;
            m_spi_wdata <= 32'h4;
            spi_state <= SPI_STATE_COMMAND;
            spi_phase <= 8'hfc;
            if(spi_mode == SPI_PREPARE) begin
               if(spi_prepare_state == 2'h0) begin
                  spi_mode <= SPI_READ;
               end else if(spi_prepare_state == 2'h1)begin
                  spi_mode <= SPI_PREPARE;
                  spi_prepare_state <= 2'h2;
               end else if(spi_prepare_state == 2'h2)begin
                  spi_mode <= SPI_ERASE;
               end else if(spi_prepare_state == 2'h3)begin
                  spi_mode <= SPI_PROGRAM;
               end
            end else if(spi_mode == SPI_ERASE) begin
               spi_mode <= SPI_WIP;
               spi_wip_state <= 2'h2;
            end else if(spi_mode == SPI_PROGRAM) begin
               spi_mode <= SPI_WIP;
               spi_wip_state <= 2'h3;
            end else if(spi_mode == SPI_WIP) begin
               if(spi_wip_state == 2'h0) begin
                  spi_mode <= SPI_PREPARE;
                  spi_prepare_state <= 2'h3;
               end else if(spi_wip_state == 2'h1)begin
                  if(spi_rep == 2'h0) begin
                     spi_mode <= SPI_IDLE;
                     spi_wenable <= 1'b0;
                  end else begin
                     spi_mode <= SPI_PREPARE;
                     spi_prepare_state <= 2'h3;
                  end
                  cdisk_microstate <= CDISK_INIT;
                  controller_state <= WRITE_USED;
               end
            end else if(spi_mode == SPI_READ) begin
               if(spi_rep == 2'h0) begin
                  spi_mode <= SPI_IDLE;
                  spi_wenable <= 1'b0;
                  cdisk_microstate <= CDISK_W_MEM;
               end
            end
         end
      end
   endtask

   task spi_reading();
      begin
         if(m_spi_rready && m_spi_rvalid && ~m_spi_rresp[1]) begin
            spi_phase <= spi_phase + 8'h1;
            m_spi_arvalid <= 1'b1;
            if(spi_phase < 8'h80) begin
               cdisk_buf[{spi_rep, spi_phase[6:2]}][{spi_phase[1:0], 3'h0} +: 5'h8] <= m_spi_rdata[7:0];
               if(spi_phase == 8'h7f) begin
                  m_spi_arvalid <= 1'b0;
                  m_spi_rready <= 1'b0;
                  spi_wenable <= 1'b1;
                  spi_state <= SPI_STATE_DISABLE;
                  spi_phase <= 8'h0;
                  spi_rep <= spi_rep + 2'h1;
               end
            end
         end
      end
   endtask

   task spi_watch_wip();
      begin
         if(spi_phase == 8'h0) begin
            m_spi_arvalid <= 1'b1;
            m_spi_rready <= 1'b1;
            m_spi_araddr <= 32'h6c;
            spi_phase <= 8'h1;
         end else if(spi_phase == 8'h1) begin
            if(m_spi_rready && m_spi_rvalid && ~m_spi_rresp[1]) begin
               m_spi_arvalid <= 1'b1;
               spi_phase <= 8'h2;
            end
         end else if(spi_phase == 8'h2) begin
            if(m_spi_rready && m_spi_rvalid && ~m_spi_rresp[1]) begin
               m_spi_rready <= 1'b0;
               spi_wip_state[1] <= m_spi_rdata[0];
               spi_wenable <= 1'b1;
               spi_state <= SPI_STATE_DISABLE;
               spi_phase <= 8'h0;
            end
         end
      end
   endtask

   task load_disk(input startup);
      begin
         if (startup) begin
            spi_mode <= SPI_PREPARE;
            spi_state <= SPI_STATE_COMMAND;   
            spi_phase <= 8'hf9;
            spi_rep <= 2'h0;
            spi_prepare_state <= 2'h0;
            spi_wenable <= 1'b1;
         end else if(~m_spi_bready) begin 
            if(spi_state == SPI_STATE_COMMAND) begin
               spi_command();
            end else if(spi_state == SPI_STATE_ENABLE) begin
               spi_enable();
            end else if(spi_state == SPI_STATE_DISABLE) begin
               spi_disable();
            end else if(spi_state == SPI_STATE_READ) begin
               spi_reading();
            end
         end
      end
   endtask

   task write_disk(input startup);
      begin
         if (startup) begin
            spi_mode <= SPI_PREPARE;
            spi_state <= SPI_STATE_COMMAND;   
            spi_phase <= 8'hf9;
            spi_rep <= 2'h0;
            spi_prepare_state <= 2'h1;
            spi_wenable <= 1'b1;
         end else if(~m_spi_bready) begin
            if(spi_state == SPI_STATE_COMMAND) begin
               spi_command();
            end else if(spi_state == SPI_STATE_ENABLE) begin
               spi_enable();
            end else if(spi_state == SPI_STATE_WIP) begin
               spi_watch_wip();
            end else if(spi_state == SPI_STATE_DISABLE) begin
               spi_disable();
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
            mem_addr <= {outhdr.sector[22:0], 9'b0};            
         end else begin
            if (mem_response_enable) begin
               if (cdisk_loop_index == 127) begin
                  cdisk_microstate <= CDISK_INIT;
                  controller_state <= START_TO_HANDLE;
               end else begin
                  cdisk_loop_index <= cdisk_loop_index + 1;               
                  mem_request_enable <= 1'b1;
                  mem_mode <= MEMREQ_WRITE;
                  mem_wdata <= cdisk_buf[cdisk_loop_index + 1];
                  mem_wstrb <= 4'b1111;
                  mem_addr <= {outhdr.sector[22:0], 9'b0} + (cdisk_loop_index+1);
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
            mem_addr <= {outhdr.sector[22:0], 9'b0};            
         end else begin
            if (mem_response_enable) begin
               if (cdisk_loop_index == 127) begin
                  cdisk_microstate <= CDISK_W_DISK;
                  write_disk(1);                  
               end else begin
                  cdisk_buf[cdisk_loop_index]  <= mem_data;               
                  cdisk_loop_index <= cdisk_loop_index + 1;
                  
                  mem_request_enable <= 1'b1;
                  mem_mode <= MEMREQ_READ;
                  mem_addr <= {outhdr.sector[22:0], 9'b0} + (cdisk_loop_index+1);
               end                  
            end else begin
               mem_request_enable <= 1'b0;                           
            end
         end
      end
   endtask // load_mem

   task control_disk;
      begin
         if (cdisk_microstate == CDISK_INIT) begin
            cdisk_loop_index <= 0;            
            if (outhdr.btype == VIRTIO_BLK_T_IN) begin
               cdisk_microstate <= CDISK_R_DISK;
               load_disk(1);               
            end else begin
               cdisk_microstate <= CDISK_R_MEM;
               load_mem(1);               
            end
         end else if (cdisk_microstate == CDISK_R_DISK) begin
            load_disk(0);            
         end else if (cdisk_microstate == CDISK_R_MEM) begin
            load_mem(0);            
         end else if (cdisk_microstate == CDISK_W_DISK) begin
            write_disk(0);            
         end else if (cdisk_microstate == CDISK_W_MEM) begin
            write_mem(0);            
         end
      end
   endtask // control_disk

   
   // notify
   ///////////////////////
   
   enum reg [3:0] {
                   NOTIFY_INIT, 
                   NOTIFY_WAITING, 
                   NOTIFY_WAITING2, 
                   NOTIFY_WAITING3
                   } notify_microstate;   
   task write_used;
      begin
         if (notify_microstate == NOTIFY_INIT) begin
            notify_microstate <= NOTIFY_WAITING;
            
            mem_request_enable <= 1'b1;
            mem_mode <= MEMREQ_WRITE;
            mem_wdata <= used_idx;
            mem_wstrb <= 4'b1111;
            mem_addr <= used_head + 32'd2;
         end else if (notify_microstate == NOTIFY_WAITING) begin
            mem_request_enable <= 1'b0;                 
            if (mem_response_enable) begin
               notify_microstate <= NOTIFY_WAITING2;

               mem_request_enable <= 1'b1;
               mem_mode <= MEMREQ_WRITE;
               mem_wdata <= {16'b0, first_idx};               
               mem_wstrb <= 4'b1111;
               mem_addr <= used_head + 8 * (used_idx-1);
            end
         end else if (notify_microstate == NOTIFY_WAITING2) begin
            mem_request_enable <= 1'b0;                 
            if (mem_response_enable) begin
               notify_microstate <= NOTIFY_WAITING3;

               mem_request_enable <= 1'b1;
               mem_mode <= MEMREQ_WRITE;
               mem_wdata <= 32'b0; // TODO(linux): set appropriate value
               mem_wstrb <= 4'b1111;
               mem_addr <= used_head + 8 * (used_idx-1) + 4;
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
   
   
   task init_controller;
      begin
         avail_idx <= 32'h0;         
         used_idx <= 32'h0;
         load_desc_microstate <= 0;
         load_outhdr_microstate <= 0;
         
         cdisk_microstate <= CDISK_INIT;
         cdisk_loop_index <= 0;         
         
         virtio_interrupt <= 1'b0;
         
         mem_request_enable <= 1'b0;
         mem_mode <= 1'b0;
         mem_addr <= 32'b0;
         mem_wdata <= 32'b0;
         mem_wstrb <= 4'b0;

         m_spi_araddr <= 32'h0;
			m_spi_arvalid <= 1'b0;
			m_spi_arprot <= 3'b000;
			m_spi_rready <= 1'b0;
			m_spi_bready <= 1'b0;
			m_spi_awaddr <= 32'h0;
			m_spi_awvalid <= 1'b0;
			m_spi_awprot <= 3'b000;
			m_spi_wdata <= 32'h0;
			m_spi_wstrb <= 4'b1111;
			m_spi_wvalid <= 1'b0;
         spi_wenable <= 1'b0;           
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
            mem_addr <= avail_head + 32'd2; 
            
            controller_state <= WAITING_MEM_AVAIL_IDX;            
         end else if (controller_state == WAITING_MEM_AVAIL_IDX) begin
            if (mem_response_enable) begin
               avail_idx <= mem_data[15:0];
               if (used_idx != mem_data[15:0]) begin
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
               first_idx <= mem_data[15:0];
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
            buffer_addr <= desc.addr[31:0];
            controller_state <= LOAD_THIRD_DESC;            
         end else if (controller_state == LOAD_THIRD_DESC) begin
            // this change state to LOAD_THIRD_DESC when finished
            load_desc(third_idx, HANDLE_THIRD_DESC);
         end else if (controller_state == HANDLE_THIRD_DESC) begin
            status_addr <= desc.addr[31:0];            
            controller_state <= CONTROL_DISK;            
         end else if (controller_state == CONTROL_DISK) begin
            // this change state to WRITE_USED when finished
            control_disk();            
         end else if (controller_state == WRITE_USED) begin
            // write_used() change state to START_TO_HANDLE when finished
            write_used();            
         end else if (controller_state == RAISE_IRQ) begin
            virtio_interrupt <= 1'b1;            
            controller_state <= WAITING_NOTIFICATION;            
         end

         if(m_spi_arready && m_spi_arvalid) m_spi_arvalid <= 1'b0;
         if(m_spi_rready && m_spi_rvalid) begin
            if(m_spi_rresp[1]) begin
               m_spi_arvalid <= 1'b1;
            end
         end
         if(m_spi_awready && m_spi_awvalid) m_spi_awvalid <= 1'b0;
         if(m_spi_wready && m_spi_wvalid) m_spi_wvalid <= 1'b0;
         if(m_spi_bready && m_spi_bvalid) begin
            if(m_spi_bresp[1]) begin
               m_spi_awvalid <= 1'b1;
               m_spi_wvalid <= 1'b1;
            end else begin
               m_spi_bready <= 1'b0;
            end
         end
         if(spi_wenable && ~m_spi_bready) begin
            m_spi_awvalid <= 1'b1;
            m_spi_wvalid <= 1'b1;
            m_spi_bready <= 1'b1;
         end
      end else begin 
         init_controller();
      end
   end
   
endmodule

`default_nettype wire
