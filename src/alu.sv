`default_nettype none
`include "def.sv"

module alu
  (input wire        clk,
   input wire        rstn,
   input wire        enabled,

   input             instructions instr,
   input             regvpair register,

   output reg        completed,
   output reg [31:0] result);

   wire [63:0]       mul_temp = $signed({{32{register.rs1[31]}}, register.rs1}) * $signed({{32{register.rs2[31]}}, register.rs2});
   wire [63:0]       mul_temp_hsu = $signed({{32{register.rs1[31]}}, register.rs1}) * $signed({32'b0, register.rs2});
   wire [63:0]       mul_temp_hu = $signed({32'b0, register.rs1}) * $signed({32'b0, register.rs2});

   wire [63:0] _extended_rs1 = {{32{register.rs1[31]}}, register.rs1};
   wire [63:0] _tmp_srai = _extended_rs1 >> instr.imm[4:0];
   wire [63:0] _tmp_sra = _extended_rs1 >> register.rs2[4:0];
   
   wire [31:0]       _result =
                     instr.lui? instr.imm:
                     instr.auipc? $signed(instr.imm) + instr.pc:
                     // jumps
                     instr.jal? instr.pc + 4: // the value to be written to rd
                     instr.jalr? instr.pc + 4: // the value to be written to rd
                     // conditional breaks
                     instr.beq? (register.rs1 == register.rs2):
                     instr.bne? (register.rs1 != register.rs2):
                     instr.blt? ($signed(register.rs1) < $signed(register.rs2)):
                     instr.bge? ($signed(register.rs1) >= $signed(register.rs2)):
                     instr.bltu? register.rs1 < register.rs2:
                     instr.bgeu? register.rs1 >= register.rs2:
                     // memory control
                     instr.lb? $signed({1'b0, register.rs1}) + $signed(instr.imm):
                     instr.lh? $signed({1'b0, register.rs1}) + $signed(instr.imm):
                     instr.lw? $signed({1'b0, register.rs1}) + $signed(instr.imm):
                     instr.lbu? $signed({1'b0, register.rs1}) + $signed(instr.imm):
                     instr.lhu? $signed({1'b0, register.rs1}) + $signed(instr.imm):
                     instr.sb? $signed({1'b0, register.rs1}) + $signed(instr.imm):
                     instr.sh? $signed({1'b0, register.rs1}) + $signed(instr.imm):
                     instr.sw? $signed({1'b0, register.rs1}) + $signed(instr.imm):
                     // arith instr.immediate
                     instr.addi? $signed(register.rs1) + $signed(instr.imm):
                     instr.slti? $signed(register.rs1) < $signed(instr.imm):
                     instr.sltiu? register.rs1 < instr.imm:
                     instr.xori? register.rs1 ^ instr.imm:
                     instr.ori? register.rs1 | instr.imm:
                     instr.andi? register.rs1 & instr.imm:
                     instr.slli? register.rs1 << instr.imm[4:0]:
                     instr.srli? register.rs1 >> instr.imm[4:0]:
                     instr.srai? _tmp_srai[31:0]:
                     // arith others
                     instr.add? $signed(register.rs1) + $signed(register.rs2):
                     instr.sub? $signed(register.rs1) - $signed(register.rs2):
                     instr.sll? register.rs1 << register.rs2[4:0]:
                     instr.slt? $signed(register.rs1) < $signed(register.rs2):
                     instr.sltu? register.rs1 < register.rs2:
                     instr.i_xor? register.rs1 ^ register.rs2:
                     instr.srl? register.rs1 >> register.rs2[4:0]:
                     instr.sra? _tmp_sra[31:0]:
                     instr.i_or? register.rs1 | register.rs2:
                     instr.i_and? register.rs1 & register.rs2:
                     instr.fence? 32'b0: // NOTE: fence is nop in this implementation
                     instr.fencei? 32'b0: // NOTE: fencei is nop in this implementation
                     instr.ecall? 32'b0: // will be handed in core.sv
                     instr.ebreak? 32'b0: // will be handed in core.sv
                     instr.csrrw? 32'b0: // will be handed in core.sv
                     instr.csrrs? 32'b0: // will be handed in core.sv
                     instr.csrrc? 32'b0: // will be handed in core.sv
                     instr.csrrwi? 32'b0: // will be handed in core.sv
                     instr.csrrsi? 32'b0: // will be handed in core.sv
                     instr.csrrci? 32'b0: // will be handed in core.sv
                     ///// rv32m /////
                     // TODO: seems to be buggy; not fully tested yet.
                     instr.mul? mul_temp[31:0]:
                     instr.mulh? mul_temp[63:32]:
                     instr.mulhsu? mul_temp_hsu[63:32]:
                     instr.mulhu? mul_temp_hu[63:32]:
                     // zero division does not cause any exceptions in RISC-V
                     instr.div? (register.rs2 == 32'b0 ? $signed(~32'b0) : $signed(register.rs1) / $signed(register.rs2)):
                     instr.divu? (register.rs2 == 32'b0 ? (~32'b0) : register.rs1 / register.rs2):
                     instr.rem? (register.rs2 == 32'b0 ? register.rs1 : $signed(register.rs1) % $signed(register.rs2)):
                     instr.remu? (register.rs2 == 32'b0 ? register.rs1 : register.rs1 % register.rs2):                 
                     ///// rv32m /////
                     instr.amoswap? 32'b0: // will be handed in core.sv
                     instr.amoand? 32'b0: // will be handed in core.sv
                     instr.amoor? 32'b0: // will be handed in core.sv
                     instr.amoxor? 32'b0: // will be handed in core.sv
                     instr.amomax? 32'b0: // will be handed in core.sv
                     instr.amomin? 32'b0: // will be handed in core.sv
                     instr.amomaxu? 32'b0: // will be handed in core.sv
                     instr.amominu? 32'b0: // will be handed in core.sv
                     ///// rv32s /////
                     instr.sret? 32'b0: // will be handed in core.sv
                     instr.mret? 32'b0: // will be handed in core.sv
                     instr.wfi? 32'b0: // NOTE: wfi is nop in this implementation
                     instr.sfence_vma? 32'b0: // NOTE: sfence_vma is nop in this implementation
                     32'b0;

   always @(posedge clk) begin
      if (rstn) begin
         if (enabled) begin
            result <= _result;
            completed <= 1;
         end else begin
            completed <= 0;
         end
      end else begin
         completed <= 0;
      end
   end

endmodule
`default_nettype wire
