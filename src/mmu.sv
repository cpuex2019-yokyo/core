`default_nettype none
`include "def.sv"

module mmu(
           input wire        clk,
           input wire        rstn,

           input wire        fetch_request_enable,
           input             fetch_request,
           input wire        freq_mode,
           input wire [31:0] freq_addr,
           input wire [31:0] freq_wdata,
           input wire [3:0]  freq_wstrb,
           output reg        fetch_response_enable,
           output reg [31:0] fresp_data,


           input wire        mem_request_enable,
           input             mem_request,
           input wire        mreq_mode,
           input wire [31:0] mreq_addr,
           input wire [31:0] mreq_wdata,
           input wire [3:0]  mreq_wstrb,
           output reg        mem_response_enable,
           output reg [31:0] mresp_data,

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


   typedef enum reg [3:0]    {WAITING_REQUEST, WAITING_MEM_RREADY, WAITING_MEM_WREADY, WAITING_MEM_RVALID, WAITING_MEM_BVALID} memistate_t;
   memistate_t                 state;

   typedef enum reg          {CAUSE_FETCH, CAUSE_MEM} memicause_t;
   memicause_t cause;

   task init;
      begin
         axi_wvalid <= 0;
         axi_awvalid <= 0;
         axi_arvalid <= 0;
         axi_bready <= 0;
         axi_rready <= 0;
      end
   endtask

   initial begin
      init();
   end

   always @(posedge clk) begin
      if(rstn) begin
         if (state == WAITING_REQUEST) begin
            if (fetch_request_enable) begin
               cause <= CAUSE_FETCH;
               if (fetch_request.mode == MEMREQ_READ) begin
                  axi_araddr <= fetch_request.addr;
                  axi_arprot <= 3'b000;
                  axi_arvalid <= 1;
                  state <= WAITING_MEM_RREADY;
               end else begin
                  axi_awaddr <= fetch_request.addr;
                  axi_awprot <= 3'b000;
                  axi_awvalid <= 1;
                  axi_wstrb <= fetch_request.wstrb;
                  axi_wdata <= fetch_request.wdata;
                  state <= WAITING_MEM_RVALID;
               end
            end else if (mem_request_enable) begin
               cause <= CAUSE_MEM;
               if (mem_request.mode == MEMREQ_READ) begin
                  axi_araddr <= mem_request.addr;
                  axi_arprot <= 3'b000;
                  axi_arvalid <= 1;
                  state <= WAITING_MEM_RREADY;
               end else begin
                  axi_awaddr <= fetch_request.addr;
                  axi_awprot <= 3'b000;
                  axi_awvalid <= 1;
                  axi_wstrb <= fetch_request.wstrb;
                  axi_wdata <= fetch_request.wdata;
                  state <= WAITING_MEM_RVALID;
               end
            end
         end else if (state == WAITING_MEM_RREADY) begin
            if (axi_arready) begin
               axi_arvalid <= 0;
               axi_rready <= 1;
               state <= WAITING_MEM_RVALID;
            end
         end else if (state == WAITING_MEM_RVALID) begin
            if (axi_rvalid) begin
               axi_rready <= 0;
               if (cause == CAUSE_FETCH) begin
                  fetch_response.data <= axi_rdata;
                  fetch_response_enable <= 1;
               end else begin
                  mem_response.data <= axi_rdata;
                  mem_response_enable <= 1;
               end
            end
         end else if (state == WAITING_MEM_WREADY) begin
            if(axi_awready) begin
               axi_awvalid <= 0;
            end
            if(axi_wready) begin
               axi_wvalid <= 0;
            end
            if(!axi_awvalid && !axi_wvalid) begin
               axi_bready <= 1;
               state <= WAITING_MEM_BVALID;
            end
         end else if (state == WAITING_MEM_BVALID) begin
            if (axi_bvalid) begin
               axi_bready <= 0;
               if (cause == CAUSE_FETCH) begin
                  fetch_response_enable <= 1;
               end else begin
                  mem_response_enable <= 1;
               end
            end
         end
      end else begin
         init();
      end
   end
endmodule
`default_nettype wire
