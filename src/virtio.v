`default_nettype none

module virtio_wrapper(
                      // general
	                  input wire         clk,
	                  input wire         rstn,

                      // bus for core
	                  input wire [31:0]  core_araddr,
	                  output wire        core_arready,
	                  input wire         core_arvalid,
	                  input wire [2:0]   core_arprot,

	                  output wire [31:0] core_rdata,
	                  input wire         core_rready,
	                  output wire [1:0]  core_rresp,
	                  output wire        core_rvalid,

	                  input wire         core_bready,
	                  output wire [1:0]  core_bresp,
	                  output wire        core_bvalid,

	                  input wire [31:0]  core_awaddr,
	                  output wire        core_awready,
	                  input wire         core_awvalid,
	                  input wire [2:0]   core_awprot,

	                  input wire [31:0]  core_wdata,
	                  output wire        core_wready,
	                  input wire [3:0]   core_wstrb,
	                  input wire         core_wvalid,

                      // bus for mem
                      output wire        mem_request_enable,
                      output wire        mem_mode,
                      output wire [31:0] mem_addr,
                      output wire [31:0] mem_wdata,
                      output wire [3:0]  mem_wstrb, 
                      input wire         mem_response_enable,
                      input wire [31:0]  mem_data,

                      // bus for disk
                      output reg         disk_request_enable,
                      output reg         disk_mode,
                      output reg [31:0]  disk_addr,
                      output reg [31:0]  disk_wdata,
                      output reg [3:0]   disk_wstrb, 
                      input wire         disk_response_enable,
                      input wire [31:0]  disk_data,
                      
                      // general
                      output wire        virtio_interrupt
                      );

   virtio _virtio(
                  .clk(clk),
                  .rstn(rstn),

                  .core_araddr(core_araddr),
                  .core_arready(core_arready),
                  .core_arvalid(core_arvalid),
                  .core_arprot(core_arprot),

                  .core_bready(core_bready),
                  .core_bresp(core_bresp),
                  .core_bvalid(core_bvalid),

                  .core_rdata(core_rdata),
                  .core_rready(core_rready),
                  .core_rresp(core_rresp),
                  .core_rvalid(core_rvalid),

                  .core_awaddr(core_awaddr),
                  .core_awready(core_awready),
                  .core_awvalid(core_awvalid),
                  .core_awprot(core_awprot),

                  .core_wdata(core_wdata),
                  .core_wready(core_wready),
                  .core_wstrb(core_wstrb),
                  .core_wvalid(core_wvalid),

                  .mem_request_enable(mem_request_enable),
                  .mem_mode(mem_mode),
                  .mem_addr(mem_addr),
                  .mem_wdata(mem_wdata),
                  .mem_wstrb(mem_wstrb),
                  .mem_response_enable(mem_response_enable),
                  .mem_data(mem_data),

                  .disk_request_enable(disk_request_enable),
                  .disk_mode(disk_mode),
                  .disk_addr(disk_addr),
                  .disk_wdata(disk_wdata),
                  .disk_wstrb(disk_wstrb),
                  .disk_response_enable(disk_response_enable),
                  .disk_data(disk_data),
                  
                  .virtio_interrupt(virtio_interrupt)
                  );
      
endmodule
`default_nettype wire
