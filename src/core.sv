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
   input wire         timer_intr,
   input wire [63:0]  time_full,

   // to MMU
   output wire [31:0] o_satp,
   output wire [1:0]  o_cpu_mode,
   output wire        o_mxr,
   output wire        o_sum,
   output wire        flush_tlb,

   // from MMU
   input wire [4:0]   mem_exception_vec,
   input wire         mem_exception_enable,
   input wire [31:0]  mem_exception_tval
   );

   // internal state
   /////////
   (* mark_debug = "true" *) reg [31:0]          pc;
   (* mark_debug = "true" *) instructions instr;
   (* mark_debug = "true" *) regvpair register;
   (* mark_debug = "true" *) cpu_mode_t cpu_mode;   
   (* mark_debug = "true" *) enum reg [5:0]      {
                                                  INIT, 
                                                  FETCH, 
                                                  DECODE, 
                                                  EXEC, 
                                                  EXEC_PRIV, 
                                                  EXEC_ATOM1, 
                                                  EXEC_ATOM2, 
                                                  MEM, 
                                                  WRITE, 
                                                  ATOM1, 
                                                  ATOM2, 
                                                  TRAP
                                                  } state;
   const cpu_mode_t cpu_mode_base = CPU_U;
   
   task init_stage_states;
      begin
         instr <= '{default: '0};
         register <= '{default: '0};
      end
   endtask
   
   // registers
   /////////
   (* mark_debug = "true" *) wire [4:0]         reg_w_dest;
   (* mark_debug = "true" *) wire [31:0]        reg_w_data;
   (* mark_debug = "true" *) wire               reg_w_enable;
   (* mark_debug = "true" *) instructions instr_d_out;
   (* mark_debug = "true" *) regvpair register_d_out;         
   registers _registers(.clk(clk),
                        .rstn(rstn),
                        .r_enabled(is_fetch_done),

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

   (* mark_debug = "true" *) reg [31:0]         _mstatus;
   wire               _mstatus_mie = _mstatus[3];   
   wire               _mstatus_sie = _mstatus[1];   
   wire               _mstatus_tvm = _mstatus[20];   
   wire [1:0]         _mstatus_mpp = _mstatus[12:11];
   wire               _mstatus_mpie = _mstatus[7];
   wire               _mstatus_spp = _mstatus[8];
   wire               _mstatus_spie = _mstatus[5];   
   wire [31:0]        _mstatus_mask = 32'h601e79aa;   
   task write_mstatus (input [31:0] value);
      begin
         _mstatus <= (_mstatus & ~(_mstatus_mask)) | (value & _mstatus_mask);         
      end
   endtask

   task set_mstatus_by_trap(input [1:0] next_cpu_mode);
      begin
         if (next_cpu_mode == CPU_M) begin
            _mstatus <= {_mstatus[31:13], 
                         cpu_mode[1:0],  //mpp
                         _mstatus[10:8], 
                         _mstatus[3], // mpie
                         _mstatus[6:4],
                         1'b0, // mie
                         _mstatus[2:0]}; // to M
         end else begin
            _mstatus <= {_mstatus[31:9], 
                         cpu_mode[0], // spp 
                         _mstatus[7:6], 
                         _mstatus[1], //spie
                         _mstatus[4:2], 
                         1'b0, //sie
                         _mstatus[0]};                  
         end         
      end
   endtask

   task set_mstatus_by_mret();      
      begin
         _mstatus <= {_mstatus[31:13], 
                      2'b0, // mpp
                      _mstatus[10:8], 
                      1'b1, // mpie
                      _mstatus[6:4], 
                      _mstatus_mpie, // mie
                      _mstatus[2:0]};               
      end
   endtask

   task set_mstatus_by_sret();
      begin
         _mstatus <= {_mstatus[31:9], 
                      1'b0, // spp
                      _mstatus[7:6], 
                      1'b1,  // spie
                      _mstatus[4:2], 
                      _mstatus_spie, // sie 
                      _mstatus[0]};         
      end
   endtask
   
   (* mark_debug = "true" *) reg [31:0]         _medeleg;
   wire [31:0]        delegable_excps = 32'hbfff;   
   task write_medeleg (input [31:0] value);
      begin
         _medeleg <= (_medeleg & ~delegable_excps) | (value & delegable_excps);         
      end
   endtask
   
   (* mark_debug = "true" *) reg [31:0]         _mideleg;
   wire [31:0]        delegable_ints = 32'h222;   
   task write_mideleg (input [31:0] value);
      begin
         _mideleg <= (_mideleg & delegable_ints) | (value & delegable_ints);         
      end
   endtask

   // mip: 
   // - ext_intr from PLIC is supervisor-level external interrupt
   // - timer_intr from CLINT is machine-level timer intr
   wire [31:0]        intr_mask = {20'b0, 4'b1000, 4'b1000, 4'b0000};
   (* mark_debug = "true" *) reg [31:0] _mip_shadow;   
   (* mark_debug = "true" *) wire [31:0]         _mip = (_mip_shadow & intr_mask) | {20'b0, 2'b0, ext_intr, 1'b0, timer_intr, 3'b0, 4'b0};
   wire               software_intr = |(_mip[3:0]);
   wire               software_intr_m = _mip[3];
   wire               software_intr_s = _mip[2];   
   task write_mip (input [31:0] value);
      begin
         _mip_shadow <= value;                       
      end
   endtask
   
   
   (* mark_debug = "true" *) reg [31:0]         _mie;
   wire [31:0]        all_ints = 32'haaa;   
   task write_mie (input [31:0] value);
      begin
         _mie <= (_mie & all_ints) | (value & all_ints);         
      end
   endtask
   
   (* mark_debug = "true" *) reg [31:0]         _mtvec;
   task write_mtvec (input [31:0] value);
      begin
         if ((value & 32'h3) < 32'h2) begin
            _mtvec <= value;            
         end
      end
   endtask
   
   (* mark_debug = "true" *) reg [63:0]         _mcycle_full;   
   wire [31:0]        _mcycle = _mcycle_full[31:0];   
   wire [31:0]        _mcycleh = _mcycle_full[63:32];

   (* mark_debug = "true" *) reg [63:0]         _minstret_full;   
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
   
   (* mark_debug = "true" *) reg [31:0]         _mtval;
   task write_mtval (input [31:0] value);
      begin
         _mtval <= value;         
      end
   endtask

   // TODO(linux): implmenent PMP appropriately   
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

   // TODO(future): implement user-level trap   
   // reg [31:0]       _sedeleg;
   //reg [31:0]       _sideleg;
   (* mark_debug = "true" *) wire [31:0]       _sie = _mie & _mideleg;
   task write_sie (input [31:0] value);
      begin
         write_mie((_mie & ~(_mideleg)) | (value & (_mideleg)));
      end
   endtask
   
   (* mark_debug = "true" *) reg [31:0]       _stvec;
   task write_stvec (input [31:0] value);
      begin
         if ((value & 32'h3) < 32'h2) begin
            _stvec <= value;            
         end
      end
   endtask
   
   (* mark_debug = "true" *) reg [31:0]      _scounteren;
   task write_scounteren (input [31:0] value);
      begin
         _scounteren <= value;         
      end
   endtask
   
   (* mark_debug = "true" *) reg [31:0]         _sscratch;
   task write_sscratch (input [31:0] value);
      begin
         _sscratch <= value;         
      end
   endtask
   
   (* mark_debug = "true" *) reg [31:0]         _sepc;
   task write_sepc (input [31:0] value);
      begin
         _sepc <= value;         
      end
   endtask
   
   (* mark_debug = "true" *) reg [31:0]         _scause;   
   task write_scause (input [31:0] value);
      begin
         _scause <= value;         
      end
   endtask
   
   (* mark_debug = "true" *) reg [31:0]         _stval;   
   task write_stval (input [31:0] value);
      begin
         _stval <= value;         
      end
   endtask
   
   wire [31:0]         _sip = _mip & _mideleg;
   // This mask is for SSIP, USIP, and UEIP.
   wire [31:0]         sip_writable_mask = 32'b100000011;   
   task write_sip (input [31:0] value);
      begin
         write_mip(value & _mideleg & sip_writable_mask);         
      end
   endtask
   
   (* mark_debug = "true" *) reg [31:0]         _satp;
   task write_satp (input [31:0] value);
      begin
         if (_mstatus_tvm && cpu_mode == CPU_S) begin
            state <= TRAP;
            raise_illegal_instruction(instr_raw);            
         end else begin
            // TODO: flush TLB
            _satp <= value;            
         end
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
   
   // interrupts
   /////////
   wire                is_interrupted = 
                       (((_mip[11] && _mie[11]) // for M-mode trap
                         || (_mip[7] && _mie[7]) 
                         || (_mip[3] && _mie[3])) 
                        && ((_mstatus_mie && cpu_mode == CPU_M)
                            || (CPU_M > cpu_mode)))
                       || (((_mideleg[11] && _mip[11] && _mie[11]) // for S-mode trap 
                            || (_mideleg[7] && _mip[7] && _mie[7]) 
                            || (_mideleg[3] && _mip[3] && _mie[3])
                            || (_mip[9] && _mie[9])
                            || (_mip[5] && _mie[5])
                            || (_mip[1] && _mie[1]))
                           && ((cpu_mode == CPU_S && _mstatus_sie) 
                               || CPU_S > cpu_mode));

   wire [1:0]          next_cpu_mode_when_interrupted =
                       (_mip[11] && _mie[11])? (_mideleg[11]? CPU_S : CPU_M):
                       (_mip[9] && _mie[9])? CPU_S:
                       (_mip[3] && _mie[3])? (_mideleg[3]? CPU_S : CPU_M):
                       (_mip[1] && _mie[1])? CPU_S:
                       (_mip[7] && _mie[7])? (_mideleg[7]? CPU_S : CPU_M):
                       (_mip[5] && _mie[5])? CPU_S:
                       cpu_mode;   
   
   wire [31:0]         exception_vec_when_interrupted =
                       (_mip[11] && _mie[11])? (_mideleg[11]? 32'd9 : 32'd11):
                       (_mip[9] && _mie[9])? 32'd9:
                       (_mip[3] && _mie[3])? (_mideleg[3]? 32'd1 : 32'd3):
                       (_mip[1] && _mie[1])? 32'd1:
                       (_mip[7] && _mie[7])? (_mideleg[7]? 32'd4 : 32'd7):
                       (_mip[5] && _mie[5])? 32'd4:
                       32'd0;
   
   (* mark_debug = "true" *) reg [4:0]           exception_number;   
   (* mark_debug = "true" *) reg [31:0]          exception_tval;        
   wire [1:0]          next_cpu_mode_when_exception = _medeleg[exception_number]? CPU_S : CPU_M;                 
   
   task raise_illegal_instruction(input [31:0] _tval);
      begin
         exception_number <= 5'd2;         
         exception_tval <= _tval;
      end
   endtask
   
   task raise_instruction_address_misaligned(input [31:0] _tval);
      begin
         exception_number <= 5'd0;         
         exception_tval <= _tval;
      end
   endtask // raise_instruction_adress_misaligned

   task raise_ecall;      
      begin
         exception_number <= cpu_mode == CPU_M? 5'd11:
                             cpu_mode == CPU_S? 5'd9:
                             cpu_mode == CPU_U? 5'd8:
                             5'd16;
         exception_tval <= 32'd0; // NOTE: is it okay?         
      end
   endtask

   task raise_ebreak;      
      begin
         exception_number <= 5'd3;         
         exception_tval <= instr.pc; // NOTE: is it okay?         
      end
   endtask
   
   // fetch stage
   /////////
   // control flags
   (* mark_debug = "true" *) reg                fetch_enabled;
   (* mark_debug = "true" *) wire               is_fetch_done;

   // stage outputs
   (* mark_debug = "true" *) wire [31:0]         instr_raw;

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
                .instr_raw(instr_raw));

   // decode stage
   /////////
   // control flags
   (* mark_debug = "true" *) wire               is_decode_done;

   // stage input
   // none

   // stage outputs
   // defined above

   wire [4:0]          rs1_a;
   wire [4:0]          rs2_a;
   decoder _decoder(.clk(clk),
                    .rstn(rstn),

                    .enabled(is_fetch_done),
                    .completed(is_decode_done),

                    .pc(pc),
                    .instr_raw(instr_raw),

                    .instr(instr_d_out),
                    .rs1(rs1_a),
                    .rs2(rs2_a));

   // exec stage
   /////////
   // control flags
   (* mark_debug = "true" *) reg                exec_enabled;
   (* mark_debug = "true" *) wire               is_exec_done;

   // stage input
   (* mark_debug = "true" *) reg                 is_csr_valid;
   (* mark_debug = "true" *) reg [31:0]          csr_value;   

   // stage outputs
   (* mark_debug = "true" *) wire [31:0]        exec_result;
   (* mark_debug = "true" *) wire               is_jump_chosen;
   (* mark_debug = "true" *) wire [31:0]        jump_dest;

   execute _execute(.clk(clk),
                    .rstn(rstn),

                    .enabled(exec_enabled),
                    .completed(is_exec_done),

                    .instr(instr),
                    .register(register),

                    .result(exec_result),
                    .is_jump_chosen(is_jump_chosen),
                    .jump_dest(jump_dest));

   // mem stage
   /////////
   // control flags
   (* mark_debug = "true" *) reg                mem_enabled;
   (* mark_debug = "true" *) wire               is_mem_done;

   // stage inputs
   (* mark_debug = "true" *) reg [31:0]          mem_arg;

   // stage outputs
   (* mark_debug = "true" *) wire [31:0]         mem_result;

   wire                is_a_read = (state == EXEC_ATOM1);
   wire                is_a_write = (state == EXEC_ATOM2);

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

            .instr(instr),
            .register(register),

            .arg(mem_arg),
            .is_a_read(is_a_read),
            .is_a_write(is_a_write),

            .result(mem_result),
            .flush_tlb(flush_tlb));

   // write stage
   /////////
   // control flags
   (* mark_debug = "true" *) reg                write_enabled;
   (* mark_debug = "true" *) wire               is_write_done;

   // stage input
   (* mark_debug = "true" *) reg [31:0]          data_to_write;

   write _write(.clk(clk),
                .rstn(rstn),

                .enabled(write_enabled),
                .instr(instr),
                .data(data_to_write),

                .reg_w_enable(reg_w_enable),

                .reg_w_dest(reg_w_dest),
                .reg_w_data(reg_w_data),

                .completed(is_write_done));


   /////////////////////
   // tasks
   /////////////////////
   task init;
      begin
         pc <= 32'h00001000; // bootloader
         
         fetch_enabled <= 0;
         exec_enabled <= 0;
         mem_enabled <= 0;
         write_enabled <= 0;

         state <= INIT;         
         cpu_mode <= CPU_M;
         is_csr_valid <= 1'b0;
         
         exception_number <= 5'b0;
         exception_tval <= 32'b0;

         // init csr
         _stvec <= 32'b0;
         _scounteren <= 32'b0;
         _sscratch <= 32'b0;         
         _sepc <= 32'b0;
         _scause <= 32'b0;         
         _stval <= 32'b0;         
         _satp <= 32'b0;
         _mstatus <= 32'b0;
         _medeleg <= 32'b0;
         _mideleg <= 32'b0;
         _mie <= 32'b0;
         _mtvec <= 32'b0;
         _mcounteren <= 32'b0;         
         _mscratch <= 32'b0;         
         _mepc <= 32'b0;         
         _mcause <= 32'b0;         
         _mtval <= 32'b0;         
         _mip_shadow <= 32'b0;         
         _pmpcfg <= 128'b0;         
         _pmpaddr[0] <= 32'b0;         
         _pmpaddr[1] <= 32'b0;         
         _pmpaddr[2] <= 32'b0;         
         _pmpaddr[3] <= 32'b0;         
         _pmpaddr[4] <= 32'b0;         
         _pmpaddr[5] <= 32'b0;         
         _pmpaddr[6] <= 32'b0;         
         _pmpaddr[7] <= 32'b0;         
         _pmpaddr[8] <= 32'b0;         
         _pmpaddr[9] <= 32'b0;         
         _pmpaddr[10] <= 32'b0;         
         _pmpaddr[11] <= 32'b0;        
         _pmpaddr[12] <= 32'b0;         
         _pmpaddr[13] <= 32'b0;         
         _pmpaddr[14] <= 32'b0;
         _pmpaddr[15] <= 32'b0;
         _mcycle_full <= 64'b0;         
      end
   endtask

   task clear_enabled;
      begin
         fetch_enabled <= 0;
         exec_enabled <= 0;
         mem_enabled <= 0;
         write_enabled <= 0;
      end
   endtask

   task set_cause(input [1:0] next_cpu_mode, input [31:0] value);
      begin
         if (cpu_mode_base.next(next_cpu_mode) == CPU_M) begin
            write_mcause(value);
         end  else if (cpu_mode_base.next(next_cpu_mode) == CPU_S) begin
            write_scause(value);
         end            
      end
   endtask
   
   task set_tval(input [1:0] next_cpu_mode, input [31:0] value);
      begin
         if (cpu_mode_base.next(next_cpu_mode) == CPU_M) begin
            write_mtval(value);
         end  else if (cpu_mode_base.next(next_cpu_mode) == CPU_S) begin
            write_stval(value);
         end            
      end
   endtask

   task set_epc(input  [1:0] next_cpu_mode, input [31:0] value);
      begin
         if (cpu_mode_base.next(next_cpu_mode) == CPU_M) begin
            write_mepc(value);
         end else if (cpu_mode_base.next(next_cpu_mode) == CPU_S) begin
            write_sepc(value);
         end            
      end
   endtask

   task set_pc_by_tvec(input is_asynchronous, input  [1:0] next_cpu_mode, input [4:0] vec);
      begin
         if (cpu_mode_base.next(next_cpu_mode) == CPU_M) begin
            pc <= (_mtvec[1:0] == 0 | ~is_asynchronous)? {_mtvec[31:2], 2'b0}:
                  {_mtvec[31:2], 2'b0} + 4 * vec;
         end else if (cpu_mode_base.next(next_cpu_mode) == CPU_S) begin
            pc <= (_stvec[1:0] == 0 | ~is_asynchronous)? {_stvec[31:2], 2'b0}:
                  {_stvec[31:2], 2'b0} + 4 * vec;         
         end
      end  
   endtask
   
   // here we assume that this function will used in the decode phase
   function [32:0] read_csr(input [11:0] addr);
      begin
         //if ((instr.csrrw && instr.rd != 0)
         //  || (instr_de_out.csrrs)
         //  || (instr_de_out.csrrc)
         //  || (instr.csrrwi && instr.rd != 0)
         //  || (instr.csrrsi)
         //  || (instr.csrrci)) begin
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
           12'hf11: read_csr = {1'b1, _mvendorid};
           12'hf12: read_csr = {1'b1, _marchid};
           12'hf13: read_csr = {1'b1, _mimpid};
           12'hf14: read_csr = {1'b1, _mhartid};
           // mhpmcounterN
           // mhpmcounterNh
           // mhpmevent*
           default: read_csr = {1'b0, 32'b0};            
         endcase // case (addr)
         //end else begin
         // read_csr = {1'b0, 32'b0};           
         //end         
      end
   endfunction // read_csr

   // here we assume that this function will be used in the exec phase
   task write_csr(input [11:0] addr, input[31:0] value); 
      begin
         if ((instr.csrrw)
             || (instr.csrrs && instr.rs1 != 0)
             || (instr.csrrc && instr.rs1 != 0)
             || (instr.csrrwi)
             || (instr.csrrsi && instr.rs1 != 0)
             || (instr.csrrci && instr.rs1 != 0)) begin
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
            endcase           
         end
      end
   endtask
   
   // here we assume this function is expanded into exec phase
   function [31:0] csr_v(input [31:0] original);
      begin         
         if (instr.csrrw) begin
            csr_v = register.rs1;            
         end else if (instr.csrrs) begin
            csr_v = original | register.rs1;
         end else if (instr.csrrc) begin
            csr_v = original & ~(register.rs1);            
         end else if (instr.csrrwi) begin
            csr_v = {27'b0, instr.rs1};
         end else if (instr.csrrsi) begin
            csr_v = original | {27'b0, instr.rs1};
         end else if (instr.csrrci) begin
            csr_v = original & ~{27'b0, instr.rs1};
         end
      end
   endfunction 


   /////////////////////
   // main
   /////////////////////

   assign o_satp = _satp;
   assign o_cpu_mode = cpu_mode;
   assign o_mxr = _mstatus[19];
   assign o_sum = _mstatus[18];
   
   
   initial begin
      init();
   end
   
   always @(posedge clk) begin
      if(rstn) begin
         if (state == INIT) begin
            state <= FETCH;
            fetch_enabled <= 1;
         end else if (state == FETCH && is_fetch_done) begin
            _mcycle_full <= _mcycle_full + 1;            
            
            if (mem_exception_enable) begin
               state <= TRAP;               
               exception_number <= mem_exception_vec;
               exception_tval <= mem_exception_tval; 
            end else if (instr_raw == 32'b0) begin // TODO: cover more exception
               raise_illegal_instruction(instr_raw);
               state <= TRAP;
            end else begin
               state <= DECODE;
            end
         end else if (state == DECODE && is_decode_done) begin
            instr <= instr_d_out;
            register <= register_d_out;
            // reset previous results ... d -> e
            exec_enabled <= 1;    
            
            if (instr_d_out.csrop) begin
               state <= EXEC_PRIV;           
               {is_csr_valid, csr_value} <= read_csr(instr_d_out.imm[11:0]);                         
            end else if (instr_d_out.rv32a) begin               
               state <= EXEC_ATOM1;
               // NOTE:
               // amo* rd, rs1, rs2 can be splited into ... (pseudo-code)
               // lw rd, (rs1)
               // op tmp, rs2, rd
               // sw tmp, (rs1)
               
               // start to load (rs1) ... d -> m
               mem_enabled <= 1;          
               mem_arg <= register_d_out.rs1; // load addr: rs1
            end else begin
               state <= EXEC;
            end
         end else if (state == EXEC_ATOM1 && is_mem_done) begin   
            exec_enabled <= 0;         
            state <= EXEC_ATOM2;
            
            // prepare to write ... m -> w
            // here we do not enable write yet
            data_to_write <= mem_result;

            // start to store ... m -> (binop)-> m
            // op tmp, rs2, rd -> sw tmp, (rs1)
            mem_enabled <= 1;                    
            mem_arg <= instr.amoswap? register.rs2:
                       instr.amoadd? mem_result + register.rs2:
                       instr.amoand? mem_result & register.rs2:
                       instr.amoor? mem_result | register.rs2:
                       instr.amoxor? mem_result ^ register.rs2:
                       instr.amomax? ($signed(mem_result) > $signed(register.rs2)? mem_result:
                                      register.rs2):
                       instr.amomin? ($signed(mem_result) > $signed(register.rs2)? register.rs2:
                                      mem_result):
                       instr.amomaxu? (mem_result > register.rs2? mem_result:
                                       mem_result):
                       instr.amominu? (mem_result > register.rs2? register.rs2:
                                       mem_result):
                       0;
         end else if (state == EXEC_ATOM2 && is_mem_done) begin
            state <= WRITE;

            // start to write ... args are prepared when it leaves from EXEC_ATOM1
            write_enabled <= 1;
         end else if (state == EXEC_PRIV) begin 
            exec_enabled <= 0;
            if (is_csr_valid) begin
               state <= WRITE;

               write_csr(instr.imm[11:0], csr_v(csr_value));

               // start to write ... e -> w
               write_enabled <= 1;
               data_to_write <= csr_value;          
            end else begin
               // invalid_csr_addr ... instr.imm[11:0]
               raise_illegal_instruction(instr_raw);
               state <= TRAP;                  
            end
         end else if (state == EXEC && is_exec_done) begin
            exec_enabled <= 0;
            // TODO(future): implement wfi correctly.
            // Although the spec says regarding wfi as nop is legal...
            if (is_jump_chosen && jump_dest[1:0] != 2'b0) begin
               state <= TRAP;
               raise_instruction_address_misaligned(jump_dest);
            end else if (instr.fence || instr.fencei || instr.wfi) begin
               state <= WRITE;
               write_enabled <= 1;
            end else if (instr.mret) begin
               state <= TRAP;                  
               if (cpu_mode >= CPU_M) begin
                  // TODO(tentative): is there any process to be done?
               end else begin
                  raise_illegal_instruction(instr_raw);            
               end
            end else if (instr.sret) begin
               state <= TRAP;                  
               if (cpu_mode >= CPU_S) begin
                  // TODO(tentative): is there any process to be done?
               end else begin
                  raise_illegal_instruction(instr_raw);            
               end
            end else if(instr.ecall) begin
               state <= TRAP;               
               raise_ecall();
            end else if (instr.ebreak) begin
               state <= TRAP;               
               raise_ebreak();               
            end else begin
               state <= MEM;
               // start to operate mem ... e -> m
               mem_enabled <= 1;
               mem_arg <= exec_result;   
            end                        
         end else if (state == MEM && is_mem_done) begin
            mem_enabled <= 0;    
            if (mem_exception_enable) begin
               state <= TRAP;               
               exception_number <= mem_exception_vec;
               exception_tval <= mem_exception_tval;               
            end else begin
               state <= WRITE;
               // start to write ... m -> w
               write_enabled <= 1;
               data_to_write <= mem_result;
            end
         end else if (state == WRITE && is_write_done) begin
            write_enabled <= 0;
            if (is_interrupted) begin
               state <= TRAP;            
            end else begin
               init_stage_states();
               if (is_jump_chosen) begin
                  fetch_enabled <= 1;
                  state <= FETCH;
                  pc <= jump_dest;
               end else begin
                  fetch_enabled <= 1;
                  state <= FETCH;
                  pc <= pc + 4;
               end
            end              
         end else if (state == TRAP) begin
            fetch_enabled <= 1;
            state <= FETCH;
            init_stage_states();
            
            if (is_interrupted) begin
               // trap by interrupts (async)
               // when a trap is taken from y to x, 
               // xstatus.mie <= 0;
               // xstatus.mpie <= xstatus.mie;
               // xstatus.mpp <= y;
               // NOTE: is the value of *epc correct?
               // TODO(linux): cover all patterns of interrupt
               cpu_mode <= cpu_mode_base.next(next_cpu_mode_when_interrupted);
               set_pc_by_tvec(1'b1, next_cpu_mode_when_interrupted, exception_vec_when_interrupted);
               
               set_epc(next_cpu_mode_when_interrupted, instr.pc);                  
               set_cause(next_cpu_mode_when_interrupted, {1'b1, exception_vec_when_interrupted[30:0]});
               set_tval(next_cpu_mode_when_interrupted, 32'd0);
               set_mstatus_by_trap(next_cpu_mode_when_interrupted);               
            end else if (instr.mret) begin
               // trap by instruction (sync)
               // mstatus.mie <= mstatus.mpie;
               // mstatus.mpie <= 1;
               // mstatus.mpp <= 0;
               cpu_mode <= cpu_mode_base.next(_mstatus_mpp);               
               pc <= _mepc;
               set_mstatus_by_mret();               
            end else if (instr.sret) begin               
               // trap by instruction (sync)
               // mstatus.sie <= mstatus.spie;
               // mstatus.spie <= 1;
               // mstatus.spp <= 0;
               cpu_mode <= cpu_mode_base.next(_mstatus_spp);               
               pc <= _sepc;
               set_mstatus_by_sret();               
            end else begin
               // trap by exception (sync)
               cpu_mode <= cpu_mode_base.next(next_cpu_mode_when_exception);
               set_pc_by_tvec(1'b0, next_cpu_mode_when_exception, 32'b0);
               
               set_epc(next_cpu_mode_when_exception, pc);                  
               set_cause(next_cpu_mode_when_exception, {27'b0, exception_number});
               set_tval(next_cpu_mode_when_exception, exception_tval);
               set_mstatus_by_trap(next_cpu_mode_when_exception);               
            end
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
