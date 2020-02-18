`default_nettype none

module virtio_wrapper(
                      // general
	                  input wire         clk,
	                  input wire         rstn,

                      // bus for core
	                  input wire [31:0]  core_araddr,
	                  output wire        core_arready,
	                  input wire         core_arvalid,
	                  input wire [2:0]   core_arprot,

	                  output wire [31:0] core_rdata,
	                  input wire         core_rready,
	                  output wire [1:0]  core_rresp,
	                  output wire        core_rvalid,

	                  input wire         core_bready,
	                  output wire [1:0]  core_bresp,
	                  output wire        core_bvalid,

	                  input wire [31:0]  core_awaddr,
	                  output wire        core_awready,
	                  input wire         core_awvalid,
	                  input wire [2:0]   core_awprot,

	                  input wire [31:0]  core_wdata,
	                  output wire        core_wready,
	                  input wire [3:0]   core_wstrb,
	                  input wire         core_wvalid,

                      // bus for mem
                      output wire        mem_request_enable,
                      output wire        mem_mode,
                      output wire [31:0] mem_addr,
                      output wire [31:0] mem_wdata,
                      output wire [3:0]  mem_wstrb, 
                      input wire         mem_response_enable,
                      input wire [31:0]  mem_data,

                      // bus for disk
                      output wire [31:0]  m_spi_araddr,
                      input wire         m_spi_arready,
                      output wire         m_spi_arvalid,
                      output wire [2:0]   m_spi_arprot,

                      input wire [31:0]  m_spi_rdata,
                      output wire         m_spi_rready,
                      input wire [1:0]   m_spi_rresp,
                      input wire         m_spi_rvalid,

                      output wire         m_spi_bready,
                      input wire [1:0]   m_spi_bresp,
                      input wire         m_spi_bvalid,

                      output wire [31:0]  m_spi_awaddr,
                      input wire         m_spi_awready,
                      output wire         m_spi_awvalid,
                      output wire [2:0]   m_spi_awprot,

                      output wire [31:0]  m_spi_wdata,
                      input wire         m_spi_wready,
                      output wire [3:0]   m_spi_wstrb,
                      output wire         m_spi_wvalid,
                      
                      // general
                      output wire        virtio_interrupt
                      );

   virtio _virtio(
                  .clk(clk),
                  .rstn(rstn),

                  .core_araddr(core_araddr),
                  .core_arready(core_arready),
                  .core_arvalid(core_arvalid),
                  .core_arprot(core_arprot),

                  .core_bready(core_bready),
                  .core_bresp(core_bresp),
                  .core_bvalid(core_bvalid),

                  .core_rdata(core_rdata),
                  .core_rready(core_rready),
                  .core_rresp(core_rresp),
                  .core_rvalid(core_rvalid),

                  .core_awaddr(core_awaddr),
                  .core_awready(core_awready),
                  .core_awvalid(core_awvalid),
                  .core_awprot(core_awprot),

                  .core_wdata(core_wdata),
                  .core_wready(core_wready),
                  .core_wstrb(core_wstrb),
                  .core_wvalid(core_wvalid),

                  .mem_request_enable(mem_request_enable),
                  .mem_mode(mem_mode),
                  .mem_addr(mem_addr),
                  .mem_wdata(mem_wdata),
                  .mem_wstrb(mem_wstrb),
                  .mem_response_enable(mem_response_enable),
                  .mem_data(mem_data),

                  .m_spi_araddr(m_spi_araddr),
                  .m_spi_arready(m_spi_arready),
                  .m_spi_arvalid(m_spi_arvalid),
                  .m_spi_arprot(m_spi_arprot),

                  .m_spi_bready(m_spi_bready),
                  .m_spi_bresp(m_spi_bresp),
                  .m_spi_bvalid(m_spi_bvalid),

                  .m_spi_rdata(m_spi_rdata),
                  .m_spi_rready(m_spi_rready),
                  .m_spi_rresp(m_spi_rresp),
                  .m_spi_rvalid(m_spi_rvalid),

                  .m_spi_awaddr(m_spi_awaddr),
                  .m_spi_awready(m_spi_awready),
                  .m_spi_awvalid(m_spi_awvalid),
                  .m_spi_awprot(m_spi_awprot),

                  .m_spi_wdata(m_spi_wdata),
                  .m_spi_wready(m_spi_wready),
                  .m_spi_wstrb(m_spi_wstrb),
                  .m_spi_wvalid(m_spi_wvalid),
                  
                  .virtio_interrupt(virtio_interrupt)
                  );
      
endmodule
`default_nettype wire
