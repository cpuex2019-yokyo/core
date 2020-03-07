`default_nettype none

module cache_bram (
	       input wire clk,
	       input wire rstn,

	       input wire ena,	  
	       input wire wea, 
	       input wire [5:0] addr,
	       input wire [533:0] din, 
	       output reg [533:0] dout);

   (* RAM_STYLE="BLOCK" *) reg [533:0] ram [0:63];
   // reg [533:0] 			  ram [0:63];

   task init;
      begin
   	 dout <= 534'b0;
      end
   endtask
   
   
   always  @(posedge  clk) begin
      if (rstn) begin
	 if (ena) begin
	    dout <= ram[addr];
	    if (wea) begin
	       ram[addr]  <=  din;
	    end
	 end
      end else begin
	 init();
      end
   end // always  @ (posedge  clk)

endmodule

`default_nettype wire
