`default_nettype none

module cache_wrapper (
                      input              clk,
                      input              rstn,

                      // master (to)
                      output wire [31:0] m_araddr,
                      input wire         m_arready,
                      output wire        m_arvalid,
                      output wire [2:0]  m_arprot,

                      output wire        m_bready,
                      input wire [1:0]   m_bresp,
                      input wire         m_bvalid,

                      input wire [31:0]  m_rdata,
                      output wire        m_rready,
                      input wire [1:0]   m_rresp,
                      input wire         m_rvalid,

                      output wire [31:0] m_awaddr,
                      input wire         m_awready,
                      output wire        m_awvalid,
                      output wire [2:0]  m_awprot,

                      output wire [31:0] m_wdata,
                      input wire         m_wready,
                      output wire [3:0]  m_wstrb,
                      output wire        m_wvalid,

                      // slave (from)
	                  input wire [31:0]  s_araddr,
	                  output wire        s_arready,
	                  input wire         s_arvalid,
	                  input wire [2:0]   s_arprot, 

	                  input wire         s_bready,
	                  output wire [1:0]  s_bresp,
	                  output wire        s_bvalid,

	                  output wire [31:0] s_rdata,
	                  input wire         s_rready,
	                  output wire [1:0]  s_rresp,
	                  output wire        s_rvalid,

	                  input wire [31:0]  s_awaddr,
	                  output wire        s_awready,
	                  input wire         s_awvalid,
	                  input wire [2:0]   s_awprot, 

	                  input wire [31:0]  s_wdata,
	                  output wire        s_wready,
	                  input wire [3:0]   s_wstrb,
	                  input wire         s_wvalid);

   cache _cache(
                .clk(clk),
                .rstn(rstn),
      
                .m_araddr(m_araddr),
                .m_arready(m_arready),
                .m_arvalid(m_arvalid),
                .m_arprot(m_arprot),

                .m_bready(m_bready),
                .m_bresp(m_bresp),
                .m_bvalid(m_bvalid),

                .m_rdata(m_rdata),
                .m_rready(m_rready),
                .m_rresp(m_rresp),
                .m_rvalid(m_rvalid),

                .m_awaddr(m_awaddr),
                .m_awready(m_awready),
                .m_awvalid(m_awvalid),
                .m_awprot(m_awprot),

                .m_wdata(m_wdata),
                .m_wready(m_wready),
                .m_wstrb(m_wstrb),
                .m_wvalid(m_wvalid),
      
                .s_araddr(s_araddr),
                .s_arready(s_arready),
                .s_arvalid(s_arvalid),
                .s_arprot(s_arprot),

                .s_bready(s_bready),
                .s_bresp(s_bresp),
                .s_bvalid(s_bvalid),

                .s_rdata(s_rdata),
                .s_rready(s_rready),
                .s_rresp(s_rresp),
                .s_rvalid(s_rvalid),

                .s_awaddr(s_awaddr),
                .s_awready(s_awready),
                .s_awvalid(s_awvalid),
                .s_awprot(s_awprot),

                .s_wdata(s_wdata),
                .s_wready(s_wready),
                .s_wstrb(s_wstrb),
                .s_wvalid(s_wvalid));
   
endmodule

`default_nettype wire
