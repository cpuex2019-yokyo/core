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
           input wire        amo_read_stage,
           input wire        amo_write_stage,

           // output
           output reg [31:0] result,
           output reg        flush_tlb,

           output reg [4:0]  exception_vec,
           output reg [31:0] exception_tval,
           output reg        exception_enable);


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
         
         flush_tlb <= 1'b0;
         
         exception_vec <= 5'b0;
         exception_tval <= 32'b0;
         exception_enable <= 1'b0;
         
         completed <= 0;
         state <= WAITING_REQUEST;
      end
   endtask

   task raise_misaligned_exception(input [31:0] vaddr);      
      begin
         exception_enable <= 1'b1;         
         exception_vec <= (instr.is_load & !instr.lr)? 5'd4: // load address misaligned
                          5'd6; // store/amo misaligned
         exception_tval <= vaddr;         
      end
   endtask

   function [0:0] is_addr_misaligned(input [31:0] addr, input [2:0] width);
      begin
         is_addr_misaligned = (width == 3'd4 && addr[1:0] != 2'b0) || (width == 3'd2 && addr[0:0] != 1'b0);         
      end
   endfunction
   
   initial begin
      init();
   end
   
   // NOTE: amo* uses register.rs1 to tell the address and others use arg.
   wire [31:0] _addr = (instr.lr | instr.sc |  amo_read_stage | amo_write_stage)? register.rs1 : arg;
   wire [31:0] _data_to_write = (instr.sc | amo_write_stage)? arg : register.rs2;
   
   always @(posedge clk) begin
      if(rstn) begin
         if (state == WAITING_REQUEST && enabled) begin            
            if (instr.sfence_vma) begin
               completed <= 0;
               flush_tlb <= 1'b1;
               state <= WAITING_DONE;
               
               // dummy
               mode <= MEMREQ_READ;
               addr <= 32'b0;
               request_enable <= 1;
            end else if (is_addr_misaligned(_addr, 
                                            (instr.lw | instr.sw | instr.lr | instr.sc | amo_read_stage | amo_write_stage) ? 3'd4:
                                            (instr.lh | instr.lhu | instr.sh) ? 3'd2:
                                            3'd1)) begin
               raise_misaligned_exception(_addr);
               completed <= 1'b1;                
            end else begin
               exception_tval <= 32'b0;              
               exception_vec <= 5'b0;
               exception_enable <= 1'b0;

               if (instr.is_load || amo_read_stage) begin
                  completed <= 0;

                  state <= WAITING_DONE;
                  mode <= MEMREQ_READ;
                  addr <= {_addr[31:2], 2'b0};
                  request_enable <= 1;
               end else if (instr.is_store || amo_write_stage) begin
                  completed <= 0;

                  state <= WAITING_DONE;
                  mode <= MEMREQ_WRITE;
                  addr <= {_addr[31:2], 2'b0};
                  if(instr.sb) begin
                     case(_addr[1:0])
                       2'b00 : begin
                          wstrb <= 4'b1000;
                          wdata <= {_data_to_write[7:0], 24'b0};
                       end
                       2'b01 : begin
                          wstrb <= 4'b0100;
                          wdata <= {8'b0, _data_to_write[7:0], 16'b0};
                       end
                       2'b10 : begin
                          wstrb <= 4'b0010;
                          wdata <= {16'b0, _data_to_write[7:0], 8'b0};
                       end
                       2'b11 : begin
                          wstrb <= 4'b0001;
                          wdata <= {24'b0, _data_to_write[7:0]};
                       end
                     endcase
                  end else if (instr.sh) begin
                     case(_addr[1:0])
                       2'b00 : begin
                          wstrb <= 4'b1100;
                          wdata <= {to_le16(_data_to_write[15:0]), 16'b0};
                       end
                       2'b10 : begin
                          wstrb <= 4'b0011;
                          wdata <= {16'b0, to_le16(_data_to_write[15:0])};
                       end
                     endcase
                  end  else if (instr.sw) begin
                     wstrb <= 4'b1111;
                     wdata <= to_le32(_data_to_write);
                  end else if (amo_write_stage | instr.sc) begin
                     wstrb <= 4'b1111;
                     wdata <= to_le32(_data_to_write);
                  end
                  request_enable <= 1;               
               end else begin
                  // this is not a memory operation. pass through.
                  result <= arg;
                  completed <= 1;
               end
            end
         end else if (state == WAITING_DONE && response_enable) begin
            completed <= 1;
            state <= WAITING_REQUEST;
            if (instr.sfence_vma) begin
               flush_tlb <= 1'b0;
            end
            
            if (instr.sc) begin
               result <= 32'b0;               
            end else if (instr.lb) begin
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
            end else if (amo_read_stage | instr.lr) begin
               result <= to_le32(data);               
            end else begin
               result <= 32'b0;
            end
         end else begin
            // just waiting now...
            flush_tlb <= 1'b0;
            request_enable <= 0;
            completed <= 0;
         end
      end else begin
         init();
      end
   end
endmodule
`default_nettype wire
