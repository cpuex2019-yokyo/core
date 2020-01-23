`default_nettype none
`include "def.sv"

module regf
  (input wire         clk,
   input wire        rstn,
   input wire [31:0] pc,
   input wire        r_enabled,
  
   input wire [4:0]  rs1,
   input wire [4:0]  rs2,

   output            regvpair register,

   input wire        w_enable,
   input wire [4:0]  w_addr,
   input wire [31:0] w_data);
   
   (* mark_debug = "true" *) reg [31:0]        regs[32];
   
   integer           i;
   initial begin
      for (i=0; i<32; i++) begin
         regs[i] <= 0;
      end
   end

   always @(posedge clk) begin
      if(rstn) begin
         if (r_enabled) begin
            register.rs1 <= w_enable && w_addr != 0 && w_addr == rs1? w_data : regs[rs1];         
            register.rs2 <= w_enable && w_addr != 0 && w_addr == rs2? w_data : regs[rs2];         
         end
         if(w_enable) begin
            if(w_addr != 0) begin
               regs[w_addr] <= w_data;  
            end       
         end
      end else begin
         register.rs1 <= 0;
         register.rs2 <= 0;         
      end
   end   
endmodule

`default_nettype wire
