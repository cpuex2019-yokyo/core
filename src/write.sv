`default_nettype none
`include "def.sv"

module write(
           input wire         clk,
           input wire         rstn,

           // control flags
           input wire        enabled,
           output reg        completed,

           // bus
           output wire        reg_w_enable,
           output wire [4:0]  reg_w_dest,
           output wire [31:0] reg_w_data,

           // input
           input              instructions instr,
           input wire [31:0]  data

           // output
           // none
       );

assign reg_w_enable = enabled && instr.writes_to_reg;
assign reg_w_dest = instr.rd;
assign reg_w_data = data;

task init;
    begin
        completed <= 0;
    end
endtask

initial begin
    init();
end

always @(posedge clk) begin
    if (rstn) begin
        if(enabled) begin
            completed <= 1;
        end else begin
            completed <= 0;
        end
    end else begin
        init();
    end
end
endmodule
`default_nettype none
