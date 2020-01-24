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
           output            memreq request,
           input wire        response_enable,
           input             memresp response,

           // input
           input             instructions instr,
           input             regvpair register,
           input wire [31:0] addr,

           // output
           output            instructions instr_n,
           output reg [31:0] result);


localparam WAITING_REQUEST = 0;
localparam WAITING_DONE = 1;
reg                       state;

task init;
    begin
        completed <= 0;
        state <= WAITING_REQUEST;
    end
endtask

initial begin
    init();
end

always @(posedge clk) begin
    if(rstn) begin
        if (state == WAITING_REQUEST && enabled) begin
            instr_n <= instr;

            if (instr.is_load) begin
                completed <= 0;

                state <= WAITING_DONE;
                request.mode <= MEMREQ_READ;
                request.addr <= {addr[31:2], 2'b0};
                request_enable <= 1;
            end else if (instr.is_store) begin
                completed <= 0;

                state <= WAITING_DONE;
                request.mode <= MEMREQ_WRITE;
                request.addr <= {addr[31:2], 2'b0};

                if(instr.sb) begin
                    case(addr[1:0])
                        2'b11 : begin
                            request.wstrb <= 4'b1000;
                            request.wdata <= {register.rs2[7:0], 24'b0};
                        end
                        2'b10 : begin
                            request.wstrb <= 4'b0100;
                            request.wdata <= {8'b0, register.rs2[7:0], 16'b0};
                        end
                        2'b01 : begin
                            request.wstrb <= 4'b0010;
                            request.wdata <= {16'b0, register.rs2[7:0], 8'b0};
                        end
                        2'b00 : begin
                            request.wstrb <= 4'b0001;
                            request.wdata <= {24'b0, register.rs2[7:0]};
                        end
                    endcase
                end else if (instr.sh) begin
                    case(addr[1:0])
                        2'b10 : begin
                            request.wstrb <= 4'b1100;
                            request.wdata <= {register.rs2[15:0], 16'b0};
                        end
                        2'b00 : begin
                            request.wstrb <= 4'b0011;
                            request.wdata <= {16'b0, register.rs2[15:0]};
                        end
                    endcase
                end  else if (instr.sw) begin
                    request.wstrb <= 4'b1111;
                    request.wdata <= register.rs2;
                end
            end else begin
                completed <= 1;
            end
        end else if (state == WAITING_DONE && response_enable) begin
            completed <= 1;
            state <= WAITING_REQUEST;

            if (instr_n.lb) begin
                case(addr[1:0])
                    2'b11: result <= {{24{response.data[31]}}, response.data[31:24]};
                    2'b10: result <= {{24{response.data[23]}}, response.data[23:16]};
                    2'b01: result <= {{24{response.data[15]}}, response.data[15:8]};
                    2'b00: result <= {{24{response.data[7]}}, response.data[7:0]};
                    default: result <= 32'b0;
                endcase
            end else if (instr_n.lh) begin
                case(addr[1:0])
                    2'b10 : result <= {{16{response.data[31]}}, response.data[31:16]};
                    2'b00 : result <= {{16{response.data[15]}}, response.data[15:0]};
                    default: result <=  32'b0;
                endcase
            end else if (instr_n.lw) begin
                result <= response.data;
            end else if (instr_n.lbu) begin
                case(addr[1:0])
                    2'b11: result = {24'b0, response.data[31:24]};
                    2'b10: result <= {24'b0, response.data[23:16]};
                    2'b01: result <= {24'b0, response.data[15:8]};
                    2'b00: result <= {24'b0, response.data[7:0]};
                    default: result <= 32'b0;
                endcase
            end else if (instr_n.lhu) begin
                case(addr[1:0])
                    2'b10 : result <= {16'b0, response.data[31:16]};
                    2'b00 : result <= {16'b0, response.data[15:0]};
                    default: result <= 32'b0;
                endcase
            end else begin
                result <= 32'b0;
            end
        end else begin
            completed <= 0;
        end
    end else begin
        init();
    end
end
endmodule
`default_nettype wire
