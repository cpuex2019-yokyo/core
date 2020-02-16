`default_nettype none
`include "def.sv"

module adoptor #(
                 parameter OFFSET = 0,
                 parameter BASE = 0,
                 parameter CHANGE_ENDIAN = 0,
                 parameter DEST_WIDTH = 32           
                 ) (
                    // master (to)
                    input wire                  clk,
                    input wire                  rstn,

                    output reg [DEST_WIDTH-1:0] m_araddr,
                    input wire                  m_arready,
                    output reg                  m_arvalid,
                    output reg [2:0]            m_arprot,

                    output reg                  m_bready,
                    input wire [1:0]            m_bresp,
                    input wire                  m_bvalid,

                    input wire [31:0]           m_rdata,
                    output reg                  m_rready,
                    input wire [1:0]            m_rresp,
                    input wire                  m_rvalid,

                    output reg [DEST_WIDTH-1:0] m_awaddr,
                    input wire                  m_awready,
                    output reg                  m_awvalid,
                    output reg [2:0]            m_awprot,

                    output reg [31:0]           m_wdata,
                    input wire                  m_wready,
                    output reg [3:0]            m_wstrb,
                    output reg                  m_wvalid,

                    // slave (from)
	                input wire [31:0]           s_araddr,
	                output reg                  s_arready,
	                input wire                  s_arvalid,
	                input wire [2:0]            s_arprot, 

	                input wire                  s_bready,
	                output reg [1:0]            s_bresp,
	                output reg                  s_bvalid,

	                output reg [31:0]           s_rdata,
	                input wire                  s_rready,
	                output reg [1:0]            s_rresp,
	                output reg                  s_rvalid,

	                input wire [31:0]           s_awaddr,
	                output reg                  s_awready,
	                input wire                  s_awvalid,
	                input wire [2:0]            s_awprot, 

	                input wire [31:0]           s_wdata,
	                output reg                  s_wready,
	                input wire [3:0]            s_wstrb,
	                input wire                  s_wvalid);
   
   wire [31:0]                                  s_araddr_proceeded =  s_araddr - BASE + OFFSET;
   wire [31:0]                                  s_awaddr_proceeded = s_awaddr - BASE + OFFSET;

   task init;
      begin
         s_arready <= 1'b1;
         
         s_bresp <= 2'b0;
         s_bvalid <= 1'b0;

         s_rdata <= 32'b0;
         s_rresp <= 2'b0;
         s_rvalid <= 1'b0;
         
         s_awready <= 1'b1;
         s_wready <= 1'b1;

         m_araddr <= 0;
         m_arvalid <= 1'b0;
         m_arprot <= 3'b0;

         m_bready <= 1'b0;
         
         m_rready <= 1'b0;

         m_awaddr <= 0;
         m_awvalid <= 1'b0;
         m_awprot <= 3'b0;

         m_wdata <= 32'b0;
         m_wstrb <= 4'b0;
         m_wvalid <= 1'b0;         
      end
   endtask
   
   always @(posedge clk) begin
      if (rstn) begin
         // read
         if (s_arready && s_arvalid) begin
            s_arready <= 1'b0;
            
            m_arvalid <= 1'b1;
            m_araddr <= s_araddr_proceeded[DEST_WIDTH-1:0];
            m_arprot <= s_arprot;
         end
         if (m_arvalid && m_arready) begin
            m_arvalid <= 0;
            m_rready <= 1'b1;         
         end
         if (m_rready && m_rvalid) begin
            m_rready <= 1'b0;
            
            s_rvalid <= 1'b1;         
            s_rdata <= CHANGE_ENDIAN == 0? m_rdata : to_le32(m_rdata);
            s_rresp <= m_rresp;
         end
         if (s_rvalid && s_rready) begin
            s_rvalid <= 1'b0;
            s_arready <= 1'b1;         
         end

         // write
         if (s_awready && s_awvalid) begin
            s_awready <= 1'b0;
            
            m_awvalid <= 1'b1;
            m_awaddr <= s_awaddr_proceeded[DEST_WIDTH-1:0];
            m_awprot <= s_awprot;
         end            
         if (s_wready && s_wvalid) begin
            s_wready <= 1'b0;
            
            m_wvalid <= 1'b1;         
            m_wdata <= CHANGE_ENDIAN == 0? s_wdata : to_le32(s_wdata);
            m_wstrb <= s_wstrb;
         end
         if (m_awvalid && m_awready) begin
            m_awvalid <= 1'b0;
         end
         if (m_wvalid && m_wready) begin
            m_wvalid <= 1'b0;
         end
         if (!s_awready && !s_wready) begin
            m_bready <= 1'b1;         
         end
         if (m_bready && m_bvalid) begin
            m_bready <= 1'b0;

            s_bvalid <= 1'b1;         
            s_bresp <= m_bresp;
            s_bvalid <= m_bvalid;
         end
         if (s_bvalid && s_bready) begin
            s_bvalid <= 1'b0;

            s_awready <= 1'b1;
            s_wready <= 1'b1;
         end
      end else begin
         init();
      end         
   end
endmodule

`default_nettype wire
