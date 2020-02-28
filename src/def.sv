`ifndef _DEFINITION_
 `define _DEFINITION_ 1

typedef struct {
   reg [31:0]  rs1;
   reg [31:0]  rs2;
} regvpair;

typedef enum reg [1:0]      {
                             CPU_U = 2'b00, 
                             CPU_S = 2'b01, 
                             CPU_RESERVED = 2'b10, 
                             CPU_M = 2'b11
                             } cpu_mode_t;

function [31:0] to_le32(input [31:0] data);
   begin
      to_le32 = {data[7:0], data[15:8], data[23:16], data[31:24]};      
   end
endfunction

function [15:0] to_le16(input [15:0] data);
   begin
      to_le16 = {data[7:0], data[15:8]};      
   end
endfunction
    
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
   reg [6:0]   funct7;
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
   // other
   reg         fence;
   reg         fencei;
   reg         ecall;
   reg         ebreak;
   reg         csrrw;
   reg         csrrs;
   reg         csrrc;
   reg         csrrwi;
   reg         csrrsi;
   reg         csrrci;

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
   reg         lr;
   reg         sc;
   reg         amoswap;
   reg         amoadd;
   reg         amoxor;
   reg         amoand;
   reg         amoor;
   reg         amomin;
   reg         amomax;
   reg         amominu;
   reg         amomaxu;   
   
   /////////
   // rv32s
   /////////
   reg         sret;
   reg         mret;
   reg         wfi;
   reg         sfence_vma;   

   /////////
   // other controls
   /////////
   reg         rv32a;
   reg         csrop;         
   reg         writes_to_reg;
   reg         writes_to_csr;
   reg         is_store;
   reg         is_load;
   reg         is_conditional_jump;
} instructions;
`endif
