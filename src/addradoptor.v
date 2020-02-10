`default_nettype none
module adoptor #(
                 parameter OFFSET = 0,
                 parameter BASE = 0,
                 parameter DEST_WIDTH = 32           
                 ) (
                    // master (to)
                    input wire                   clk,

                    output reg [DEST_WIDTH-1:0] m_araddr,
                    input wire                   m_arready,
                    output reg                  m_arvalid,
                    output reg [2:0]            m_arprot,

                    output reg                  m_bready,
                    input wire [1:0]             m_bresp,
                    input wire                   m_bvalid,

                    input wire [31:0]            m_rdata,
                    output reg                  m_rready,
                    input wire [1:0]             m_rresp,
                    input wire                   m_rvalid,

                    output reg [DEST_WIDTH-1:0] m_awaddr,
                    input wire                   m_awready,
                    output reg                  m_awvalid,
                    output reg [2:0]            m_awprot,

                    output reg [31:0]           m_wdata,
                    input wire                   m_wready,
                    output reg [3:0]            m_wstrb,
                    output reg                  m_wvalid,

                    // slave (from)
	                input wire [31:0]            s_araddr,
	                output reg                  s_arready,
	                input wire                   s_arvalid,
	                input wire [2:0]             s_arprot, 

	                input wire                   s_bready,
	                output reg [1:0]            s_bresp,
	                output reg                  s_bvalid,

	                output reg [31:0]           s_rdata,
	                input wire                   s_rready,
	                output reg [1:0]            s_rresp,
	                output reg                  s_rvalid,

	                input wire [31:0]            s_awaddr,
	                output reg                  s_awready,
	                input wire                   s_awvalid,
	                input wire [2:0]             s_awprot, 

	                input wire [31:0]            s_wdata,
	                output reg                  s_wready,
	                input wire [3:0]             s_wstrb,
	                input wire                   s_wvalid);
   
   wire [31:0]                                   s_araddr_proceeded =  s_araddr - BASE + OFFSET;
    wire [31:0]                                   s_awaddr_proceeded = s_awaddr - BASE + OFFSET;  
   always @(posedge clk) begin
   m_araddr <= s_araddr_proceeded[DEST_WIDTH-1:0];
   s_arready <= m_arready;
   m_arvalid <= s_arvalid;
   m_arprot <= s_arprot;

  m_bready <= s_bready;
 s_bresp <= m_bresp;
 s_bvalid <= m_bvalid;

s_rdata <= m_rdata;
m_rready <= s_rready;
 s_rresp <= m_rresp;
s_rvalid <= m_rvalid;
   

 m_awaddr <= s_awaddr_proceeded[DEST_WIDTH-1:0];
 s_awready <= m_awready;
m_awvalid <= s_awvalid;
 m_awprot <= s_awprot;

m_wdata <= s_wdata;
 s_wready <= m_wready;
 m_wstrb <= s_wstrb;
 m_wvalid <= s_wvalid;   
   end
endmodule

`default_nettype wire
