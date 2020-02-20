`default_nettype none

module core_wrapper
  (input wire clk,
   input wire         rstn,

   // bus
   output wire        fetch_request_enable,
   output wire        freq_mode,
   output wire [31:0] freq_addr,
   output wire [31:0] freq_wdata,
   output wire [3:0]  freq_wstrb,
   input wire         fetch_response_enable,
   input wire [31:0]  fresp_data,


   output wire        mem_request_enable,
   output wire        mreq_mode,
   output wire [31:0] mreq_addr,
   output wire [31:0] mreq_wdata,
   output wire [3:0]  mreq_wstrb,
   input wire         mem_response_enable,
   input wire [31:0]  mresp_data,

   // from PLIC
   input wire         ext_intr,

   // from CLINT
   input wire         timer_intr,
   input wire [63:0]  time_full,
   
   // to MMU
   output wire [31:0] o_satp,
   output wire [1:0]  o_cpu_mode,
   output wire        o_mxr,
   output wire        o_sum,
   output wire        flush_tlb,

   // from MMU
   input wire [4:0]   mmu_exception_vec,
   input wire         mmu_exception_enable,
   input wire [31:0]  mmu_exception_tval   
   );   

   core _core(.clk(clk),
              .rstn(rstn),

              .fetch_request_enable(fetch_request_enable),
              .freq_mode(freq_mode),
              .freq_addr(freq_addr),
              .freq_wdata(freq_wdata),
              .freq_wstrb(freq_wstrb),
              .fetch_response_enable(fetch_response_enable),
              .fresp_data(fresp_data),

              .mem_request_enable(mem_request_enable),
              .mreq_mode(mreq_mode),
              .mreq_addr(mreq_addr),
              .mreq_wdata(mreq_wdata),
              .mreq_wstrb(mreq_wstrb),
              .mem_response_enable(mem_response_enable),
              .mresp_data(mresp_data),
      
              .ext_intr(ext_intr),
              
              .timer_intr(timer_intr),
              .time_full(time_full),

              .o_satp(o_satp),
              .o_cpu_mode(o_cpu_mode),
              .o_mxr(o_mxr),
              .o_sum(o_sum),
              .flush_tlb(flush_tlb),

              .mmu_exception_vec(mmu_exception_vec),              
              .mmu_exception_enable(mmu_exception_enable),
              .mmu_exception_tval(mmu_exception_tval));   
   
endmodule

`default_nettype wire
