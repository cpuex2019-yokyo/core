`default_nettype none
`include "def.sv"

module mmu_wrapper (
           input wire        clk,
           input wire        rstn,

           input wire        fetch_request_enable,
           input            memreq fetch_request,
           output wire        fetch_response_enable,
           output             memresp fetch_response,

           input wire        mem_request_enable,
           input            memreq mem_request,
           output wire        mem_response_enable,
           output             memresp mem_response,

           // address read channel
           output wire [31:0] axi_araddr,
           input wire        axi_arready,
           output wire        axi_arvalid,
           output wire [2:0]  axi_arprot,

           // response channel
           output wire        axi_bready,
           input wire [1:0]  axi_bresp,
           input wire        axi_bvalid,

           // read data channel
           input wire [31:0] axi_rdata,
           output wire        axi_rready,
           input wire [1:0]  axi_rresp,
           input wire        axi_rvalid,

           // address write channel
           output wire [31:0] axi_awaddr,
           input wire        axi_awready,
           output wire        axi_awvalid,
           output wire [2:0]  axi_awprot,

           // data write channel
           output wire [31:0] axi_wdata,
           input wire        axi_wready,
           output wire [3:0]  axi_wstrb,
           output wire        axi_wvalid);

mmu _mmu(.clk(clk), .rstn(rstn),
         .fetch_request_enable(fetch_request_enable),
         .fetch_request(fetch_request),
         .fetch_response_enable(fetch_response_enable),
         .fetch_response(fetch_response),

         .mem_request_enable(mem_request_enable),
         .mem_request(mem_request),
         .mem_response_enable(mem_response_enable),
         .mem_response(mem_response),

         .axi_araddr(axi_araddr),
         .axi_arready(axi_arready),
         .axi_arvalid(axi_arvalid),
         .axi_arprot(axi_arprot),

         .axi_bready(axi_bready),
         .axi_bresp(axi_bresp),
         .axi_bvalid(axi_bvalid),

         .axi_rdata(axi_rdata),
         .axi_rready(axi_rready),
         .axi_rresp(axi_rresp),
         .axi_rvalid(axi_rvalid),

         .axi_awaddr(axi_awaddr),
         .axi_awready(axi_awready),
         .axi_awvalid(axi_awvalid),
         .axi_awprot(axi_awprot),

         .axi_wdata(axi_wdata),
         .axi_wready(axi_wready),
         .axi_wstrb(axi_wstrb),
         .axi_wvalid(axi_wvalid));

endmodule
`default_nettype wire
