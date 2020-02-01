`default_nettype none
`include "def.sv"

module cache(
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


   typedef enum reg [3:0]    {WAITING_REQUEST, WAITING_MEM_RREADY, WAITING_MEM_WREADY, WAITING_MEM_RVALID, WAITING_MEM_BVALID, WAITING_RECEIVE} memistate_t;
   (* mark_debug = "true" *) memistate_t                 state;

   task init;
      begin
         response_enable <= 0;
         resp_data <= 32'b0;
         
         axi_araddr <= 32'b0;
         axi_arvalid <= 0;
         axi_arprot <= 2'b0;
         
         axi_bready <= 0;
         
         axi_rready <= 0;
         
         axi_awaddr <= 32'b0;
         axi_awvalid <= 0;
         axi_awprot <= 2'b0;
         
         axi_wdata <= 32'b0;
         axi_wstrb <= 4'b0;
         axi_wvalid <= 0;
         
         state <= WAITING_REQUEST;
      end
   endtask

   initial begin
      init();
   end

   always @(posedge clk) begin
      if(rstn) begin
         if (state == WAITING_REQUEST) begin
            if (request_enable) begin
               if (req_mode == MEMREQ_READ) begin
                  axi_araddr <= req_addr;
                  axi_arprot <= 3'b000;
                  axi_arvalid <= 1;
                  state <= WAITING_MEM_RREADY;
                  // TODO: match with cache                  
               end else begin
                  axi_awaddr <= req_addr;
                  axi_awprot <= 3'b000;
                  axi_awvalid <= 1;
                  axi_wstrb <= req_wstrb;
                  axi_wdata <= req_wdata;
                  axi_wvalid <= 1;
                  state <= WAITING_MEM_WREADY;
                  // TODO: writethrough, hoge
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
               state <= WAITING_RECEIVE;
               axi_rready <= 0;
               resp_data <= axi_rdata;
               response_enable <= 1;
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
               response_enable <= 1;
               state <= WAITING_RECEIVE;              
            end
         end else if (state == WAITING_RECEIVE) begin
            response_enable <= 0;
            state <= WAITING_REQUEST;
         end
      end else begin
         init();
      end
   end
endmodule
`default_nettype wire
