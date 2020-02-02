`default_nettype none

module mmu_wrapper (
                    input wire         clk,
                    input wire         rstn,

                    input wire [31:0]  satp,
                    input wire [1:0]   cpu_mode,
                    input wire         mxr,
                    input wire         sum,

                    input wire         fetch_request_enable,
                    input wire         freq_mode,
                    input wire [31:0]  freq_addr,
                    input wire [31:0]  freq_wdata,
                    input wire [3:0]   freq_wstrb,
                    output reg         fetch_response_enable,
                    output reg [31:0]  fresp_data,

                    input wire         mem_request_enable,
                    input wire         mreq_mode,
                    input wire [31:0]  mreq_addr,
                    input wire [31:0]  mreq_wdata,
                    input wire [3:0]   mreq_wstrb,
                    output reg         mem_response_enable,
                    output reg [31:0]  mresp_data,

                    output reg [4:0]   exception_vec,
                    output reg         page_fault, 

                    output wire        request_enable,
                    output wire        req_mode,
                    output wire [31:0] req_addr,
                    output wire [31:0] req_wdata,
                    output wire [3:0]  req_wstrb,
                    input wire         response_enable,
                    input wire [31:0]  resp_data
                    );

   
   mmu _mmu(.clk(clk), .rstn(rstn),

            .satp(satp),
            .cpu_mode(cpu_mode),
            .mxr(mxr),
            .sum(sum),
      
            .fetch_request_enable(fetch_request_enable),
            .freq_mode(freq_mode),
            .freq_addr(freq_addr),
            .freq_wdata(freq_wdata),
            .freq_wstrb(freq_wstrb),
            .fetch_response_enable(fetch_response_enable),
            .fresp_data(fresp_data),

            .mem_request_enable(mem_request_enable),
            .mreq_mode(mreq_mode),
            .mreq_addr(mreq_addr),
            .mreq_wdata(mreq_wdata),
            .mreq_wstrb(mreq_wstrb),
            .mem_response_enable(mem_response_enable),
            .mresp_data(mresp_data),

            .exception_vec(exception_vec),
            .page_fault(page_fault),

            .request_enable(request_enable),
            .req_mode(req_mode),
            .mreq_addr(req_addr),
            .req_wdata(req_wdata),
            .req_wstrb(req_wstrb),
            .response_enable(response_enable),
            .resp_data(resp_data));   


endmodule
`default_nettype wire