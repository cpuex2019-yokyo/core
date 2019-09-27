module alu 
  (input wire        clk,
   input wire        rstn,
     
   input             instructions instr,

   input wire [31:0] rs1_v,
   input wire [31:0] rs2_v,
   input wire [31:0] imm,

   output reg [31:0] result

   );

   always @(posedge clk) begin
      result <= instr.addi? $signed(rs1_v) + $signed(imm):
                instr.add? $signed(rs1_v) + $signed(rs2_v):      
                instr.beq? (rs1_v == rs2_v):
                31'b0;      
   end
endmodule
