`default_nettype none
`include "def.sv"

module core_wrapper
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

core _core(.clk(clk),
           .rstn(rstn),

           .fetch_request_enable(fetch_request_enable),
           .fetch_request(fetch_request),
           .fetch_response_enable(fetch_response_enable),
           .fetch_response(fetch_response),

           .mem_request_enable(mem_request_enable),
           .mem_request(mem_request),
           .mem_response_enable(mem_response_enable),
           .mem_response(mem_response));
endmodule

`default_nettype wire
