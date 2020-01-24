`default_nettype none
`include "def.sv"

module execute
  (input wire clk,
   input wire        rstn,

   // control flags
   input wire        enabled,
   output reg        completed,

   // bus
   // none

   // input
   input             instructions instr,
   input             regvpair register,

   // output
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

   task init;
      begin
         completed <= 0;
      end
   endtask


   initial begin
      init();
   end

   always @(posedge clk) begin
      if (rstn) begin
         if (enabled) begin
            completed <= 0;
            instr_n <= instr;
            register_n <= register;
         end else if (alu_completed) begin
            completed <= 1;
            result <= alu_result;

            is_jump_chosen <= (instr.jal
                               || instr.jalr)
              || (instr.is_conditional_jump && alu_result == 32'd1);

            jump_dest <= instr.jal? instr.pc + $signed(instr.imm):
                         instr.jalr? (register.rs1 + $signed(instr.imm)) & ~(32'b1):
                         (instr.is_conditional_jump && alu_result == 32'd1)? instr.pc + $signed(instr.imm):
                         0;
            // TODO: rv32i
            // TODO: rv32a
            // TODO: rv32s
         end else begin
            completed <= 0;
         end
      end else begin
         init();
      end
   end
endmodule // execute
`default_nettype wire
