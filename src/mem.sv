`default_nettype none
`include "def.sv"

module mem(
           input wire        clk,
           input wire        rstn,

           // control flags
           input wire        enabled,
           output reg        completed,

           // bus
           output reg        request_enable,
           output reg        mode,
           output reg [31:0] addr,
           output reg [31:0] wdata,
           output reg [3:0]  wstrb, 
           input wire        response_enable,
           input wire [31:0] data,

           // input
           input             instructions instr,
           input             regvpair register,
           input wire [31:0] arg,
           input wire        is_a_read,
           input wire        is_a_write,

           // output
           output reg [31:0] result,
           output reg flush_tlb);


   localparam WAITING_REQUEST = 0;
   localparam WAITING_DONE = 1;
   (* mark_debug = "true" *) reg                       state;

   task init;
      begin
         request_enable <= 0;
         mode <= 0;
         addr <= 0;
         wdata <= 0;
         wstrb <= 0;
         
         completed <= 0;
         state <= WAITING_REQUEST;
      end
   endtask

   initial begin
      init();
   end
   // NOTE: amo* uses register.rs1 to tell the address and others use arg.
   // TODO(linux): fix endian
   wire [31:0] _addr = (is_a_write|is_a_read)? register.rs1 : arg;
   always @(posedge clk) begin
      if(rstn) begin
         if (state == WAITING_REQUEST && enabled) begin
            if (instr.sfence_vma) begin
               completed <= 0;
               flush_tlb <= 1;
               state <= WAITING_DONE;
               // dummy
               mode <= MEMREQ_READ;
               addr <= 32'b0;
               request_enable <= 1;
            end else if (instr.is_load || is_a_read) begin
               completed <= 0;

               state <= WAITING_DONE;
               mode <= MEMREQ_READ;
               addr <= {_addr[31:2], 2'b0};
               request_enable <= 1;
            end else if (instr.is_store || is_a_write) begin
               completed <= 0;

               state <= WAITING_DONE;
               mode <= MEMREQ_WRITE;
               addr <= {_addr[31:2], 2'b0};
               if(instr.sb) begin
                  case(_addr[1:0])
                    2'b00 : begin
                       wstrb <= 4'b1000;
                       wdata <= {register.rs2[7:0], 24'b0};
                    end
                    2'b01 : begin
                       wstrb <= 4'b0100;
                       wdata <= {8'b0, register.rs2[7:0], 16'b0};
                    end
                    2'b10 : begin
                       wstrb <= 4'b0010;
                       wdata <= {16'b0, register.rs2[7:0], 8'b0};
                    end
                    2'b11 : begin
                       wstrb <= 4'b0001;
                       wdata <= {24'b0, register.rs2[7:0]};
                    end
                  endcase
               end else if (instr.sh) begin
                  case(_addr[1:0])
                    2'b00 : begin
                       wstrb <= 4'b1100;
                       wdata <= {to_le16(register.rs2[15:0]), 16'b0};
                    end
                    2'b10 : begin
                       wstrb <= 4'b0011;
                       wdata <= {16'b0, to_le16(register.rs2[15:0])};
                    end
                  endcase
               end  else if (instr.sw) begin
                  wstrb <= 4'b1111;
                  wdata <= to_le32(register.rs2);
               end else if (is_a_write) begin
                  wstrb <= 4'b1111;
                  wdata <= to_le32(arg);
               end
               request_enable <= 1;               
            end else begin
               // including sfence.vma
               result <= arg;
               completed <= 1;
            end
         end else if (state == WAITING_DONE && response_enable) begin
            completed <= 1;
            state <= WAITING_REQUEST;
            if (instr.sfence_vma) begin
               flush_tlb <= 1'b0;
            end if (instr.lb) begin
               case(_addr[1:0])
                 2'b00: result <= {{24{data[31]}}, data[31:24]};
                 2'b01: result <= {{24{data[23]}}, data[23:16]};
                 2'b10: result <= {{24{data[15]}}, data[15:8]};
                 2'b11: result <= {{24{data[7]}}, data[7:0]};
                 default: result <= 32'b0;
               endcase
            end else if (instr.lh) begin
               case(_addr[1:0])
                 2'b00 : result <= {{16{data[23]}}, to_le16(data[31:16])};
                 2'b10 : result <= {{16{data[7]}}, to_le16(data[15:0])};
                 default: result <=  32'b0;
               endcase
            end else if (instr.lw) begin
               result <= to_le32(data);
            end else if (instr.lbu) begin
               case(_addr[1:0])
                 2'b00: result = {24'b0, data[31:24]};
                 2'b01: result <= {24'b0, data[23:16]};
                 2'b10: result <= {24'b0, data[15:8]};
                 2'b11: result <= {24'b0, data[7:0]};
                 default: result <= 32'b0;
               endcase
            end else if (instr.lhu) begin
               case(_addr[1:0])
                 2'b00 : result <= {16'b0, to_le16(data[31:16])};
                 2'b10 : result <= {16'b0, to_le16(data[15:0])};
                 default: result <= 32'b0;
               endcase 
            end else if (is_a_read) begin
               result <= to_le32(data);               
            end else begin
               result <= 32'b0;
            end
         end else begin
            request_enable <= 0;
            completed <= 0;
         end
      end else begin
         init();
      end
   end
endmodule
`default_nettype wire
