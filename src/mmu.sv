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
           input wire [31:0] resp_data,

           input wire        flush_tlb
           );  

   // mmu state
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
   
   function [9:0] vpn1(input [31:0] addr);
      begin
         vpn1 = addr[31:22];
      end
   endfunction
   
   function [9:0] vpn0(input [31:0] addr);
      begin
         vpn0 = addr[21:12];
      end
   endfunction
   
   function [19:0] vpn(input [31:0] addr);
      begin
         vpn = addr[31:12];
      end
   endfunction
   
   function [11:0] voffset(input [31:0] addr);
      begin
         voffset = addr[11:0];
      end
   endfunction

   // return: 12 bit
   function [11:0] ppn1(input [31:0] addr);
      begin
         ppn1 = addr[31:20];
      end
   endfunction

   // return: 10 bit
   function [9:0] ppn0(input [31:0] addr);
      begin
         ppn0 = addr[19:10];
      end
   endfunction // ppn0
   
   // return: 22 bit
   function [21:0] ppn(input [31:0] addr);
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
         clear_tlb();         
      end
   endtask
   
   initial begin
      init();
   end
   
   // TLB
   ///////////////////      
   reg [42:0]                tlb_table [0:15];
   
   function [0:0] tlb_valid(input [42:0] entry);
      begin
         tlb_valid = entry[42];         
      end
   endfunction
   
   function [19:0] tlb_tag(input [42:0] entry);
      begin
         tlb_tag = entry[41:22];         
      end
   endfunction
   
   function [21:0] tlb_phys(input [42:0] entry);
      begin
         tlb_phys = entry[21:0];         
      end
   endfunction

   integer i;   
   task clear_tlb;
      begin
         for (i = 0; i < 16; i = i + 1) begin
            tlb_table[i][42] <= 1'b0;               
         end         
      end
   endtask

   task set_tlb(input [31:0] vaddr, input [33:0] paddr);
      begin
         if (tlb_valid(tlb_entry(vaddr))) begin
            // if there's a valid entry for vaddr, do nothing.
         end else if(!tlb_valid(tlb_table[0])) begin
            tlb_table[0] <= {1'b1, vaddr[31:12], paddr[33:12]};            
         end else if(!tlb_valid(tlb_table[1])) begin
            tlb_table[1] <= {1'b1, vaddr[31:12], paddr[33:12]};            
         end else if(!tlb_valid(tlb_table[2])) begin
            tlb_table[2] <= {1'b1, vaddr[31:12], paddr[33:12]};            
         end else if(!tlb_valid(tlb_table[3])) begin
            tlb_table[3] <= {1'b1, vaddr[31:12], paddr[33:12]};            
         end else if(!tlb_valid(tlb_table[4])) begin
            tlb_table[4] <= {1'b1, vaddr[31:12], paddr[33:12]};            
         end else if(!tlb_valid(tlb_table[5])) begin
            tlb_table[5] <= {1'b1, vaddr[31:12], paddr[33:12]};            
         end else if(!tlb_valid(tlb_table[6])) begin
            tlb_table[6] <= {1'b1, vaddr[31:12], paddr[33:12]};            
         end else if(!tlb_valid(tlb_table[7])) begin
            tlb_table[7] <= {1'b1, vaddr[31:12], paddr[33:12]};            
         end else if(!tlb_valid(tlb_table[8])) begin
            tlb_table[8] <= {1'b1, vaddr[31:12], paddr[33:12]};            
         end else if(!tlb_valid(tlb_table[9])) begin
            tlb_table[9] <= {1'b1, vaddr[31:12], paddr[33:12]};            
         end else if(!tlb_valid(tlb_table[10])) begin
            tlb_table[10] <= {1'b1, vaddr[31:12], paddr[33:12]};            
         end else if(!tlb_valid(tlb_table[11])) begin
            tlb_table[11] <= {1'b1, vaddr[31:12], paddr[33:12]};            
         end else if(!tlb_valid(tlb_table[12])) begin
            tlb_table[12] <= {1'b1, vaddr[31:12], paddr[33:12]};            
         end else if(!tlb_valid(tlb_table[13])) begin
            tlb_table[13] <= {1'b1, vaddr[31:12], paddr[33:12]};            
         end else if(!tlb_valid(tlb_table[14])) begin
            tlb_table[14] <= {1'b1, vaddr[31:12], paddr[33:12]};            
         end else if(!tlb_valid(tlb_table[15])) begin
            tlb_table[15] <= {1'b1, vaddr[31:12], paddr[33:12]};            
         end else begin
            // TODO: should be replaced with a better algorithm!
            tlb_table[0] <= {1'b1, vaddr[31:12], paddr[33:12]};
         end
      end
   endtask
   
   function [42:0] tlb_entry(input [31:0] vaddr);
   begin 
    tlb_entry = tlb_tag(tlb_table[0]) == vpn(vaddr)? tlb_table[0]:
                             tlb_tag(tlb_table[1]) == vpn(vaddr)? tlb_table[1]:                             
                             tlb_tag(tlb_table[2]) == vpn(vaddr)? tlb_table[2]:                             
                             tlb_tag(tlb_table[3]) == vpn(vaddr)? tlb_table[3]:                             
                             tlb_tag(tlb_table[4]) == vpn(vaddr)? tlb_table[4]:                             
                             tlb_tag(tlb_table[5]) == vpn(vaddr)? tlb_table[5]:                             
                             tlb_tag(tlb_table[6]) == vpn(vaddr)? tlb_table[6]:                             
                             tlb_tag(tlb_table[7]) == vpn(vaddr)? tlb_table[7]:                             
                             tlb_tag(tlb_table[8]) == vpn(vaddr)? tlb_table[8]:                             
                             tlb_tag(tlb_table[9]) == vpn(vaddr)? tlb_table[9]:                             
                             tlb_tag(tlb_table[10]) == vpn(vaddr)? tlb_table[10]:                             
                             tlb_tag(tlb_table[11]) == vpn(vaddr)? tlb_table[11]:                             
                             tlb_tag(tlb_table[12]) == vpn(vaddr)? tlb_table[12]:                             
                             tlb_tag(tlb_table[13]) == vpn(vaddr)? tlb_table[13]:                             
                             tlb_tag(tlb_table[14]) == vpn(vaddr)? tlb_table[14]:                             
                             tlb_tag(tlb_table[15]) == vpn(vaddr)? tlb_table[15]:
                             43'b0;
   end
   endfunction

   // main logic
   ///////////////////   
   function [33:0] l1_result(input [31:0] pte, input [31:0] vaddr);
   begin
    l1_result = {ppn1(pte), vpn0(vaddr), voffset(vaddr)};
   end  
   endfunction
   
   function [33:0] l0_result(input [31:0] pte, input [31:0] vaddr);
   begin
    l0_result = {ppn1(pte), ppn0(pte), voffset(vaddr)};
   end  
   endfunction   
   
   task handle_leaf(input level, input [31:0] pte);
      begin
         if (!has_permission(pte)) begin
            raise_pagefault_exception();
         end else if (level > 0 && ppn0(pte) != 10'b0) begin
            raise_pagefault_exception();            
         end else begin
            if (pte[6] == 0 || (operation_cause == CAUSE_MEM && _mode == MEMREQ_WRITE && (pte[7] == 0))) begin
               raise_pagefault_exception();            
            end else begin
               state <= WAITING_RESPONSE;
               req_mode <= _mode;
               req_wdata <= _wdata;
               req_wstrb <= _wstrb;
               // NOTE: 34 -> 32
               req_addr <= level == 1? l1_result(pte, _vaddr) : l0_result(pte, _vaddr);
               // NOTE: 34 -> 22
               set_tlb(_vaddr, level == 1? l1_result(pte, _vaddr) : l0_result(pte, _vaddr));
               request_enable <= 1'b1;                  
            end
         end
      end
   endtask // handle_leaf
   
   wire _req_mode = (fetch_request_enable)? freq_mode:
        (mem_request_enable)? mreq_mode:
        1'b0;
   wire [31:0] _req_addr = (fetch_request_enable)? freq_addr:
               (mem_request_enable)? mreq_addr:
               1'b0;
   wire [31:0] _req_wdata = (fetch_request_enable)? freq_wdata:
               (mem_request_enable)? mreq_wdata:
               1'b0;
   wire [3:0]  _req_wstrb = (fetch_request_enable)? freq_wstrb:
               (mem_request_enable)? mreq_wstrb:
               1'b0;       
                  
   // NOTE: READ CAREFULLY: v1.10.0 - 4.3 Sv32
   always @(posedge clk) begin
      if(rstn) begin
         if (state == WAITING_REQUEST && flush_tlb) begin
            clear_tlb();            
         end else if (state == WAITING_REQUEST && (fetch_request_enable | mem_request_enable)) begin
            exception_vec <= 5'b0;
            exception_enable <= 1'b0;
            operation_cause <= (fetch_request_enable)? CAUSE_FETCH: CAUSE_MEM;            
            if (paging_mode == 0 || cpu_mode == CPU_M) begin
               state <= WAITING_RESPONSE;
               request_enable <= 1'b1;
               req_mode <= _req_mode;
               req_wdata <= _req_wdata;
               req_wstrb <= _req_wstrb;
               req_addr <= _req_addr;
               // TODO: kore ha dame
               set_tlb(_req_addr, {2'b0, _req_addr});                         
            end else begin
               if (tlb_valid(tlb_entry(_req_addr))) begin
                  state <= WAITING_RESPONSE;
                  request_enable <= 1'b1;
                  req_mode <= _req_mode;
                  req_wdata <= _req_wdata;
                  req_wstrb <= _req_wstrb;
                  req_addr <= {tlb_phys(tlb_entry(_req_addr)), _req_addr[11:0]};
               end else begin
                  state <= FETCHING_FIRST_PTE;
                  request_enable <= 1'b1;
                  req_mode <= MEMREQ_READ;
                  req_addr <= {satp_ppn[19:0], 12'b0} + vpn1(_req_addr) * 4;            
                  _vaddr <= _req_addr;
                  _mode <= _req_mode;
                  _wdata <= _req_wdata;
                  _wstrb <= _req_wstrb;
               end
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
