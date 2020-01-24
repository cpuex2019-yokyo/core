`default_nettype none
`include "def.sv"

module core_wrapper
  (input wire clk,
   input wire         rstn,

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
   input wire [31:0]  mresp_data);

   core _core(.clk(clk),
              .rstn(rstn),

              .fetch_request_enable(fetch_request_enable),
              .freq_fode(freq_fode),
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
              .mresp_data(mresp_data));
   
endmodule

`default_nettype wire
