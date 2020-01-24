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
   input wire [31:0]  mresp_data);

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

                        .register(register_de_out));

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
   reg [31:0]         _time;
   reg [31:0]         _timeh;
      
   // program counter
   reg [31:0]         pc;
   enum reg [3:0]     {FETCH, DECODE, EXEC, MEM, WRITE, ATOM1, ATOM2, EXCEPTION} state;
   

   // fetch stage
   /////////
   // control flags
   (* mark_debug = "true" *) reg                fetch_enabled;
   (* mark_debug = "true" *) reg                fetch_reset;
   (* mark_debug = "true" *) wire               is_fetch_done;

   // stage outputs
   wire [31:0]        pc_fd_out;
   wire [31:0]        instr_fd_out;

   fetch _fetch(.clk(clk),
                .rstn(rstn && !fetch_reset),

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

                .pc_n(pc_fd_out),
                .instr_raw(instr_fd_out));

   // decode stage
   /////////
   // control flags
   (* mark_debug = "true" *) reg                decode_enabled;
   (* mark_debug = "true" *) reg                decode_reset;
   (* mark_debug = "true" *) wire               is_decode_done;

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
                    .completed(is_decode_done),

                    .pc(pc_fd_in),
                    .instr_raw(instr_fd_in),

                    .instr(instr_de_out),
                    .rs1(rs1_a),
                    .rs2(rs2_a));

   // exec stage
   /////////
   // control flags
  (* mark_debug = "true" *) reg                exec_enabled;
   (* mark_debug = "true" *) reg                exec_reset;
   (* mark_debug = "true" *) wire               is_exec_done;

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
                    .completed(is_exec_done),

                    .instr(instr_de_in),
                    .register(register_de_in),

                    .instr_n(instr_em_out),
                    .register_n(register_em_out),
                    .result(result_em_out),
                    .is_jump_chosen(is_jump_chosen_em_out),
                    .jump_dest(jump_dest_em_out));

   // mem stage
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
            .completed(is_mem_done),

            .request_enable(mem_request_enable),
            .mode(mreq_mode),
            .addr(mreq_addr),
            .wdata(mreq_wdata),
            .wstrb(mreq_wstrb),
            .response_enable(mem_response_enable),
            .data(mresp_data),

            .instr(instr_em_in),
            .register(register_em_in),
            .target_addr(result_em_in),
            .instr_n(instr_mw_out),
            .result(result_mw_out));

   // write stage
   /////////
   // control flags
   (* mark_debug = "true" *) reg                write_enabled;
   (* mark_debug = "true" *) reg                write_reset;
   (* mark_debug = "true" *) wire               is_write_done;

   // stage input
   instructions instr_mw_in;
   reg [31:0]         result_mw_in;

   write _write(.clk(clk),
                .rstn(rstn && !write_reset),

                .enabled(write_enabled),
                .instr(instr_mw_in),
                .data(result_mw_in),

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

         state <= FETCH;         
      end
   endtask

   task clear_reset;
      begin
         fetch_reset <= 0;
         decode_reset <= 0;
         exec_reset <= 0;
         mem_reset <= 0;
         write_reset <= 0;
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
   endtask

   /////////////////////
   // main
   /////////////////////
   initial begin
      init();
   end

   always @(posedge clk) begin
      if(rstn) begin
         if (is_fetch_done) begin
            pc_fd_in <= pc_fd_out;
            instr_fd_in <= instr_fd_out;
            fetch_reset <= 1;
            decode_enabled <= 1;
            state <= DECODE;            
         end else if (is_decode_done) begin
            instr_de_in <= instr_de_out;
            register_de_in <= register_de_out;
            decode_reset <= 1;
            exec_enabled <= 1;
            state <= EXEC;            
         end else if (is_exec_done) begin
            instr_em_in <= instr_em_out;
            register_em_in <= register_em_out;
            result_em_in <= result_em_out;
            if (is_jump_chosen_em_out) begin
               pc <= jump_dest_em_out;
            end else begin
               pc <= pc + 4;
            end
            exec_reset <= 1;
            mem_enabled <= 1;
            state <= MEM;            
         end else if (is_mem_done) begin
            instr_mw_in <= instr_mw_out;
            result_mw_in <= result_mw_out;
            mem_reset <= 1;
            write_enabled <= 1;
            state <= WRITE;            
         end else if (is_write_done) begin
            write_reset <= 1;
            fetch_enabled <= 1;
            state <= FETCH;            
         end else begin
            clear_enabled();
            clear_reset();
         end
      end else begin
         init();
      end
   end
endmodule
`default_nettype wire
