`default_nettype none
`include "def.sv"

module write(
             input wire         clk,
             input wire         rstn,
             input wire         enabled,

             input              instructions instr,
             input wire [31:0]  data,

             output wire        reg_w_enable,

             output wire [4:0]  reg_w_dest,
             output wire [31:0] reg_w_data,

             output wire        completed);
   
   reg _completed;
   assign completed = _completed & !enabled;
   
   assign reg_w_enable = enabled &&  instr.writes_to_reg;   

   assign reg_w_dest = instr.rd;
   assign reg_w_data = data;   

   initial begin
      _completed <= 1;      
   end
   
   always @(posedge clk) begin
      if (rstn) begin
         if(enabled) begin
            _completed <= 1;
         end
      end else begin
         _completed <= 0;         
      end
   end
endmodule // execute
`default_nettype none
