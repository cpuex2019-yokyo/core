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


wire [31:0]       _result =
     instr.lui? instr.imm:
     instr.auipc? $signed(instr.imm) + instr.pc:
     // jumps
     instr.jal? instr.pc + 4:
     instr.jalr? instr.pc + 4:
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
     instr.srai? $signed(register.rs1) << instr.imm[4:0]:
     // arith others
     instr.add? $signed(register.rs1) + $signed(register.rs2):
     instr.sub? $signed(register.rs1) - $signed(register.rs2):
     instr.sll? register.rs1 << register.rs2:
     instr.slt? $signed(register.rs1) < $signed(register.rs2):
     instr.sltu? $signed(register.rs1) < $signed(register.rs2):
     instr.i_xor? register.rs1 ^ register.rs2:
     instr.srl? register.rs1 >> register.rs2[4:0]:
     instr.sra? $signed(register.rs1) >>> register.rs2[4:0]:
     instr.i_or? register.rs1 | register.rs2:
     instr.i_and? register.rs1 & register.rs2:
     ///// rv32m /////
     // seems to be buggy; not fully tested yet.
     instr.mul? mul_temp[31:0]:
     instr.mulh? mul_temp[63:32]:
     instr.mulhsu? mul_temp_hsu[63:32]:
     instr.mulhu? mul_temp_hu[63:32]:
     instr.div? $signed(register.rs1) / $signed(register.rs2):
     instr.divu? register.rs1 / register.rs2:
     instr.rem? $signed(register.rs1) % $signed(register.rs2):
     instr.remu? register.rs1 % register.rs2:
     31'b0;

always @(posedge clk) begin
    if (rstn) begin
        if (enabled) begin
            result <= _result;
            completed <= 1;
        end
    end else begin
        completed <= 0;
    end
end

endmodule
`default_nettype wire
