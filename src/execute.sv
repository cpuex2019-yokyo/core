`default_nettype none
`include "def.sv"

module execute
  (input wire clk,
   input wire        rstn,
     
   input wire        enabled,
   input             instructions instr,
   input             regvpair register,
  
   output wire       completed,
   output            instructions instr_n,
   output            regvpair register_n,

   output reg [31:0] result,
   output reg        is_jump_chosen,
   output reg [31:0] jump_dest);

   wire [31:0]       alu_result;
   wire              alu_completed;   
   alu _alu(.clk(clk),
            .rstn(rstn),
            .enabled(enabled),
      
            .instr(instr),
            .register(register),
      
            .completed(alu_completed),      
            .result(alu_result));
   
   reg               _completed;
   assign completed = _completed & !enabled;
   
   always @(posedge clk) begin
      if (rstn) begin
         if (enabled) begin
            instr_n <= instr;
            register_n <= register;            
            _completed <= 0;
         end else if (alu_completed) begin            
            result <= alu_result;
            _completed <= 1;            
            
            is_jump_chosen <= (instr.jal 
                               || instr.jalr) 
              || (instr.is_conditional_jump && alu_result == 32'd1);
            
            jump_dest <= instr.jal? instr.pc + $signed(instr.imm):
                         instr.jalr? (register.rs1 + $signed(instr.imm)) & ~(32b'0): // TODO
                         (instr.is_conditional_jump && alu_result == 32'd1)? instr.pc + $signed(instr.imm):
                         0;                        
         end else begin
            _completed <= 0;            
         end
      end else begin
         _completed <= 0;
      end
   end  
endmodule // execute
`default_nettype none
