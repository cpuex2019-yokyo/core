`default_nettype none
`include "def.sv"

module mmu(
           input wire        clk,
           input wire        rstn,

           input wire [31:0] satp,
           input wire [1:0]  cpu_mode,
           input wire        mxr,
           input wire        sum,

           input wire        fetch_request_enable,
           input wire        freq_mode,
           input wire [31:0] freq_addr,
           input wire [31:0] freq_wdata,
           input wire [3:0]  freq_wstrb,
           output reg        fetch_response_enable,
           output reg [31:0] fresp_data,

           input wire        mem_request_enable,
           input wire        mreq_mode,
           input wire [31:0] mreq_addr,
           input wire [31:0] mreq_wdata,
           input wire [3:0]  mreq_wstrb,
           output reg        mem_response_enable,
           output reg [31:0] mresp_data,

           output reg [4:0]  exception_vec,
           output reg [31:0] exception_tval,
           output reg        exception_enable,

           output reg        request_enable,
           output reg        req_mode,
           output reg [31:0] req_addr,
           output reg [31:0] req_wdata,
           output reg [3:0]  req_wstrb,
           input wire        response_enable,
           input wire [31:0] resp_data
           );
   


   typedef enum reg [3:0]    {
                              WAITING_REQUEST,
                              FETCHING_FIRST_PTE, 
                              FETCHING_SECOND_PTE, 
                              WAITING_RESPONSE,
                              WAITING_RECEIVE
                              } memistate_t;
   (* mark_debug = "true" *) memistate_t                 state;

   typedef enum reg          {CAUSE_FETCH, CAUSE_MEM} memicause_t;
   (* mark_debug = "true" *) memicause_t operation_cause;

   // 0 for Bare
   // 1 for Sv32
   wire                      paging_mode = satp[31];   
   wire [21:0]               satp_ppn = satp[21:0];
   
   reg [31:0]                _vaddr;   
   reg                       _mode;
   reg [31:0]                _wdata;
   reg [3:0]                 _wstrb;   
   
   // utils
   ///////////////////
   
   function vpn1(input [31:0] addr);
      begin
         vpn1 = addr[31:22];
      end
   endfunction
   
   function vpn0(input [31:0] addr);
      begin
         vpn0 = addr[21:12];
      end
   endfunction
   
   function voffset(input [31:0] addr);
      begin
         voffset = addr[11:0];
      end
   endfunction

   // return: 12 bit
   function ppn1(input [31:0] addr);
      begin
         ppn1 = addr[31:20];
      end
   endfunction

   // return: 10 bit
   function ppn0(input [31:0] addr);
      begin
         ppn0 = addr[19:10];
      end
   endfunction // ppn0
   
   // return: 22 bit
   function ppn(input [31:0] addr);
      begin
         ppn = addr[31:10];
      end
   endfunction // ppn0

   task raise_pagefault_exception;
      begin
         exception_enable <= 1'b1;         
         exception_vec <= _mode == MEMREQ_READ? 5'd13: // load page fault
                          5'd15; // store/amo page fault
         exception_tval <= _vaddr;         
         state <= WAITING_RECEIVE;
         if (operation_cause == CAUSE_FETCH) begin
            fetch_response_enable <= 1'b1;               
            fresp_data <= resp_data;
         end else begin
            mem_response_enable <= 1'b1;               
            mresp_data <= resp_data;
         end
      end
   endtask
   
   // privilege checker
   ///////////////////
   
   // when         
   // sum = 0 ... u-mode page from S-mode will fault.
   // sum = 1 ... not.
   // when
   // mxr = 0 ... read requires r flag
   // mxr = 1 ... read requires r or x flag
   function is_appropriate_usermode(input [31:0] pte);
      begin
         is_appropriate_usermode = ((cpu_mode == CPU_U && pte[4])
                                    || (cpu_mode == CPU_S && sum)
                                    || (~pte[4]));         
      end
   endfunction

   function is_appropriate_operation(input [31:0] pte);
      begin
         is_appropriate_operation = ((operation_cause == CAUSE_FETCH && pte[3])
                                     || (operation_cause == CAUSE_MEM && ((_mode == MEMREQ_READ && pte[1]) 
                                                                          || (_mode == MEMREQ_WRITE && pte[2]))));
      end
   endfunction // is_appropriate_operation

   function has_permission(input [31:0] pte);
      begin
         has_permission = is_appropriate_usermode(pte) && is_appropriate_operation(pte);         
      end
   endfunction
   

   // initialization
   ///////////////////
   
   task init;
      begin
         fetch_response_enable <= 1'b0;
         fresp_data <= 32'b0;
         
         mem_response_enable <= 1'b0;
         mresp_data <= 32'b0;
         
         request_enable <= 1'b0;
         _mode <= 1'b0;
         _wdata <= 32'b0;
         _wstrb <= 32'b0;
         _vaddr <= 32'b0;     
         
         state <= WAITING_REQUEST;
      end
   endtask
   
   initial begin
      init();
   end

   // main logic
   ///////////////////
   
   task handle_leaf(input level, input [31:0] pte);
      begin
         if (~has_permission(pte)) begin
            raise_pagefault_exception();
         end else if (level > 0 && ppn0(pte) != 10'b0) begin
            raise_pagefault_exception();            
         end else begin
            if (pte[6] == 0 || (operation_cause == CAUSE_MEM && _mode == MEMREQ_WRITE && pte[7])) begin
               raise_pagefault_exception();            
            end else begin
               state <= WAITING_RESPONSE;
               req_mode <= _mode;
               req_wdata <= _wdata;
               req_wstrb <= _wstrb;
               if (level == 1) begin
                  req_addr <= {ppn1(pte), vpn0(_vaddr), voffset(_vaddr)};                     
               end else begin
                  req_addr <= {ppn1(pte), ppn0(_vaddr), voffset(_vaddr)};                     
               end
               request_enable <= 1'b1;                  
            end
         end
      end
   endtask // handle_leaf
   
   // NOTE: READ CAREFULLY: v1.10.0 - 4.3 Sv32 
   always @(posedge clk) begin
      if(rstn) begin
         if (state == WAITING_REQUEST && fetch_request_enable) begin
            exception_vec <= 5'b0;
            exception_enable <= 1'b0;
            operation_cause <= CAUSE_FETCH;            
            if (paging_mode == 0) begin
               state <= WAITING_RESPONSE;
               request_enable <= 1'b1;
               req_mode <= freq_mode;
               req_wdata <= freq_wdata;
               req_wstrb <= freq_wstrb;
               req_addr <= freq_addr;               
            end else begin
               // TODO: TLB hit
               state <= FETCHING_FIRST_PTE;
               request_enable <= 1'b1;
               req_mode <= MEMREQ_READ;
               req_addr <= {satp_ppn[19:0], 12'b0} + vpn1(freq_addr) * 4;            
               ;            
               _vaddr <= freq_addr;
               _mode <= freq_mode;
               _wdata <= freq_wdata;
               _wstrb <= freq_wstrb;
            end
         end else if (state == WAITING_REQUEST & mem_request_enable) begin
            exception_vec <= 5'b0;
            exception_enable <= 1'b0;
            operation_cause <= CAUSE_MEM;            
            if (paging_mode == 0) begin
               state <= WAITING_RESPONSE;
               request_enable <= 1'b1;
               req_mode <= mreq_mode;
               req_wdata <= mreq_wdata;
               req_wstrb <= mreq_wstrb;
               req_addr <= mreq_addr;               
            end else begin
               // TODO: TLB hit
               state <= FETCHING_FIRST_PTE;            
               request_enable <= 1'b1;
               req_mode <= MEMREQ_READ;
               req_addr <= {satp_ppn[19:0], 12'b0} + vpn1(freq_addr) * 4;            
               
               _vaddr <= mreq_addr;
               _mode <= mreq_mode;
               _wdata <= mreq_wdata;
               _wstrb <= mreq_wstrb;
            end
         end else if (state == FETCHING_FIRST_PTE && response_enable) begin
            if (resp_data[0] == 0 || (resp_data[1] == 0 && resp_data[2] == 1)) begin
               raise_pagefault_exception();               
            end else begin
               if (resp_data[1] == 1 || resp_data[3] == 1) begin
                  // PTE seems to be a leaf node.
                  handle_leaf(1, resp_data);                  
               end else begin
                  // not a leaf node. 
                  state <= FETCHING_SECOND_PTE;                  
                  request_enable <= 1'b1;
                  req_mode <= MEMREQ_READ;
                  req_addr <= {satp_ppn[19:0], 12'b0} + vpn0(_vaddr) * 4;
               end
            end
         end else if (state == FETCHING_SECOND_PTE && response_enable) begin
            if (resp_data[0] == 0 || (resp_data[1] == 0 && resp_data[2] == 1)) begin
               raise_pagefault_exception();               
            end else begin
               if (resp_data[1] == 1 || resp_data[3] == 1) begin
                  // PTE seems to be a leaf node.
                  handle_leaf(0, resp_data);                  
               end else begin
                  raise_pagefault_exception();               
               end
            end
         end else if (state == WAITING_RESPONSE && response_enable) begin
            state <= WAITING_RECEIVE;            
            if (operation_cause == CAUSE_FETCH) begin
               fetch_response_enable <= 1'b1;               
               fresp_data <= resp_data;
            end else begin
               mem_response_enable <= 1'b1;               
               mresp_data <= resp_data;
            end
         end else if (state == WAITING_RECEIVE) begin
            state <= WAITING_REQUEST;            
            if (operation_cause == CAUSE_FETCH) begin
               fetch_response_enable <= 1'b0;               
            end else begin
               mem_response_enable <= 1'b0;               
            end            
         end else begin
            request_enable <= 0;            
         end
      end else begin
         init();
      end
   end
endmodule
`default_nettype wire
