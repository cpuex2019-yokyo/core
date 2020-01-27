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
   input wire         software_intr,
   input wire         timer_intr,
   input wire [63:0]  time_full);

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
              
              .software_intr(software_intr),
              .timer_intr(timer_intr),
              .time_full(time_full));
   
endmodule

`default_nettype wire
