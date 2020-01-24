`ifndef _DEFINITION_
 `define _DEFINITION_ 1

typedef struct {
   reg [31:0]  rs1;
   reg [31:0]  rs2;
} regvpair;

parameter MEMREQ_READ = 0;
parameter MEMREQ_WRITE = 1;

typedef struct {
   /////////
   // decoded metadata
   /////////
   reg [4:0]   rd;
   reg [4:0]   rs1;
   reg [4:0]   rs2;
   reg [31:0]  imm;
   reg [31:0]  pc;

   /////////
   // rv32i
   /////////
   // lui, auipc
   reg         lui;
   reg         auipc;
   // jumps
   reg         jal;
   reg         jalr;
   // conditional breaks
   reg         beq;
   reg         bne;
   reg         blt;
   reg         bge;
   reg         bltu;
   reg         bgeu;
   // memory control
   reg         lb;
   reg         lh;
   reg         lw;
   reg         lbu;
   reg         lhu;
   reg         sb;
   reg         sh;
   reg         sw;
   // arith immediate
   reg         addi;
   reg         slti;
   reg         sltiu;
   reg         xori;
   reg         ori;
   reg         andi;
   reg         slli;
   reg         srli;
   reg         srai;
   // arith other
   reg         add;
   reg         sub;
   reg         sll;
   reg         slt;
   reg         sltu;
   reg         i_xor;
   reg         srl;
   reg         sra;
   reg         i_or;
   reg         i_and;

   // TODO

   /////////
   // rv32m
   /////////
   reg         mul;
   reg         mulh;
   reg         mulhsu;
   reg         mulhu;
   reg         div;
   reg         divu;
   reg         rem;
   reg         remu;

   /////////
   // rv32a
   /////////
   // TODO

   /////////
   // rv32s
   /////////
   // TODO

   /////////
   // other controls
   /////////
   reg         writes_to_reg;

   reg         is_store;
   reg         is_load;
   reg         is_conditional_jump;
} instructions;
`endif
