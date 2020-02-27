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


   enum reg [2:0]    {WAITING, MULDIV} state;

   //div & mul module
   reg               mul_enabled;   
   wire              mul_completed;   
   reg               mul_is_signed;   
   reg [31:0]        mul_op1;
   reg [31:0]        mul_op2;
   wire [31:0]       mul_result;
   mul _mul(.clk(clk),
            .enable(mul_enabled),
            .completed(mul_completed),
            .is_signed(mul_is_signed),
            .s(mul_op1),
            .t(mul_op2),
            .d(mul_result));
   
   reg               div_enabled;   
   wire              div_completed;   
   reg               div_is_signed;   
   reg [31:0]        div_dividend;
   reg [31:0]        div_divisor;   
   wire [31:0]       div_quotient;
   wire [31:0]       div_remainder;   
   div _div(.clk(clk),
            .enable(div_enabled),
            .completed(div_completed),
            .is_signed(div_is_signed),
            .s(div_dividend),
            .t(div_divisor),
            .q(div_quotient),
            .r(div_remainder));

   

   // tmp module
   wire [63:0]       mul_temp = $signed({{32{register.rs1[31]}}, register.rs1}) * $signed({{32{register.rs2[31]}}, register.rs2});
   wire [63:0]       mul_temp_hsu = $signed({{32{register.rs1[31]}}, register.rs1}) * $signed({32'b0, register.rs2});
   wire [63:0]       mul_temp_hu = $signed({32'b0, register.rs1}) * $signed({32'b0, register.rs2});
   wire [63:0]       _extended_rs1 = {{32{register.rs1[31]}}, register.rs1};
   wire [63:0]       _tmp_srai = _extended_rs1 >> instr.imm[4:0];
   wire [63:0]       _tmp_sra = _extended_rs1 >> register.rs2[4:0];   

   // init utility
   task init;
      begin
         state <= WAITING;

         mul_enabled <= 1'b0;
         mul_is_signed <= 1'b0;
         mul_op1 <= 32'b0;
         mul_op2 <= 32'b0;         
         
         div_enabled <= 1'b0;
         div_is_signed <= 1'b0;
         div_dividend <= 32'b0;
         div_divisor <= 32'b1;         
      end
   endtask  

   task be_quiet;      
      begin
         completed <= 0;
         mul_enabled <= 1'b0;            
         div_enabled <= 1'b0;
      end
   endtask // be_quiet

   // bit util
   function [31:0] abs32(input [31:0] v);
      begin
         abs32 = v[31] ? (~v + 32'b1) :
                 v;         
      end
   endfunction

   function [63:0] u64_to_s64(input sign, input [31:0] v);
      begin
         u64_to_s64 = sign? ~v + 64'b1:
                      v;         
      end
   endfunction

   function [31:0] upper32(input [63:0] v);
      begin
         upper32 = v[63:32];         
      end
   endfunction
   
   // main logic
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
                     // zero division does not cause any exceptions in RISC-V
                     // instr.mul? mul_temp[31:0]:
                     // instr.mulh? mul_temp[63:32]:
                     // instr.mulhsu? mul_temp_hsu[63:32]:
                     // instr.mulhu? mul_temp_hu[63:32]:
                     // instr.div? div32(register.rs1, register.rs2):
                     // instr.rem? rem32(register.rs1, register.rs2):
                     // instr.divu? divu32(register.rs1, register.rs2):
                     // instr.remu? remu32(register.rs1, register.rs2):
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
         if (state == WAITING && enabled) begin
            if (instr.mul | instr.mulh | instr.mulhsu | instr.mulhu) begin
               completed <= 0;
               state <= MULDIV;

               if (instr.mul | instr.mulh) begin
                  mul_op1 <= register.rs1;
                  is_signed <= 1;                  
               end else if (instr.mulhsu) begin
                  mul_op1 <= abs32(register.rs1);                  
                  is_signed <= 0;                  
               end else if (instr.mulhu) begin
                  mul_op1 <= register.rs1;                  
                  is_signed <= 0;                  
               end 
               mul_op2 <= register.rs2;               
            end else if (instr.div) begin
               if (register.rs2 == 32'b0) begin
                  completed <= 1;
                  result <= (~32'b0);
               end else if (register.rs1 == 32'h80000000 && register.rs2 == ~(32'b0)) begin
                  completed <= 1;                  
                  result <= register.rs1;
               end else begin
                  completed <= 0;
                  state <= MULDIV;
                  
                  div_enabled <= 1'b1;
                  div_is_signed <= 1'b1;
                  div_dividend <= register.rs1;
                  div_divisor <= register.rs2;                  
               end               
            end else if (instr.divu) begin
               if (register.rs2 == 32'b0) begin
                  completed <= 1;
                  result <= (~32'b0);
               end else begin
                  completed <= 0;                  
                  state <= MULDIV;
                  
                  div_enabled <= 1'b1;
                  div_is_signed <= 1'b0;
                  div_dividend <= register.rs1;
                  div_divisor <= register.rs2;                  
               end               
            end else if (instr.rem) begin
               if (register.rs2 == 32'b0) begin
                  completed <= 1;
                  result <= register.rs1;
               end else if (register.rs1 == 32'h80000000 && register.rs2 == ~(32'b0)) begin
                  completed <= 1;                  
                  result <= 32'b0;                  
               end else begin
                  completed <= 0;                  
                  state <= MULDIV;
                  
                  div_enabled <= 1'b1;
                  div_is_signed <= 1'b1;
                  div_dividend <= register.rs1;
                  div_divisor <= register.rs2;                  
               end               
            end else if (instr.remu) begin // if (instr.rem)
               if (register.rs2 == 32'b0) begin
                  completed <= 1;
                  result <= register.rs1;                  
               end else begin
                  completed <= 0;                  
                  state <= MULDIV;    
                  
                  div_enabled <= 1'b1;
                  div_is_signed <= 1'b0;
                  div_dividend <= register.rs1;
                  div_divisor <= register.rs2;
               end                              
            end else begin 
               // for rv32iasu instructions, _result is the result.
               completed <= 1;               
               result <= _result;
            end
         end else if (state == MULDIV) begin // else: !if(state == WAITING && enabled)
            if (div_completed) begin
               completed <= 1'b1;          
               state <= WAITING;
               
               if (instr.div | instr.divu) begin
                  result <= div_quotient;                  
               end else if (instr.rem | instr.remu) begin
                  result <= div_remainder;                  
               end
            end else if (mul_completed) begin
               completed <= 1'b1;               
               state <= WAITING;

               if (instr.mul) begin
                  result <= mul_result[31:0];                  
               end else if (instr.mulh) begin
                  result <= mul_result[63:32];                  
               end else if (instr.mulhsu) begin
                  result <= upper32(u64_to_s64(register.rs1[31], mul_result));                 
               end else if (instr.mulhu) begin
                  result <= mul_result[63:32];                  
               end
            end else begin
               be_quiet();            
            end
         end else begin // if (state == MULDIV)
            be_quiet();            
         end
      end else begin
         init();         
      end
   end
endmodule
`default_nettype wire
