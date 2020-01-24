`default_nettype none

module mmu_wrapper (
                    input wire         clk,
                    input wire         rstn,

                    input wire         fetch_request_enable,
                    input wire         freq_mode,
                    input wire [31:0]  freq_addr,
                    input wire [31:0]  freq_wdata,
                    input wire [3:0]   freq_wstrb,
                    output wire        fetch_response_enable,
                    output wire [31:0] fresp_data,


                    input wire         mem_request_enable,
                    input wire         mreq_mode,
                    input wire [31:0]  mreq_addr,
                    input wire [31:0]  mreq_wdata,
                    input wire [3:0]   mreq_wstrb,
                    output wire        mem_response_enable,
                    output wire [31:0] mresp_data,

                    // address read channel
                    output wire [31:0] axi_araddr,
                    input wire         axi_arready,
                    output wire        axi_arvalid,
                    output wire [2:0]  axi_arprot,

                    // response channel
                    output wire        axi_bready,
                    input wire [1:0]   axi_bresp,
                    input wire         axi_bvalid,

                    // read data channel
                    input wire [31:0]  axi_rdata,
                    output wire        axi_rready,
                    input wire [1:0]   axi_rresp,
                    input wire         axi_rvalid,

                    // address write channel
                    output wire [31:0] axi_awaddr,
                    input wire         axi_awready,
                    output wire        axi_awvalid,
                    output wire [2:0]  axi_awprot,

                    // data write channel
                    output wire [31:0] axi_wdata,
                    input wire         axi_wready,
                    output wire [3:0]  axi_wstrb,
                    output wire        axi_wvalid);

   mmu _mmu(.clk(clk), .rstn(rstn),
      
            .fetch_request_enable(fetch_request_enable),
            .freq_fode(freq_mode),
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
