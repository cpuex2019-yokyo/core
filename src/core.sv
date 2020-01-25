`default_nettype none
`include "def.sv"

module core
  (input wire clk,
   input wire         rstn,

   // bus
   output wire        fetch_request_enable,
   output wire        freq_mode,
   output wire [31:0] freq_addr,
   output wire [31:0] freq_wdata
   output wire [3:0]  freq_wstrb,
   input wire         fetch_response_enable,
   input wire [31:0]  fresp_data,


   output wire        mem_request_enable,
   output wire        mreq_mode,
   output wire [31:0] mreq_addr,
   output wire [31:0] mreq_wdata,
   output wire [3:0]  mreq_wstrb,
   input wire         mem_response_enable,
   input wire [31:0]  mresp_data,

   input wire         software_intr,
   input wire         timer_intr,
   input wire         ext_intr
   );

   // registers
   /////////
   wire [4:0]         reg_w_dest;
   wire [31:0]        reg_w_data;
   wire               reg_w_enable;
   registers _registers(.clk(clk),
                        .rstn(rstn),
                        .r_enabled(decode_enabled),

                        .rs1(rs1_a),
                        .rs2(rs2_a),

                        .w_enable(reg_w_enable),
                        .w_addr(reg_w_dest),
                        .w_data(reg_w_data),

                        .register(register_d_out));

   // csrs
   /////////
   wire [31:0]        _misa = {2'b01, 4'b0, 26'b00000101000001000100000001};   
   wire [31:0]        _mvendorid = 32'b0;
   wire [31:0]        _marchid = 32'b0;
   wire [31:0]        _mimpid = 32'b0;
   wire [31:0]        _mhartid = 32'b0;

   reg [31:0]         _mstatus;
   wire [31:0]        _mstatus_mask = 32'h601e79aa;   
   task write_mstatus (input wire [31:0] value);
      begin
         _mstatus <= (_mstatus & ~(mstatus_mask)) | (val * _mstatus_mask);         
      end
   endtask
   
   reg [31:0]         _medeleg;
   wire [31:0]        delegable_excps = 32'hbfff;   
   task write_medeleg (input wire [31:0] value);
      begin
         _medeleg <= (_medeleg & ~delegable_excps) | (value & delegable_excps);         
      end
   endtask
   
   reg [31:0]         _mideleg;
   wire [31:0]        delegable_ints = 32'h222;   
   task write_mideleg (input wire [31:0] value);
      begin
         _mideleg <= (_mideleg & delegable_ints) | (value & delegable_ints);         
      end
   endtask
   
   reg [31:0]         _mip;
   task write_mip (input wire [31:0] value);
      begin
         // TODO
      end
   endtask
   
   
   reg [31:0]         _mie;
   wire [31:0]        all_ints = 32'haaa;   
   task write_mie (input wire [31:0] value);
      begin
         _mie <= (_mie & all_ints) | (value & all_ints);         
      end
   endtask
   
   reg [31:0]         _mtvec;
   task write_mtvec (input wire [31:0] value);
      begin
         if (value & 3 < 2) begin
            _mtvec <= value;            
         end
      end
   endtask
   
   reg [63:0]         _mcycle_full;   
   wire [31:0]        _mcycle = _mcycle_full[31:0];   
   wire [31:0]        _mcycleh = _mcycle_full[63:32];

   reg [63:0]         _minstret_full;   
   wire [31:0]        _minstret = _minstret_full[31:0];   
   wire [31:0]        _minstreth = _minstret_full[63:32];
   
   wire [31:0]        _mhpmcounter3 = 32'b0;
   wire [31:0]        _mhpmcounter3h = 32'b0;
   wire [31:0]        _mhpmevent3 = 32'b0;
   
   reg [31:0]         _mcounteren;
   task write_mcounteren (input wire [31:0] value);
      begin
         _mcounteren <= value;         
      end
   endtask
   
   reg [31:0]         _mscratch;
   task write_mscratch (input wire [31:0] value);
      begin
         _mscratch <= value;         
      end
   endtask
   
   reg [31:0]         _mepc;
   task write_mepc (input wire [31:0] value);
      begin
         _mepc <= value;         
      end
   endtask
   
   reg [31:0]         _mcause;
   task write_mcause (input wire [31:0] value);
      begin
         _mcause <= value;         
      end
   endtask
   
   reg [31:0]         _mtval;
   task write_mtval (input wire [31:0] value);
      begin
         _mtval <= value;         
      end
   endtask
   
   reg [8 * 16:0]       _pmpcfg;
   function [31:0] read_pmpcfg (input [31:0] value, input [3:0] idx);
      begin
         if(value & 1 == 0) begin
            _pmpcfg[idx+:32];            
         end else begin
            32'b0;            
         end
      end
   endtask 
   task write_pmpcfg (input [31:0] value, input [3:0] idx);
      begin
         if (value & 1 == 0) begin
            _pmpcfg[idx+:32] <= value;
         end
      end
   endtask 
   
   reg [31:0]       _pmaddr[0:15];
   task write_pmaddr (input [31:0] value, input [3:0] idx);
      begin
         // TODO: lock check
         _pmaddr[idx] = value;         
      end
   endtask
   
   
   wire [31:0]       sstatus_v1_10_mask = 32'h0x800de133;   
   wire [31:0]       _sstatus = _mstatus & sstatus_v1_10_mask;
   task write_sstatus (input [31:0] value);
      begin
         write_mstatus((value & ~sstatus_v1_10_mask) | (value & sstatus_v1_10_mask));         
      end
   endtask
   
   reg [31:0]       _sedeleg;
   reg [31:0]       _sideleg;
   reg [31:0]       _sie = _mie & _mideleg;
   task write_sie (input [31:0] value);
      begin
         write_mie((_mie & ~(_mideleg)) | (value & (_mideleg)))
           end
   endtask
   
   reg [31:0]       _stvec;
   task write_stvec (input [31:0] value);
      begin
         if (value & 3 < 2) begin
            _stvec <= value;            
         end
      end
   endtask
   
   reg [31:0]      _scounteren;
   task write_scounteren (input [31:0] value);
      begin
         _scounteren <= value;         
      end
   endtask
   
   reg [31:0]         _sscratch;
   task write_sscratch (input [31:0] value);
      begin
         _sscratch <= value;         
      end
   endtask
   
   reg [31:0]         _sepc;
   task write_sepc (input wire [31:0] value);
      begin
         _sepc <= value;         
      end
   endtask
   
   reg [31:0]         _scause;   
   task write_scause (input wire [31:0] value);
      begin
         _scause <= value;         
      end
   endtask
   
   reg [31:0]         _stval;   
   task write_stval (input wire [31:0] value);
      begin
         _stval <= value;         
      end
   endtask
   
   reg [31:0]         _sip; // TODO
   task write_sip (input [31:0] value);
      begin
         // TODO
      end
   endtask
   
   reg [31:0]         _satp;
   task write_satp (input [31:0] value);
      begin
         // TODO
      end
   endtask;   

   // for N extension:
   // reg [31:0]         _ustatus;
   // reg [31:0]         _uie;
   // reg [31:0]         _utvec;
   // reg [31:0]         _uscratch;
   // reg [31:0]         _uepc;
   // reg [31:0]         _ucause;
   // reg [31:0]         _utval;
   // reg [31:0]         _uip;
   
   wire [31:0]         _cycle = _mcycle;
   wire [31:0]         _cycleh = _mcycleh;
   wire [31:0]         _instret = _minstret;
   wire [31:0]         _instreth = _minstreth;
   wire [31:0]         _hpmcounter3 = 32'b0;   
   wire [31:0]         _hpmcounter3h = 32'b0;

   // access to those regs is same as load of mtime
   reg [31:0]          _time;
   reg [31:0]          _timeh;
   
   // internal state
   /////////
   reg [31:0]          pc;
   enum reg [1:0]      {CPU_U = 2'b00, CPU_S = 2'b01, CPU_RESERVED = 2'b10, CPU_M = 2'b11} cpu_mode;
   enum reg [5:0]      {INIT, FETCH, DECODE, EXEC, EXEC_PRIV, EXEC_ATOM1, EXEC_ATOM2, MEM, WRITE, ATOM1, ATOM2, EXCEPTION} state;
   

   // fetch stage
   /////////
   // control flags
   (* mark_debug = "true" *) reg                fetch_enabled;
   (* mark_debug = "true" *) wire               is_fetch_done;

   // stage outputs
   wire [31:0]         pc_f_out;
   wire [31:0]         instr_f_out;

   fetch _fetch(.clk(clk),
                .rstn(rstn),

                .enabled(fetch_enabled),
                .completed(is_fetch_done),

                .request_enable(fetch_request_enable),
                .mode(freq_mode),
                .addr(freq_addr),
                .wdata(freq_wdata),
                .wstrb(freq_wstrb),
                .response_enable(fetch_response_enable),
                .data(fresp_data),

                .pc(pc),

                .pc_n(pc_f_out),
                .instr_raw(instr_f_out));

   // decode stage
   /////////
   // control flags
   (* mark_debug = "true" *) reg                decode_enabled;
   (* mark_debug = "true" *) wire               is_decode_done;

   // stage input
   reg [31:0]          pc_d_in;
   reg [31:0]          instr_d_in;

   // stage outputs
   instructions instr_d_out;
   regvpair register_d_out;

   wire [4:0]          rs1_a;
   wire [4:0]          rs2_a;
   decoder _decoder(.clk(clk),
                    .rstn(rstn),

                    .enabled(decode_enabled),
                    .completed(is_decode_done),

                    .pc(pc_d_in),
                    .instr_raw(instr_d_in),

                    .instr(instr_d_out),
                    .rs1(rs1_a),
                    .rs2(rs2_a));

   // exec stage
   /////////
   // control flags
   (* mark_debug = "true" *) reg                exec_enabled;
   (* mark_debug = "true" *) wire               is_exec_done;

   // stage input
   (* mark_debug = "true" *) instructions instr_e_in;
   (* mark_debug = "true" *) regvpair register_e_in;

   // stage outputs
   instructions instr_e_out;
   regvpair register_e_out;
   (* mark_debug = "true" *) wire [31:0]        result_e_out;
   (* mark_debug = "true" *) wire               is_jump_chosen_e_out;
   (* mark_debug = "true" *) wire [31:0]        jump_dest_e_out;

   execute _execute(.clk(clk),
                    .rstn(rstn),

                    .enabled(exec_enabled),
                    .completed(is_exec_done),

                    .instr(instr_e_in),
                    .register(register_e_in),

                    .instr_n(instr_e_out),
                    .register_n(register_e_out),
                    .result(result_e_out),
                    .is_jump_chosen(is_jump_chosen_e_out),
                    .jump_dest(jump_dest_e_out));

   // mem stage
   /////////
   // control flags
   (* mark_debug = "true" *) reg                mem_enabled;
   (* mark_debug = "true" *) wire               is_mem_done;

   // stage inputs
   instructions instr_m_in;
   regvpair register_m_in;
   reg [31:0]          arg_m_in;

   // stage outputs
   instructions instr_m_out;
   wire [31:0]         result_m_out;

   mem _mem(.clk(clk),
            .rstn(rstn),

            .enabled(mem_enabled),
            .completed(is_mem_done),

            .request_enable(mem_request_enable),
            .mode(mreq_mode),
            .addr(mreq_addr),
            .wdata(mreq_wdata),
            .wstrb(mreq_wstrb),
            .response_enable(mem_response_enable),
            .data(mresp_data),

            .instr(instr_m_in),
            .register(register_m_in),
            .arg(arg_m_in),
            .instr_n(instr_m_out),
            .result(result_m_out));

   // write stage
   /////////
   // control flags
   (* mark_debug = "true" *) reg                write_enabled;
   (* mark_debug = "true" *) wire               is_write_done;

   // stage input
   instructions instr_w_in;
   reg [31:0]          result_w_in;

   write _write(.clk(clk),
                .rstn(rstn),

                .enabled(write_enabled),
                .instr(instr_w_in),
                .data(result_w_in),

                .reg_w_enable(reg_w_enable),

                .reg_w_dest(reg_w_dest),
                .reg_w_data(reg_w_data),

                .completed(is_write_done));


   /////////////////////
   // tasks
   /////////////////////
   task init;
      begin
         pc <= 0;

         fetch_enabled <= 0;
         decode_enabled <= 0;
         exec_enabled <= 0;
         mem_enabled <= 0;
         write_enabled <= 0;

         state <= INIT;         
      end
   endtask

   task clear_enabled;
      begin
         fetch_enabled <= 0;
         decode_enabled <= 0;
         exec_enabled <= 0;
         mem_enabled <= 0;
         write_enabled <= 0;
      end
   endtask // clear_enabled

   wire is_interrupted = software_intr || timer_intr || ext_intr;   
   task handle_intr;
      begin
         fetch_enabled <= 1;
         state <= FETCH;         
         if (is_interrupted) begin
            mcause[31] <= 1'b0;
            if (software_intr) begin
               mcause[30:0] <= cpu_mode == CPU_M? 3:
                               cpu_mode == CPU_S? 1:
                               cpu_mode == CPU_U? 0:
                               12;               
            end else if (timer_intr) begin
               mcause[30:0] <= cpu_mode == CPU_M? 7:
                               cpu_mode == CPU_S? 5:
                               cpu_mode == CPU_U? 4:
                               12;               
            end else begin
               mcause[30:0] <= cpu_mode == CPU_M? 11:
                               cpu_mode == CPU_S? 9:
                               cpu_mode == CPU_U? 8:
                               12;               
            end
         end
      end
   endtask // handle_intr

   task set_pc_after_exec;
      begin
         if (instr_e_out.mret) begin
            if (cpu_mode >= CPU_M) begin
               pc <= _mepc;
               // TODO
               // mstatus.mpp <= priv;
               // mstatus.mie <= mstatus.mpie;
               // mstatus.mpie <= 1;
               // mstatus.mpp <= 0;
            end else begin
               // TODO: no priv
            end
         end else if (instr_e_out.sret) begin
            if (cpu_mode >= CPU_S) begin
               pc <= _sepc;
               // TODO
               // mstatus.spp <= priv;
               // mstatus.sie <= mstatus.spie;
               // mstatus.spie <= 1;
               // mstatus.spp <= 0;
            end else begin
               // TODO: no priv
            end
         end else if (is_jump_chosen_e_out) begin
            pc <= jump_dest_e_out;
         end else begin
            pc <= pc + 4;
         end
      end
   endtask 

   task set_cause(input [1:0] next_cpu_mode, input [31:0] value);
      begin
         if (next_cpu_mode == CPU_M) begin
            write_mcause(value);
         end  else if (next_cpu_mode == CPU_S) begin
            write_scause(value);
         end            
      end
   endtask
   
   task set_tval(input [1:0] next_cpu_mode, input [31:0] value);
      begin
         if (next_cpu_mode == CPU_M) begin
            write_mtval(value);
         end  else if (next_cpu_mode == CPU_S) begin
            write_stval(value);
         end            
      end
   endtask

   task set_epc(input [31:0] value);
      begin
         if (cpu_mode == CPU_M) begin
            write_mepc(value);
         end else if (cpu_mode == CPU_S) begin
            write_sepc(value);
         end            
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
         if (state == INIT) begin
            handle_intr();            
         end if (state == FETCH && is_fetch_done) begin
            state <= DECODE;

            // start to decode ... f -> d
            decode_enabled <= 1;
            pc_d_in <= pc_f_out;
            instr_d_in <= instr_f_out;
         end else if (state == DECODE && is_decode_done) begin
            if (instr_d_out.csrop) begin
               state <= EXEC_PRIV;               
            end else if (instr_d_out.rv32a) begin               
               state <= EXEC_ATOM1;
               // NOTE:
               // amo* rd, rs1, rs2 can be splited into ... (pseudo-code)
               // lw rd, (rs1)
               // op tmp, rs2, rd
               // sw tmp, (rs1)
               
               // start to load (rs1) ... d -> m
               mem_enabled <= 1;
               instr_m_in <= instr_d_out;
               register_m_in <= register_d_out;               
               arg_m_in <= register_d_out.rs1; // load addr: rs1
            end else begin
               state <= EXEC;

               // start to execute ... d -> e
               instr_e_in <= instr_d_out;
               register_e_in <= register_d_out;
               exec_enabled <= 1;
            end
         end else if (state == EXEC_PRIV) begin
            // TODO
            if (instr.csrrw) begin               
            end else if (instr.csrrs) begin
            end else if (instr.csrrc) begin
            end else if (instr.csrrwi) begin
            end else if (instr.csrrsi) begin
            end else if (instr.csrrci) begin
            end
         end else if (state == EXEC_ATOM1 && is_mem_done) begin            
            state <= EXEC_ATOM2;
            
            // prepare to write ... m -> w
            // here we do not enable write yet
            instr_w_in <= instr_m_out;
            result_w_in <= result_m_out;

            // start to store ... m -> (binop)-> m
            // op tmp, rs2, rd -> sw tmp, (rs1)
            mem_enabled <= 1;            
            instr_m_in <= instr_m_out;            
            register_m_in <= register_m_out;            
            arg_m_in <= instr_m_out.amoswap? register_m_out.rs2:
                        instr_m_out.amoadd? result_m_out + register_m_out.rs2:
                        instr_m_out.amoand? result_m_out & register_m_out.rs2:
                        instr_m_out.amoor? result_m_out | register_m_out.rs2:
                        instr_m_out.amoxor? result_m_out ^ register_m_out.rs2:
                        instr_m_out.amomax? ($signed(result_m_out) > $signed(register_m_out.rs2)? result_m_out:
                                             register_m_out.rs2):
                        instr_m_out.amomin? ($signed(result_m_out) > $signed(register_m_out.rs2)? register_m_out.rs2:
                                             result_m_out):
                        instr_m_out.amomaxu? (result_m_out > register_m_out.rs2? result_m_out:
                                              register_m_out):
                        instr_m_out.amominu? (result_m_out > register_m_out.rs2? register_m_out.rs2:
                                              result_m_out):
                        0;
         end else if (state == EXEC_ATOM2 && is_mem_done) begin
            state <= WRITE;

            // start to write ... args are prepared when it leaves from EXEC_ATOM1
            write_enabled <= 1;
         end else if (state == EXEC && is_exec_done) begin
            state <= MEM;

            // TODO: implement wfi correctly, although the spec says regarding wfi as nop is legal...
            if (isntr_e_out.ecall || instr_e_out.ebreak) begin
               set_epc(instr_e_out.pc);               
               if (instr_e_out.ecall) begin
                  mcause[30:0] = cpu_mode == CPU_M? 11:
                                 cpu_mode == CPU_S? 9:
                                 cpu_mode == CPU_U? 8:
                                 16;               
               end else if (instr_e_out.ebreak) begin
                  mcause[31:0] = 3;               
               end
            end

            // start to operate mem ... e -> m
            mem_enabled <= 1;
            instr_m_in <= instr_e_out;
            register_m_in <= register_e_out;
            arg_m_in <= result_e_out;

            set_pc_after_exec();            
         end else if (state == MEM && is_mem_done) begin
            state <= WRITE;

            // start to write ... m -> w
            write_enabled <= 1;
            instr_w_in <= instr_m_out;
            result_w_in <= result_m_out;
         end else if (state == WRITE && is_write_done) begin
            // handle interrupts and jump to FETCH stage
            handle_intr();            
         end else begin
            // In the next clock after enabling *_enabled, we have to pull down them to zero.
            clear_enabled();
         end
      end else begin
         init();
      end
   end
endmodule
`default_nettype wire
