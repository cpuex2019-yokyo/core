`default_nettype none
`include "def.sv"

module core
  (input wire clk, 
   input wire         rstn,

   // Bus for instr ROM
   output wire [31:0] rom_addr,
   input wire [31:0]  rom_data,
  
   // Bus for MMU
   // address read channel
   output reg [31:0]  axi_araddr,
   input wire         axi_arready,
   output reg         axi_arvalid,
   output reg [2:0]   axi_arprot, 

   // response channel
   output reg         axi_bready,
   input wire [1:0]   axi_bresp,
   input wire         axi_bvalid,

   // read data channel
   input wire [31:0]  axi_rdata,
   output reg         axi_rready,
   input wire [1:0]   axi_rresp,
   input wire         axi_rvalid,

   // address write channel
   output reg [31:0]  axi_awaddr,
   input wire         axi_awready,
   output reg         axi_awvalid,
   output reg [2:0]   axi_awprot, 

   // data write channel
   output reg [31:0]  axi_wdata,
   input wire         axi_wready,
   output reg [3:0]   axi_wstrb,
   output reg         axi_wvalid);
   
   
   /////////////////////
  // internals
   /////////////////////
   // TODO: use interface (including csr)
   reg [31:0]         pc;
   reg                stalling_for_mem_forwarding;
   
   /////////////////////
   // stages
   /////////////////////
   
   // fetch
   /////////
   // controls
   (* mark_debug = "true" *) reg                fetch_enabled;
   (* mark_debug = "true" *) reg                fetch_reset;   
   (* mark_debug = "true" *) wire               is_fetch_done;

   // pipeline regs
   // None
   
   // stage outputs
   wire [31:0]        pc_fd_out;
   wire [31:0]        instr_fd_out;
   
   fetch _fetch(.clk(clk),
                .rstn(rstn && !fetch_reset),
      
                .enabled(fetch_enabled),
                .pc(pc),

                .rom_addr(rom_addr),
                .rom_data(rom_data),

                .completed(is_fetch_done),
                .pc_n(pc_fd_out),
                .instr_raw(instr_fd_out));      

   // decode & reg
   /////////
   // control flags
   (* mark_debug = "true" *) reg                decode_enabled;
   (* mark_debug = "true" *) reg                decode_reset;   
   (* mark_debug = "true" *) wire               is_decode_done;
   
   // pipeline regs
   // None
   
   // stage input
   reg [31:0]         pc_fd_in;
   reg [31:0]         instr_fd_in;
   
   // stage outputs
   instructions instr_de_out;   
   regvpair register_de_out;
   
   wire [4:0]         rs1_a;
   wire [4:0]         rs2_a;
   decoder _decoder(.clk(clk), 
                    .rstn(rstn && !decode_reset),                    
                    .enabled(decode_enabled),
      
                    .pc(pc_fd_in),      
                    .instr_raw(instr_fd_in),                    
      
                    .completed(is_decode_done),
                    .instr(instr_de_out),
                    .rs1(rs1_a), .rs2(rs2_a));

   // registers
   wire [4:0]         reg_w_dest;
   wire [31:0]        reg_w_data;
   
   wire               reg_w_enable;   
   regf _registers(.clk(clk), 
                   .rstn(rstn),
                   .r_enabled(decode_enabled),
      
                   .rs1(rs1_a),
                   .rs2(rs2_a),
      
                   .w_enable(reg_w_enable),
                   .w_addr(reg_w_dest),
                   .w_data(reg_w_data),
      
                   .register(register_de_out));   
   
   
   // exec
   /////////
   // control flags
   (* mark_debug = "true" *) reg                exec_enabled;
   (* mark_debug = "true" *) reg                exec_reset;   
   (* mark_debug = "true" *) wire               is_exec_done;
   wire               is_exec_available = is_exec_done && !exec_reset;   
   
   // stage input
   (* mark_debug = "true" *) instructions instr_de_in;   
   (* mark_debug = "true" *) regvpair register_de_in;
   
   // stage outputs
   instructions instr_em_out;   
   regvpair register_em_out;
   (* mark_debug = "true" *) wire [31:0]        result_em_out;
   (* mark_debug = "true" *) wire               is_jump_chosen_em_out;
   (* mark_debug = "true" *) wire [31:0]        jump_dest_em_out;   

   execute _execute(.clk(clk), 
                    .rstn(rstn && !exec_reset),
      
                    .enabled(exec_enabled),
                    .instr(instr_de_in),
                    .register(register_de_in),
      
                    .completed(is_exec_done),
      
                    .instr_n(instr_em_out),
                    .register_n(register_em_out), 
                    .result(result_em_out), 
                    .is_jump_chosen(is_jump_chosen_em_out), 
                    .jump_dest(jump_dest_em_out));

   // mem
   /////////
   // control flags
   (* mark_debug = "true" *) reg                mem_enabled;
   (* mark_debug = "true" *) reg                mem_reset;   
   (* mark_debug = "true" *) wire               is_mem_done;
   wire               is_mem_available = is_mem_done && !mem_reset;   

   // stage inputs
   instructions instr_em_in;   
   regvpair register_em_in;
   reg [31:0]         result_em_in;
   
   // stage outputs
   instructions instr_mw_out;   
   wire [31:0]        result_mw_out;
   
   mem _mem(.clk(clk), 
            .rstn(rstn && !mem_reset),
      
            .enabled(mem_enabled),
            .instr(instr_em_in),
            .register(register_em_in),
            .addr(result_em_in),

            .axi_araddr(axi_araddr), 
            .axi_arready(axi_arready), 
            .axi_arvalid(axi_arvalid), 
            .axi_arprot(axi_arprot),
      
            .axi_bready(axi_bready), 
            .axi_bresp(axi_bresp), 
            .axi_bvalid(axi_bvalid),
      
            .axi_rdata(axi_rdata), 
            .axi_rready(axi_rready),
            .axi_rresp(axi_rresp), 
            .axi_rvalid(axi_rvalid),
      
            .axi_awaddr(axi_awaddr), 
            .axi_awready(axi_awready), 
            .axi_awvalid(axi_awvalid), 
            .axi_awprot(axi_awprot), 

            .axi_wdata(axi_wdata), 
            .axi_wready(axi_wready), 
            .axi_wstrb(axi_wstrb), 
            .axi_wvalid(axi_wvalid),

            .completed(is_mem_done),
      
            .instr_n(instr_mw_out),
            .result(result_mw_out));
   
   // write
   /////////
   // control flags
   (* mark_debug = "true" *) reg                write_enabled;
   (* mark_debug = "true" *) reg                write_reset;   
   (* mark_debug = "true" *) wire               is_write_done;   

   // stage input
   instructions instr_mw_in;   
   reg [31:0]         result_mw_in;

   // there is no stage output
   
   write _write(.clk(clk), 
                .rstn(rstn && !write_reset),
      
                .enabled(write_enabled), 
                .instr(instr_mw_in),      
                .data(result_mw_in),

                .reg_w_enable(reg_w_enable),

                .reg_w_dest(reg_w_dest),
                .reg_w_data(reg_w_data),

                .completed(is_write_done));
   

   wire               are_all_stages_completed = (fetch_reset || is_fetch_done) && (decode_reset || is_decode_done) && (exec_reset || is_exec_done) && (mem_reset || is_mem_done) && (write_reset || is_write_done);

   wire               reg_onestep_forwarding_required = (instr_de_out.uses_reg 
                                                         && instr_em_out.writes_to_reg
                                                         && ((instr_de_out.rs1 != 0 && instr_de_out.rs1 == instr_em_out.rd)
                                                             || (instr_de_out.rs2 != 0 && instr_de_out.rs2 == instr_em_out.rd))) ;   
   
   wire               reg_twostep_forwarding_required = (instr_de_out.uses_reg 
                                                         && instr_mw_out.writes_to_reg
                                                         && ((instr_de_out.rs1 != 0 && instr_de_out.rs1 == instr_mw_out.rd)
                                                             || (instr_de_out.rs2 != 0 && instr_de_out.rs2 == instr_mw_out.rd))) ;   
   

   (* mark_debug = "true" *) reg [128:0]        total_executed_instrs;
   
   /////////////////////
   // tasks
   /////////////////////
   task init;
      begin
         pc <= 0;
         stalling_for_mem_forwarding <= 0;
         
         fetch_enabled <= 1;      
         decode_enabled <= 0;      
         exec_enabled <= 0;      
         mem_enabled <= 0;      
         write_enabled <= 0;

         fetch_reset <= 0;
         decode_reset <= 1;
         exec_reset <= 1;
         mem_reset <= 1;
         write_reset <= 1;

         total_executed_instrs  <= 0;         
      end
   endtask; 

   task set_fd;      
      begin
         pc_fd_in <= pc_fd_out;
         instr_fd_in <= instr_fd_out;         
      end
   endtask

   task set_de;      
      begin
         instr_de_in <= instr_de_out;
         register_de_in.rs1 <= (reg_onestep_forwarding_required 
                                && is_exec_available 
                                && instr_em_out.rd == instr_de_out.rs1)? result_em_out:
                               (reg_twostep_forwarding_required 
                                && is_mem_available 
                                && instr_mw_out.rd == instr_de_out.rs1)? result_mw_out:
                               register_de_out.rs1;
         register_de_in.rs2 <= (reg_onestep_forwarding_required  
                                && is_exec_available 
                                && instr_em_out.rd == instr_de_out.rs2)? result_em_out:
                               (reg_twostep_forwarding_required 
                                && is_mem_available 
                                && instr_mw_out.rd == instr_de_out.rs2)? result_mw_out:
                               register_de_out.rs2;
      end
   endtask
   
   task set_em;      
      begin
         instr_em_in <= instr_em_out;
         register_em_in <= register_em_out;
         result_em_in <= result_em_out;         
      end
   endtask
   
   task set_mw;      
      begin
         instr_mw_in <= instr_mw_out;
         result_mw_in <= result_mw_out;         
      end
   endtask

   /////////////////////
   // main
   /////////////////////   
   initial begin
      init();      
   end

   always @(posedge clk) begin
      if(rstn) begin
         if (are_all_stages_completed) begin
            // Control stalls
            //////////////////

            if (stalling_for_mem_forwarding) begin               
               stalling_for_mem_forwarding <= 0;

               pc <= pc + 4;               
               
               fetch_enabled <= 1;
               fetch_reset <= 0;
               
               decode_enabled <= 1;
               decode_reset <= 0;
               set_fd();
               
               exec_enabled <= 1;            
               exec_reset <= 0;
               set_de();            
            end else if (instr_em_out.is_load && onestep_forwarding_required && is_exec_available) begin
               // case 00
               stalling_for_mem_forwarding <= 1;
               
               fetch_enabled <= 0;
               fetch_reset <= 0; // this result will be used in next round
               
               decode_enabled <= 1;
               decode_reset <= 0;
               // no set_fd();
               
               exec_enabled <= 0;               
               exec_reset <= 1; // this result won't be used in the future anymore.
               // no set_de(); because decode stage should be done once more before set_de
            end else if (is_jump_chosen_em_out && is_exec_available) begin
               // TODO: change here to handle only if it fails to predict jump destination
               pc <= jump_dest_em_out;
               
               fetch_enabled <= 1;
               fetch_reset <= 0;
               
               decode_enabled <= 0;
               decode_reset <= 1;
               // no set_fd();
               
               exec_enabled <= 0;               
               exec_reset <= 1;
               // no set_de(); because there's no need to move
            end else begin
               // TODO: set pc what branch predictor says
               pc <= pc + 4;               
               
               fetch_enabled <= 1;
               fetch_reset <= 0;
               
               decode_enabled <= is_fetch_done;
               decode_reset <= !is_fetch_done;
               set_fd();              
               
               exec_enabled <= is_decode_done;
               exec_reset <= !is_decode_done;
               set_de();
            end
            
            mem_enabled <= is_exec_available;            
            mem_reset <= !is_exec_available;
            set_em();              
            
            write_enabled <= is_mem_done;
            write_reset <= !is_mem_done;
            set_mw();

            if(is_write_done && !write_reset) begin
               total_executed_instrs <= total_executed_instrs + 1;               
            end      
            
            total_executed_instrs <=  total_executed_instrs + 1;     
         end else begin
            fetch_enabled <= 0;
            decode_enabled <= 0;
            exec_enabled <= 0;
            mem_enabled <= 0;
            write_enabled <= 0;
         end
      end else begin // if (rstn)
         init();
      end
   end
endmodule
`default_nettype wire
