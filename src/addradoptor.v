`default_nettype none
module adoptor #(
                 parameter OFFSET = 0,
                 parameter LEFT_SHIFT = 0                 
                 ) (
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
   
   wire [31:0] s_araddr_offset = s_araddr - OFFSET;
   assign m_araddr = {s_araddr_offset[31-LEFT_SHIFT:0], {(LEFT_SHIFT){1'b0}}};
   assign s_arready = m_arready;
   assign m_arvalid = s_arvalid;
   assign m_arprot = s_arprot;

   assign m_bready = s_bready;
   assign s_bresp = m_bresp;
   assign s_bvalid = m_bvalid;

   assign s_rdata = m_rdata;
   assign m_rready = s_rready;
   assign s_rresp = m_rresp;
   assign s_rvalid = m_rvalid;
   
   wire [31:0] s_awaddr_offset = s_awaddr - OFFSET;
   assign m_awaddr = {s_awaddr_offset[31-LEFT_SHIFT:0], {(LEFT_SHIFT){1'b0}}};
   assign s_awready = m_awready;
   assign m_awvalid = s_awvalid;
   assign m_awprot = s_awprot;

   assign m_wdata = s_wdata;
   assign s_wready = m_wready;
   assign m_wstrb = s_wstrb;
   assign m_wvalid = s_wvalid;   
   
endmodule

`default_nettype wire
