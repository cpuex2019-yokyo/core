`default_nettype none
`include "def.sv"

  module core
    (input wire clk,
     input wire         rstn,

     // bus
     output wire        fetch_request_enable,
     output wire        freq_mode,
     output wire [31:0] freq_addr,
     output wire [31:0] freq_wdata,
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

     // from PLIC
     input wire         ext_intr,

     // from CLINT
     input wire         software_intr,
     input wire         timer_intr,
     input wire [63:0]  time_full
     );

   // registers
   /////////
   wire [4:0]           reg_w_dest;
   wire [31:0]          reg_w_data;
   wire                 reg_w_enable;
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
   wire [31:0]          _misa = {2'b01, 4'b0, 26'b00000101000001000100000001};   
   wire [31:0]          _mvendorid = 32'b0;
   wire [31:0]          _marchid = 32'b0;
   wire [31:0]          _mimpid = 32'b0;
   wire [31:0]          _mhartid = 32'b0;

   reg [31:0]           _mstatus;
   wire [31:0]          _mstatus_mask = 32'h601e79aa;   
   task write_mstatus (input [31:0] value);
      begin
         _mstatus <= (_mstatus & ~(_mstatus_mask)) | (value * _mstatus_mask);         
      end
   endtask
   
   reg [31:0]         _medeleg;
   wire [31:0]        delegable_excps = 32'hbfff;   
   task write_medeleg (input [31:0] value);
      begin
         _medeleg <= (_medeleg & ~delegable_excps) | (value & delegable_excps);         
      end
   endtask
   
   reg [31:0]         _mideleg;
   wire [31:0]        delegable_ints = 32'h222;   
   task write_mideleg (input [31:0] value);
      begin
         _mideleg <= (_mideleg & delegable_ints) | (value & delegable_ints);         
      end
   endtask
   
   reg [31:0]         _mip;
   task write_mip (input [31:0] value);
      begin
         // TODO
      end
   endtask
   
   
   reg [31:0]         _mie;
   wire [31:0]        all_ints = 32'haaa;   
   task write_mie (input [31:0] value);
      begin
         _mie <= (_mie & all_ints) | (value & all_ints);         
      end
   endtask
   
   reg [31:0]         _mtvec;
   task write_mtvec (input [31:0] value);
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
   
   reg [31:0]         _mcounteren;
   task write_mcounteren (input [31:0] value);
      begin
         _mcounteren <= value;         
      end
   endtask
   
   reg [31:0]         _mscratch;
   task write_mscratch (input [31:0] value);
      begin
         _mscratch <= value;         
      end
   endtask
   
   reg [31:0]         _mepc;
   task write_mepc (input [31:0] value);
      begin
         _mepc <= value;         
      end
   endtask
   
   reg [31:0]         _mcause;
   task write_mcause (input [31:0] value);
      begin
         _mcause <= value;         
      end
   endtask
   
   reg [31:0]         _mtval;
   task write_mtval (input [31:0] value);
      begin
         _mtval <= value;         
      end
   endtask
   
   reg [8 * 16 - 1:0]       _pmpcfg;
   // function [31:0] read_pmpcfg (input [31:0] value, input [3:0] idx);
   //    begin
   //       if(value & 1 == 0) begin
   //          read_pmpcfg = _pmpcfg[idx+:32];            
   //       end else begin
   //          read_pmpcfg = 32'b0;            
   //       end
   //    end
   // endtask 
   task write_pmpcfg (input [31:0] value, input [3:0] idx);
      begin
         if (value & 1 == 0) begin
            _pmpcfg[idx+:32] <= value;
         end
      end
   endtask 
   
   reg [31:0]       _pmpaddr[0:15];
   task write_pmpaddr (input [31:0] value, input [3:0] idx);
      begin
         // TODO: lock check
         _pmpaddr[idx] = value;         
      end
   endtask
   
   
   wire [31:0]       sstatus_v1_10_mask = 32'h800de133;   
   wire [31:0]       _sstatus = _mstatus & sstatus_v1_10_mask;
   task write_sstatus (input [31:0] value);
      begin
         write_mstatus((value & ~sstatus_v1_10_mask) | (value & sstatus_v1_10_mask));         
      end
   endtask
   
  // reg [31:0]       _sedeleg;
   //reg [31:0]       _sideleg;
   reg [31:0]       _sie = _mie & _mideleg;
   task write_sie (input [31:0] value);
      begin
         write_mie((_mie & ~(_mideleg)) | (value & (_mideleg)));
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
   task write_sepc (input [31:0] value);
      begin
         _sepc <= value;         
      end
   endtask
   
   reg [31:0]         _scause;   
   task write_scause (input [31:0] value);
      begin
         _scause <= value;         
      end
   endtask
   
   reg [31:0]         _stval;   
   task write_stval (input [31:0] value);
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
         ;// TODO
      end
   endtask

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

   // _time_full is given as a wire from CLINT
   wire [31:0]         _time = time_full[31:0];
   wire [31:0]         _timeh = time_full[63:32];
   
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
   wire                 is_csr_valid_d_out;
   wire [31:0]          csr_value_d_out;
   assign {is_csr_valid_d_out, csr_value_d_out} = read_csr(instr_d_out.imm[11:0]);

   wire [4:0]          rs1_a;
   wire [4:0]            rs2_a;
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
   reg                   is_csr_valid_e_in;
   reg  [31:0]             csr_value_e_in;   

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
   reg [31:0]            arg_m_in;

   // stage outputs
   instructions instr_m_out;
   wire [31:0]           result_m_out;

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
   reg [31:0]            result_w_in;

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
         pc <= 32'h80000000;

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
            // TODO: choose mcause or scause appropriately
            _mcause[31] <= 1'b0;
            if (software_intr) begin
               _mcause[30:0] <= cpu_mode == CPU_M? 3:
                               cpu_mode == CPU_S? 1:
                               cpu_mode == CPU_U? 0:
                               12;               
            end else if (timer_intr) begin
               _mcause[30:0] <= cpu_mode == CPU_M? 7:
                               cpu_mode == CPU_S? 5:
                               cpu_mode == CPU_U? 4:
                               12;               
            end else begin
               _mcause[30:0] <= cpu_mode == CPU_M? 11:
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
   endtask // set_epc

   // here we assume that this function will used in the decode phase
   function read_csr(input [11:0] addr);
      begin
        if ((instr_e_in.csrrw && instr_d_out.rd != 0)
            || (instr_e_in.csrrs)
            || (instr_e_in.csrrc)
            || (instr_e_in.csrrwi && instr_d_out.rd != 0)
            || (instr_e_in.csrrsi)
            || (instr_e_in.csrrci)) begin
         case (addr) 
           12'hc00: read_csr = {1'b1, _cycle};
           12'hc01: read_csr = {1'b1, _time};
           12'hc02: read_csr = {1'b1, _instret};
           12'hc81: read_csr = {1'b1, _timeh};
           12'hc82: read_csr = {1'b1, _instreth};
           // hpmcounterN
           // hpmcounterNh
           12'h100: read_csr = {1'b1, _sstatus};
           //12'h102: read_csr = {1'b1, _sedeleg};
           //12'h103: read_csr = {1'b1, _sideleg};
           12'h104: read_csr = {1'b1, _sie};
           12'h105: read_csr = {1'b1, _stvec};
           12'h106: read_csr = {1'b1, _scounteren};
           12'h140: read_csr = {1'b1, _sscratch};
           12'h141: read_csr = {1'b1, _sepc};
           12'h142: read_csr = {1'b1, _scause};
           12'h143: read_csr = {1'b1, _stval};
           12'h144: read_csr = {1'b1, _sip};
           12'h180: read_csr = {1'b1, _satp};            
           12'h300: read_csr = {1'b1, _mstatus};            
           12'h301: read_csr = {1'b1, _misa};
           12'h302: read_csr = {1'b1, _medeleg};
           12'h303: read_csr = {1'b1, _mideleg};
           12'h304: read_csr = {1'b1, _mie};
           12'h305: read_csr = {1'b1, _mtvec};
           12'h306: read_csr = {1'b1, _mcounteren};
           12'h340: read_csr = {1'b1, _mscratch};
           12'h341: read_csr = {1'b1, _mepc};
           12'h342: read_csr = {1'b1, _mcause};
           12'h343: read_csr = {1'b1, _mtval};                       
           12'h344: read_csr = {1'b1, _mip};
           12'h3a0: read_csr = {1'b1, _pmpcfg[127:96]};
           12'h3a1: read_csr = {1'b1, _pmpcfg[95:64]};
           12'h3a2: read_csr = {1'b1, _pmpcfg[63:32]};
           12'h3a3: read_csr = {1'b1, _pmpcfg[31:0]};
           12'h3b0: read_csr = {1'b1, _pmpaddr[0]};
           12'h3b1: read_csr = {1'b1, _pmpaddr[1]};
           12'h3b2: read_csr = {1'b1, _pmpaddr[2]};
           12'h3b3: read_csr = {1'b1, _pmpaddr[3]};
           12'h3b4: read_csr = {1'b1, _pmpaddr[4]};
           12'h3b5: read_csr = {1'b1, _pmpaddr[5]};
           12'h3b6: read_csr = {1'b1, _pmpaddr[6]};
           12'h3b7: read_csr = {1'b1, _pmpaddr[7]};
           12'h3b8: read_csr = {1'b1, _pmpaddr[8]};
           12'h3b9: read_csr = {1'b1, _pmpaddr[9]};
           12'h3ba: read_csr = {1'b1, _pmpaddr[10]};
           12'h3bb: read_csr = {1'b1, _pmpaddr[11]};
           12'h3bc: read_csr = {1'b1, _pmpaddr[12]};
           12'h3bd: read_csr = {1'b1, _pmpaddr[13]};
           12'h3be: read_csr = {1'b1, _pmpaddr[14]};
           12'h3bf: read_csr = {1'b1, _pmpaddr[15]};            
           12'hb00: read_csr = {1'b1, _mcycle};
           12'hb02: read_csr = {1'b1, _minstret};
           12'hb80: read_csr = {1'b1, _mcycleh};
           12'hb82: read_csr = {1'b1, _minstreth};
           // mhpmcounterN
           // mhpmcounterNh
           // mhpmevent*
           default: read_csr = {1'b0, 32'b0};            
         endcase // case (addr)
        end else begin
           read_csr = {1'b1, 32'b0};           
        end         
      end
   endfunction // read_csr

   task invalid_csr_addr(input [11:0] addr);
      begin
         state <= FETCH;
         // TODO
         // scause
         //
      end
   endtask

   // here we assume that this function will be used in the exec phase
   task write_csr(input [11:0] addr, input[31:0] value); 
     begin
        if ((instr_e_in.csrrw)
            || (instr_e_in.csrrs && instr_e_in.rs1 != 0)
            || (instr_e_in.csrrc && instr_e_in.rs1 != 0)
            || (instr_e_in.csrrwi)
            || (instr_e_in.csrrsi && instr_e_in.rs1 != 0)
            || (instr_e_in.csrrci && instr_e_in.rs1 != 0)) begin
           case (addr) 
             // U mode            
             // 12'hc00: _cycle;
             // 12'hc01: _time;
             // 12'hc02: _instret;
             // 12'hc81: _timeh;
             // 12'hc82: _instreth;
             // hpmcounterN
             // hpmcounterNh

             // S mode
             12'h100: write_sstatus(value);
             //12'h102: write_sedeleg(value);
             //12'h103: write_sideleg(value);
             12'h104: write_sie(value);
             12'h105: write_stvec(value);
             12'h106: write_scounteren(value);
             12'h140: write_sscratch(value);
             12'h141: write_sepc(value);
             12'h142: write_scause(value);
             12'h143: write_stval(value);
             12'h144: write_sip(value);
             12'h180: write_satp(value);   

             // M mode
             12'h300: write_mstatus(value);            
             // 12'h301: misa
             12'h302: write_medeleg(value);            
             12'h303: write_mideleg(value);            
             12'h304: write_mie(value);            
             12'h305: write_mtvec(value);            
             12'h306: write_mcounteren(value);            
             12'h340: write_mscratch(value);            
             12'h341: write_mepc(value);            
             12'h342: write_mcause(value);            
             12'h343: write_mtval(value);            
             12'h344: write_mip(value);            
             12'h3a0: write_pmpcfg(value, 127);            
             12'h3a1: write_pmpcfg(value, 95);            
             12'h3a2: write_pmpcfg(value, 64);
             12'h3a3: write_pmpcfg(value, 31);
             12'h3b0: write_pmpaddr(value, 0);
             12'h3b1: write_pmpaddr(value, 1);
             12'h3b2: write_pmpaddr(value, 2);
             12'h3b3: write_pmpaddr(value, 3);
             12'h3b4: write_pmpaddr(value, 4);
             12'h3b5: write_pmpaddr(value, 5);
             12'h3b6: write_pmpaddr(value, 6);
             12'h3b7: write_pmpaddr(value, 7);
             12'h3b8: write_pmpaddr(value, 8);
             12'h3b9: write_pmpaddr(value, 9);
             12'h3ba: write_pmpaddr(value, 10);
             12'h3bb: write_pmpaddr(value, 11);
             12'h3bc: write_pmpaddr(value, 12);
             12'h3bd: write_pmpaddr(value, 13);
             12'h3be: write_pmpaddr(value, 14);
             12'h3bf: write_pmpaddr(value, 15);
             // 12'hb00: _mcycle;
             // 12'hb02: _minstret;
             // 12'hb80: _mcycleh;
             // 12'hb82: _minstreth;
             // mhpmcounterN
             // mhpmcounterNh
             // mhpmevent*
             default: invalid_csr_addr(addr);            
           endcase           
        end // if ((instr_e_in.csrrs))
     end
   endtask
   
   // here we assume this function is expanded into exec phase
   function csr_v(input [31:0] original);
      begin         
         if (instr_e_in.csrrw) begin
            csr_v = register_e_in.rs1;            
         end else if (instr_e_in.csrrs) begin
            csr_v = original | register_e_in.rs1;
         end else if (instr_e_in.csrrc) begin
            csr_v = original | ~(register_e_in.rs1);            
         end else if (instr_e_in.csrrwi) begin
            csr_v = {27'b0, instr_e_in.rs1};
         end else if (instr_e_in.csrrsi) begin
            csr_v = original | {27'b0, instr_e_in.rs1};
         end else if (instr_e_in.csrrci) begin
            csr_v = original | ~({27'b0, instr_e_in.rs1});
         end
      end
   endfunction
   

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
               
               instr_e_in <= instr_d_out;
               register_e_in <= register_d_out;
               is_csr_valid_e_in <= is_csr_valid_d_out;
               csr_value_e_in <= csr_value_d_out;                             
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
            if (is_csr_valid_e_in) begin
               state <= WRITE;
               write_csr(instr_e_in.imm[11:0], csr_v(csr_value_e_in));

               // start to write ... e -> w
               write_enabled <= 1;
               instr_w_in <= instr_e_in;
               result_w_in <= csr_value_e_in;               
            end else begin
               invalid_csr_addr(instr_e_in.imm[11:0]);               
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
            //register_m_in <= register_m_in;            
            arg_m_in <= instr_m_out.amoswap? register_m_in.rs2:
                        instr_m_out.amoadd? result_m_out + register_m_in.rs2:
                        instr_m_out.amoand? result_m_out & register_m_in.rs2:
                        instr_m_out.amoor? result_m_out | register_m_in.rs2:
                        instr_m_out.amoxor? result_m_out ^ register_m_in.rs2:
                        instr_m_out.amomax? ($signed(result_m_out) > $signed(register_m_in.rs2)? result_m_out:
                                             register_m_in.rs2):
                        instr_m_out.amomin? ($signed(result_m_out) > $signed(register_m_in.rs2)? register_m_in.rs2:
                                             result_m_out):
                        instr_m_out.amomaxu? (result_m_out > register_m_in.rs2? result_m_out:
                                              result_m_out):
                        instr_m_out.amominu? (result_m_out > register_m_in.rs2? register_m_in.rs2:
                                              result_m_out):
                        0;
         end else if (state == EXEC_ATOM2 && is_mem_done) begin
            state <= WRITE;

            // start to write ... args are prepared when it leaves from EXEC_ATOM1
            write_enabled <= 1;
         end else if (state == EXEC && is_exec_done) begin
            state <= MEM;

            // TODO: implement wfi correctly, although the spec says regarding wfi as nop is legal...
            if (instr_e_out.ecall || instr_e_out.ebreak) begin
               set_epc(instr_e_out.pc);               
               if (instr_e_out.ecall) begin
                  _mcause[30:0] = cpu_mode == CPU_M? 11:
                                 cpu_mode == CPU_S? 9:
                                 cpu_mode == CPU_U? 8:
                                 16;               
               end else if (instr_e_out.ebreak) begin
                  _mcause[31:0] = 3;               
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
