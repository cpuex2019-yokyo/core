`default_nettype none

module bram(
	        input wire        clk,
	        input wire        rstn,

            output reg [31:0] addra,
            output wire       clka,
            output reg [31:0] dina,
            input wire [31:0] douta,
            output reg        ena,
            output wire       rsta,
            output reg [3:0]  wea,
            

	        input wire [31:0] axi_araddr,
	        output reg        axi_arready,
	        input wire        axi_arvalid,
	        input wire [2:0]  axi_arprot, 

	        input wire        axi_bready,
	        output reg [1:0]  axi_bresp,
	        output reg        axi_bvalid,

	        output reg [31:0] axi_rdata,
	        input wire        axi_rready,
	        output reg [1:0]  axi_rresp,
	        output reg        axi_rvalid,

	        input wire [31:0] axi_awaddr,
	        output reg        axi_awready,
	        input wire        axi_awvalid,
	        input wire [2:0]  axi_awprot, 

	        input wire [31:0] axi_wdata,
	        output reg        axi_wready,
	        input wire [3:0]  axi_wstrb,
	        input wire        axi_wvalid);
   

   reg [4:0]                  state;
   localparam WAITING_QUERY = 0;
   localparam WAITING_MEM1 = 1;
   localparam WAITING_MEM2 = 2;
   localparam WAITING_RREADY = 3;   
   localparam WAITING_WROTE = 4;   
   localparam WAITING_BREADY = 5;

   assign rsta = !rstn;
   assign clka = clk;   
   
   
   initial begin
      axi_arready <= 1;

      axi_bresp <= 2'b0;            
      axi_bvalid <= 0;

      axi_rdata <= 32'b0;
      axi_rresp <= 2'b0;      
      axi_rvalid <= 0;      
      
      axi_awready <= 1;
      
      axi_wready <= 1;         
   end
   
   always @(posedge clk) begin
      if(rstn) begin
         if (state == WAITING_QUERY) begin
            if (axi_arvalid) begin
               axi_arready <= 0;
               addra <= axi_araddr;  
               ena <= 1;             
               state <= WAITING_MEM1;
            end else if (axi_wvalid) begin
               axi_wready <= 0;
               dina <= axi_wdata;      
               wea <= axi_wstrb;         
            end else if (axi_awvalid) begin
               axi_awready <= 0;  
               addra <= axi_awaddr;               
            end else if (!axi_awready && !axi_wready) begin
               ena <= 1;
               state <= WAITING_WROTE;               
            end            
         end else if (tate == WAITING_MEM1) begin
            ena <= 0;
            state <= WAITING_MEM2;            
         end if (state == WAITING_MEM2) begin
            axi_rvalid <= 1;
            axi_rdata <= douta;
            state <= WAITING_RREADY;
         end if (state == WAITING_RREADY) begin
            if (axi_rready) begin
               axi_rvalid <= 0;
               axi_arready <= 1;
               state <= WAITING_QUERY;               
            end
         end if (state == WAITING_WROTE) begin            
            ena <= 0;
            axi_bresp <= 2'b0;
            axi_bvalid <= 1;            
            state <= WAITING_BREADY;            
         end  if (state == WAITING_BREADY) begin
            if (axi_bready) begin
               axi_bvalid <= 0;
               axi_awready <= 1;
               axi_wready <= 1;               
               state <= WAITING_QUERY;               
            end
         end
      end
   end                    
endmodule
`default_nettype wire
