module mem(
           input wire        clk,
           input wire        rstn,

           input wire        enabled,
           input             instructions instr,
           input             regvpair register,

           input wire [31:0] addr,

           // Bus for MMU
           // address read channel
           output reg [31:0] axi_araddr,
           input wire        axi_arready,
           output reg        axi_arvalid,
           output reg [2:0]  axi_arprot, 

           // response channel
           output reg        axi_bready,
           input wire [1:0]  axi_bresp,
           input wire        axi_bvalid,

           // read data channel
           input wire [31:0] axi_rdata,
           output reg        axi_rready,
           input wire [1:0]  axi_rresp,
           input wire        axi_rvalid,

           // address write channel
           output reg [31:0] axi_awaddr,
           input wire        axi_awready,
           output reg        axi_awvalid,
           output reg [2:0]  axi_awprot, 

           // data write channel
           output reg [31:0] axi_wdata,
           input wire        axi_wready,
           output reg [3:0]  axi_wstrb,
           output reg        axi_wvalid,

           output wire       completed,
           output            instructions instr_n,
           output reg [31:0] result);
   
   reg                       _completed;
   
   assign completed = _completed & !enabled;
   
   reg [3:0]                 mem_state;
   localparam mem_r_waiting_ready = 1;
   localparam mem_r_waiting_data = 2;

   
   localparam mem_w_waiting_ready = 3;
   localparam mem_w_waiting_data = 4;   

   initial begin
      axi_wvalid <= 0;
      axi_awvalid <= 0;
      
      axi_arvalid <= 0;
      
      axi_bready <= 0;
      axi_rready <= 0;      
   end
   
   always @(posedge clk) begin
      if(rstn) begin
         if (enabled) begin
            instr_n <= instr;
            result <= addr;            
            
            if (instr.is_load) begin
               _completed <= 0;            
               axi_araddr <= {addr[31:2], 2'b0};
               axi_arprot <= 3'b000;                  
               axi_arvalid <= 1;
               mem_state <= mem_r_waiting_ready;               
            end else if (instr.is_store) begin
               _completed <= 0;            
               axi_awaddr <= {addr[31:2], 2'b0}; // rs1 + imm
               axi_awprot <= 3'b000;                  
               axi_awvalid <= 1;
               
               if(instr.sb) begin 
                  case(addr[1:0])
                    2'b11 : begin 
                       axi_wstrb <= 4'b1000;
                       axi_wdata <= {register.rs2[7:0], 24'b0};
                    end
                    2'b10 : begin
                       axi_wstrb <= 4'b0100;
                       axi_wdata <= {8'b0, register.rs2[7:0], 16'b0};
                    end
                    2'b01 : begin
                       axi_wstrb <= 4'b0010;
                       axi_wdata <= {16'b0, register.rs2[7:0], 8'b0};
                    end
                    2'b00 : begin
                       axi_wstrb <= 4'b0001;
                       axi_wdata <= {24'b0, register.rs2[7:0]};
                    end
                    default : begin    
                       // TODO                         
                    end
                  endcase	
               end else if (instr.sh) begin
                  case(addr[1:0])
                    2'b10 : begin
                       axi_wstrb <= 4'b1100;
                       axi_wdata <= {register.rs2[15:0], 16'b0};
                    end
                    2'b00 : begin
                       axi_wstrb <= 4'b0011;
                       axi_wdata <= {16'b0, register.rs2[15:0]};
                    end
                    default : begin
                       // TODO                          
                    end
                  endcase
               end  else if (instr.sw) begin
                  axi_wstrb <= 4'b1111;
                  axi_wdata <= register.rs2;                  
               end else begin
                  // TODO    
               end
               axi_wvalid <= 1;
               mem_state <= mem_w_waiting_ready;
            end else begin
               _completed <= 1;               
            end
         end else if (mem_state == mem_r_waiting_ready) begin
            if (axi_arready) begin
               axi_arvalid <= 0;
               axi_rready <= 1;                  
               mem_state <= mem_r_waiting_data;                  
            end
         end else if (mem_state == mem_r_waiting_data) begin
            if (axi_rvalid) begin
               axi_rready <= 0;
               if (instr_n.lb) begin
                  case(addr[1:0])
                    2'b11: result <= {{24{axi_rdata[31]}}, axi_rdata[31:24]};
                    2'b10: result <= {{24{axi_rdata[23]}}, axi_rdata[23:16]};
                    2'b01: result <= {{24{axi_rdata[15]}}, axi_rdata[15:8]};
                    2'b00: result <= {{24{axi_rdata[7]}}, axi_rdata[7:0]};
                    default: result <= 32'b0;                       
                  endcase
               end else if (instr_n.lh) begin
                  case(addr[1:0])
                    2'b10 : result <= {{16{axi_rdata[31]}}, axi_rdata[31:16]};
                    2'b00 : result <= {{16{axi_rdata[15]}}, axi_rdata[15:0]};
                    default: result <=  32'b0;                       
                  endcase
               end else if (instr_n.lw) begin
                  result <= axi_rdata;       
               end else if (instr_n.lbu) begin                     
                  case(addr[1:0])
                    2'b11: result = {24'b0, axi_rdata[31:24]};
                    2'b10: result <= {24'b0, axi_rdata[23:16]};
                    2'b01: result <= {24'b0, axi_rdata[15:8]};
                    2'b00: result <= {24'b0, axi_rdata[7:0]};
                    default: result <= 32'b0;                       
                  endcase
               end else if (instr_n.lhu) begin
                  case(addr[1:0])
                    2'b10 : result <= {16'b0, axi_rdata[31:16]};
                    2'b00 : result <= {16'b0, axi_rdata[15:0]};
                    default: result <= 32'b0;                       
                  endcase
               end
               _completed <= 1;                  
            end               
         end else if (mem_state == mem_w_waiting_ready) begin
            if(axi_awready) begin
               axi_awvalid <= 0;
            end
            if(axi_wready) begin
               axi_wvalid <= 0;
            end
            if(!axi_awvalid && !axi_wvalid) begin
               axi_bready <= 1;
               mem_state <= mem_w_waiting_data;                  
            end               
         end else if (mem_state == mem_w_waiting_data) begin
            if (axi_bvalid) begin
               axi_bready <= 0;                  
               _completed <= 1;
            end
         end
      end else begin 
         _completed <= 0;         
      end // else: !if(enabled)
   end
endmodule
