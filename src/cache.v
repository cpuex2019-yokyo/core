`default_nettype none

module cache_wrapper(
                     input wire        clk,
                     input wire        rstn,

                     input wire        request_enable,
                     input wire        req_mode,
                     input wire [31:0] req_addr,
                     input wire [31:0] req_wdata,
                     input wire [3:0]  req_wstrb,
                     output reg        response_enable,
                     output reg [31:0] resp_data,

                     // address read channel
                     output reg [31:0] axi_araddr,
                     input wire        axi_arready,
                     output reg        axi_arvalid,
                     output reg [2:0]  axi_arprot,

                     // response channel
                     output reg        axi_bready,
                     input wire [1:0]  axi_bresp,
                     input wire        axi_bvalid,

                     // read data channel
                     input wire [31:0] axi_rdata,
                     output reg        axi_rready,
                     input wire [1:0]  axi_rresp,
                     input wire        axi_rvalid,

                     // address write channel
                     output reg [31:0] axi_awaddr,
                     input wire        axi_awready,
                     output reg        axi_awvalid,
                     output reg [2:0]  axi_awprot,

                     // data write channel
                     output reg [31:0] axi_wdata,
                     input wire        axi_wready,
                     output reg [3:0]  axi_wstrb,
                     output reg        axi_wvalid);

   cache _cache(
                .clk(clk),
                .rstn(rstn),

                .request_enable(request_enable),
                .req_mode(req_mode),
                .req_addr(req_addr),
                .req_wdata(req_wdata),
                .req_wstrb(req_wstrb),
                .response_enable(response_enable),
                .resp_data(resp_data),

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
