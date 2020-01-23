`default_nettype none
`include "def.sv"

module fetch
  (input wire         clk,
   input wire        rstn,

   // control flags
   input wire        enabled,
   output reg        completed,

   // bus
   output reg        request_enable,
   output            memreq request,
   input wire        response_enable,
   input             memresp response,   

   // input
   input wire [31:0] pc,
  
   // output
   output reg [31:0] pc_n,
   output reg [31:0] instr_raw);

   
   localparam WAITING_REQUEST = 0;
   localparam WAITING_DONE = 1;
   reg               state;

   task init;
      begin
         completed <= 0;      
         state <= WAITING_REQUEST;         
      end
   endtask
   
   initial begin
      init();      
   end
   
   always @(posedge clk) begin
      if(rstn) begin
         if (state == WAITING_REQUEST && enabled) begin
            completed <= 0;
            
            state <= WAITING_DONE;
            request.mode <= MEMREQ_READ;
            request.addr <= pc;            
            request_enable <= 1;            
            pc_n <= pc;
         end else if (state == WAITING_DONE && response_enable) begin
            completed <= 1;
            
            state <= WAITING_REQUEST;
            instr_raw <= response.data;            
         end else begin
            completed <= 0;            
         end
      end else begin
         init();
      end      
   end
endmodule
`default_nettype wire
