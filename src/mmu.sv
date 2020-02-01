`default_nettype none
`include "def.sv"

module mmu(
           input wire         clk,
           input wire         rstn,

           input wire [31:0]  satp,
           input wire [1:0]   cpu_mode,
           input wire         mxr,
           input wire         sum,
           
           input wire         fetch_request_enable,
           input wire         freq_mode,
           input wire [31:0]  freq_addr,
           input wire [31:0]  freq_wdata,
           input wire [3:0]   freq_wstrb,
           output reg         fetch_response_enable,
           output reg [31:0]  fresp_data,


           input wire         mem_request_enable,
           input wire         mreq_mode,
           input wire [31:0]  mreq_addr,
           input wire [31:0]  mreq_wdata,
           input wire [3:0]   mreq_wstrb,
           output reg         mem_response_enable,
           output reg [31:0]  mresp_data,

           output wire        request_enable,
           output wire        req_mode,
           output wire [31:0] req_addr,
           output wire [31:0] req_wdata,
           output wire [3:0]  req_wstrb,
           input wire         response_enable,
           input wire [31:0]  resp_data);
   


   typedef enum reg [3:0]     {
                               WAITING_REQUEST,
                               FETCHING_FIRST_PTE, 
                               FETCHING_SECOND_PTE, 
                               WAITING_RESPONSE,
                               WAITING_RECEIVE
                               } memistate_t;
   (* mark_debug = "true" *) memistate_t                 state;

   typedef enum reg           {CAUSE_FETCH, CAUSE_MEM} memicause_t;
   (* mark_debug = "true" *) memicause_t cause;

   reg [31:0]                 _vaddr;
   
   function vpn1(input [31:0] addr);
      begin
         vpn1 = addr[31:22];
      end
   endfunction
   
   function vpn2(input [31:0] addr);
      begin
         vpn2 = addr[21:12];
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
   endfunction
   
   reg                        _mode;
   reg [31:0]                 _wdata;
   reg [3:0]                  _wstrb;   
   
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

         vaddr <= 32'b0;
         pte <= 32'b0;         
         
         state <= WAITING_REQUEST;
      end
   endtask

   task handle_leaf(input level, input [31:0] pte);
      begin
         // TODO: check priviledge according to step 5.
         // when         
         // sum = 0 ... u-mode page from S-mode will fault.
         // sum = 1 ... not.
         // when
         // mxr = 0 ... read requires r flag
         // mxr = 1 ... read requires r or x flag
         if (((cpu_mode == CPU_U && pte[4])
             || (cpu_mode == CPU_S && sum)
             || (~pte[4]))
             && 
             ((cause == CAUSE_FETCH && pte[3])
              || (cause == CAUSE_MEM && _mode == MEMREQ_READ && pte[1])
              || (cause == CAUSE_MEM && _mode == MEMREQ_READ && pte[2]))) begin
            if (level > 0 && ppn0(pte) != 10'b0) begin
               // TODO: raise page-fault exception
            end else begin
               if (pte[6] == 0 || (cause == CAUSE_MEM && _mode == MEMREQ_WRITE && pte[7])) begin
                  // TODO: raise page-fault exception
               end else begin
                  state <= WAITING_RESPONSE;
                  req_mode <= _mode;
                  req_wdata <= _wdata;
                  req_wstrb <= _wstrb;
                  if (level == 1) begin
                     req_addr <= {ppn1(pte), vpn0(vaddr), voffset(vaddr)};                     
                  end else begin
                     req_addr <= {ppn1(pte), ppn0(vaddr), voffset(vaddr)};                     
                  end
                  request_enable <= 1'b1;                  
               end
            end
         end else begin
            // no permission.
            // TODO: raise page-fault exception
         end
      end
   endtask

   initial begin
      init();
   end

   // NOTE: READ CAREFULLY: v1.10.0 - 4.3 Sv32 

   always @(posedge clk) begin
      if(rstn) begin
         if (state == WAITING_REQUEST && fetch_request_enable) begin
            // TODO: TLB hit
            state <= FETCHING_FIRST_PTE;
            request_enable <= 1'b1;
            req_mode <= MEMREQ_READ;
            req_addr <= (satp * 4096) + vpn1(freq_addr) * 4;            
            
            cause <= CAUSE_FETCH;            
            vaddr <= freq_addr;
            _mode <= freq_mode;
            _wdata <= freq_wdata;
            _wstrb <= freq_wstrb;            
         end else if (state == WAITING_REQUEST & mem_request_enable) begin
            // TODO: TLB hit
            state <= FETCHING_FIRST_PTE;            
            request_enable <= 1'b1;
            req_mode <= MEMREQ_READ;
            req_addr <= (ppn(satp) * 4096) + vpn1(freq_addr) * 4;            
            
            cause <= CAUSE_MEM;            
            vaddr <= mreq_addr;
            _mode <= mreq_mode;
            _wdata <= mreq_wdata;
            _wstrb <= mreq_wstrb;
         end else if (state == FETCHING_FIRST_PTE && response_enable) begin
            if (resp_data[0] == 0 || (resp_data[1] == 0 && resp_data[2] == 1)) begin
               // PTE is not valid.
               // TODO: raise page-fault exception
            end else begin
               // PTE seems to be valid. 
               if (resp_data[1] == 1 || resp_data[3] == 1) begin
                  // Leaf
                  handle_leaf(1, resp_data);                  
               end else begin
                  state <= FETCHING_SECOND_PTE;                  
                  request_enable <= 1'b1;
                  req_mode <= MEMREQ_READ;
                  req_addr <= (ppn(satp) * 4096) + vpn1(freq_addr) * 4;
               end
            end
         end else if (state == FETCHING_SECOND_PTE && response_enable) begin
            if (resp_data[0] == 0 || (resp_data[1] == 0 && resp_data[2] == 1)) begin
               // PTE is not valid.
               // TODO: raise page-fault exception
            end else begin
               // PTE seems to be valid. 
               if (resp_data[1] == 1 || resp_data[3] == 1) begin
                  // Leaf                  
                  handle_leaf(0, resp_data);                  
               end else begin
                  // PTE is not valid.
                  // TODO: raise page-fault exception
               end
            end
         end if (state == WAITING_RESPONSE && response_enable) begin
            state <= WAITING_RECEIVE;            
            if (cause == CAUSE_FETCH) begin
               fetch_response_enable <= 1'b1;               
               fresp_data <= resp_data;
            end else begin
               mem_response_enable <= 1'b1;               
               mresp_data <= resp_data;
            end
         end if (state == WAITING_RECEIVE) begin
            state <= WAITING_REQUEST;            
            if (cause == CAUSE_FETCH) begin
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
