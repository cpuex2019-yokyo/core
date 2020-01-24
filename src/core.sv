`default_nettype none
`include "def.sv"

module core
       (input wire clk,
        input wire         rstn,

        output wire        fetch_request_enable,
        output            memreq fetch_request,
        input wire        fetch_response_enable,
        input             memresp fetch_response,

        output wire        mem_request_enable,
        output            memreq mem_request,
        input wire        mem_response_enable,
        input            memresp mem_response);


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
// TODO

// program counter
reg [31:0]         pc;


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
             .request(fetch_request),
             .response_enable(fetch_response_enable),
             .response(fetch_response),

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
         .request(mem_request),
         .response_enable(mem_response_enable),
         .response(mem_response),

         .instr(instr_em_in),
         .register(register_em_in),
         .addr(result_em_in),
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
        end else if (is_decode_done) begin
            instr_de_in <= instr_de_out;
            register_de_in <= register_de_out;
            decode_reset <= 1;
            exec_enabled <= 1;
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
        end else if (is_mem_done) begin
            instr_mw_in <= instr_mw_out;
            result_mw_in <= result_mw_out;
            mem_reset <= 1;
            write_enabled <= 1;
        end else if (is_write_done) begin
            write_reset <= 1;
            fetch_enabled <= 1;
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
