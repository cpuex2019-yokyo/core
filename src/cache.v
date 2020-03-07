`default_nettype none

module cache_controller(
			input wire 	   clk,
			input wire 	   rstn,

			// slave end
			////////////////

			// address read channel
			input wire [31:0]  s_axi_araddr,
			output reg 	   s_axi_arready,
			input wire 	   s_axi_arvalid,
			input wire [2:0]   s_axi_arprot,

			// response channel
			input wire 	   s_axi_bready,
			output reg [1:0]   s_axi_bresp,
			output reg 	   s_axi_bvalid,

			// read data channel
			output reg [31:0]  s_axi_rdata,
			input wire 	   s_axi_rready,
			output reg [1:0]   s_axi_rresp,
			output reg 	   s_axi_rvalid,

			// address write channel
			input wire [31:0]  s_axi_awaddr,
			output reg 	   s_axi_awready,
			input wire 	   s_axi_awvalid,
			input wire [2:0]   s_axi_awprot,

			// data write channel
			input wire [31:0]  s_axi_wdata,
			output reg 	   s_axi_wready,
			input wire [3:0]   s_axi_wstrb,
			input wire 	   s_axi_wvalid,


			// master end
			////////////////

			// addres read channel
			output reg [31:0]  m_axi_araddr,
			input wire 	   m_axi_arready,
			output reg 	   m_axi_arvalid,
			output reg [2:0]   m_axi_arprot,


			// response channel
			output reg 	   m_axi_bready,
			input wire [1:0]   m_axi_bresp,
			input wire 	   m_axi_bvalid,


			// read data channel
			input wire [63:0]  m_axi_rdata,
			output reg 	   m_axi_rready,
			input wire [1:0]   m_axi_rresp,
			input wire 	   m_axi_rvalid,


			// address write channel
			output reg [31:0]  m_axi_awaddr,
			input wire 	   m_axi_awready,
			output reg 	   m_axi_awvalid,
			output reg [2:0]   m_axi_awprot,


			// data write channel
			output reg [63:0]  m_axi_wdata,
			input wire 	   m_axi_wready,
			output reg [7:0]   m_axi_wstrb,
			output reg 	   m_axi_wvalid);


   // bram read/write channel
   // 4 way set associative
   reg [5:0] 			   bram_addr;
   reg [533:0] 			   bram_wdata;
   wire [533:0] 		   bram_rdata0;
   wire [533:0] 		   bram_rdata1;
   wire [533:0] 		   bram_rdata2;
   wire [533:0] 		   bram_rdata3;
   reg 				   ena;
   reg 				   wea0;
   reg 				   wea1;
   reg 				   wea2;
   reg 				   wea3;
   
   // lru table lookup/update channel
   reg [5:0] 			   lrutbl_addr;
   reg [7:0] 			   lrutbl_wdata;
   wire [7:0] 			   lrutbl_rdata;
   reg 				   lrutbl_ena;
   reg 				   lrutbl_wea;

   cache_bram cache_bram_way0(clk, rstn, ena, wea0, bram_addr, bram_wdata, bram_rdata0);
   cache_bram cache_bram_way1(clk, rstn, ena, wea1, bram_addr, bram_wdata, bram_rdata1);
   cache_bram cache_bram_way2(clk, rstn, ena, wea2, bram_addr, bram_wdata, bram_rdata2);
   cache_bram cache_bram_way3(clk, rstn, ena, wea3, bram_addr, bram_wdata, bram_rdata3);

   lrutbl lrutbl(clk, rstn, lrutbl_ena, lrutbl_wea, lrutbl_addr, lrutbl_wdata, lrutbl_rdata);


   // slave states
   localparam INITIALIZE = 0;
   localparam WAITING_MASTER_REQUEST = 1;
   localparam WAITING_MASTER_RREADY = 2;
   localparam WAITING_MASTER_AWVALID = 3;
   localparam WAITING_MASTER_WVALID = 4;
   localparam WAITING_MASTER_BREADY = 5;
   localparam PRE_READ = 6;
   localparam MEM_READ = 7;
   localparam HOLD_READ = 8;
   localparam PRE_WRITE = 9;
   localparam MEM_WRITE = 10;
   localparam HOLD_WRITE = 11;
   reg [6:0] 				   counter; // used when s_state = INITIALIZE
   reg 					   cache_miss;
   reg [3:0] 				   s_state;


   // master states
   localparam IDLE = 0;
   localparam WAITING_SLAVE_WREADY = 1;
   localparam WAITING_SLAVE_BVALID = 2;
   localparam WAITING_SLAVE_ARREADY = 3;
   localparam WAITING_SLAVE_RVALID = 4;
   reg [3:0] 				   m_state;
   reg [2:0] 				   m_counter;
   reg [511:0] 				   m_buff;


   // cache miss handler states
   localparam HANDLER_ENTRY = 0;
   localparam WRITE_BACK = 1;
   localparam FETCH = 2;
   localparam CACHE_WRITE = 3;
   localparam HOLD_WEA = 4;
   localparam DEASSERT_SIGNALS = 5;
   reg [3:0] 				   handler_state;


   // addres slices
   ////////////////

   function [19:0] a_tag (input [31:0] addr);
      begin
	 a_tag = addr[31:12];
      end
   endfunction // a_tag


   function [5:0] a_index (input [31:0] addr);
      begin
	 a_index = addr[11:6];
      end
   endfunction // a_index


   function [3:0] a_ofs(input [31:0] addr);
      begin
	 a_ofs = addr[5:2];
      end
   endfunction


   // cache block slicees
   /////////////////

   function b_valid (input [533:0] block);
      begin
	 b_valid = block[533];
      end
   endfunction // b_valid


   function b_dirty (input [533:0] block);
      begin
	 b_dirty = block[532];
      end
   endfunction // b_dirty


   function [19:0] b_tag (input [533:0] block);
      begin
	 b_tag = block[531:512];
      end
   endfunction // b_tag


   function [511:0] b_data (input [533:0] block);
      begin
	 b_data = block[511:0];
      end
   endfunction // b_data


   // cache utils
   //////////////


   // returns a one hot hit vector
   function [3:0] cache_hit (input [19:0] tag, input [533:0] b0, input [533:0] b1,
			     input [533:0] b2, input [533:0] b3);
      begin
	 cache_hit = { b_valid(b3) & (tag == b_tag(b3)), b_valid(b2) & (tag == b_tag(b2)), 
		       b_valid(b1) & (tag == b_tag(b1)), b_valid(b0) & (tag == b_tag(b0)) };
      end
   endfunction // cache_hit


   // find actual 32 bit word from cache block
   function [31:0] extract_rdata(input [3:0] ofs, input [511:0] data);
      begin
	 extract_rdata = (ofs == 4'b0000) ? data[31:0] :
			 (ofs == 4'b0001) ? data[63:32] :
			 (ofs == 4'b0010) ? data[95:64] :
			 (ofs == 4'b0011) ? data[127:96] :
			 (ofs == 4'b0100) ? data[159:128] :
			 (ofs == 4'b0101) ? data[191:160] :
			 (ofs == 4'b0110) ? data[223:192] :
			 (ofs == 4'b0111) ? data[255:224] :
			 (ofs == 4'b1000) ? data[287:256] :
			 (ofs == 4'b1001) ? data[319:288] :
			 (ofs == 4'b1010) ? data[351:320] :
			 (ofs == 4'b1011) ? data[383:352] :
			 (ofs == 4'b1100) ? data[415:384] :
			 (ofs == 4'b1101) ? data[447:416] :
			 (ofs == 4'b1110) ? data[479:448] :
			 /* when (ofs == 4'b1111) */ data[511:480];
      end
   endfunction // extract_rdata


   function [31:0] mask_strb (input [31:0] wdata, input [3:0] wstrb);
      begin
	 mask_strb = { {8{wstrb[3]}}, {8{wstrb[2]}}, {8{wstrb[1]}}, {8{wstrb[0]}} } & wdata;
      end
   endfunction // mask_strb


   // extend wdata to 512 bit with 0s outside wdata & i-th byte on wdata with wstrb[i] = 0
   function [511:0] mask_extend_wdata(input [3:0] ofs, input[31:0] wdata, input [3:0] wstrb);
      begin
	 mask_extend_wdata = (ofs == 4'b0000) ? { {480{1'b0}}, mask_strb(wdata, wstrb) } :
	 		     (ofs == 4'b0001) ? { {448{1'b0}}, mask_strb(wdata, wstrb), {32{1'b0}} } :
			     (ofs == 4'b0010) ? { {416{1'b0}}, mask_strb(wdata, wstrb), {64{1'b0}} } :
			     (ofs == 4'b0011) ? { {384{1'b0}}, mask_strb(wdata, wstrb), {96{1'b0}} } :
			     (ofs == 4'b0100) ? { {352{1'b0}}, mask_strb(wdata, wstrb), {128{1'b0}} } :
			     (ofs == 4'b0101) ? { {320{1'b0}}, mask_strb(wdata, wstrb), {160{1'b0}} } :
			     (ofs == 4'b0110) ? { {288{1'b0}}, mask_strb(wdata, wstrb), {192{1'b0}} } :
			     (ofs == 4'b0111) ? { {256{1'b0}}, mask_strb(wdata, wstrb), {224{1'b0}} } :
			     (ofs == 4'b1000) ? { {224{1'b0}}, mask_strb(wdata, wstrb), {256{1'b0}} } :
			     (ofs == 4'b1001) ? { {192{1'b0}}, mask_strb(wdata, wstrb), {288{1'b0}} } :
			     (ofs == 4'b1010) ? { {160{1'b0}}, mask_strb(wdata, wstrb), {320{1'b0}} } :
			     (ofs == 4'b1011) ? { {128{1'b0}}, mask_strb(wdata, wstrb), {352{1'b0}} } :
			     (ofs == 4'b1100) ? { {96{1'b0}}, mask_strb(wdata, wstrb), {384{1'b0}} } :
			     (ofs == 4'b1101) ? { {64{1'b0}}, mask_strb(wdata, wstrb), {416{1'b0}} } :
			     (ofs == 4'b1110) ? { {32{1'b0}}, mask_strb(wdata, wstrb), {448{1'b0}} } :
			     /* when (ofs == 4'b1111) */ { mask_strb(wdata, wstrb), {480{1'b0}} };
      end
   endfunction


   // the return bit width of this function was wrongly 33 bit
   // which caused a bug (-> ipad) and now it's fixed to be 32 bit
   // [32:0] -> [31:0]
   function [31:0] invert_replicate_strb(input [3:0] wstrb);
      begin
	 invert_replicate_strb = { {8{~(wstrb[3])}}, {8{~(wstrb[2])}}, {8{~(wstrb[1])}}, {8{~(wstrb[0])}} };
      end
   endfunction // invert_repeat_strb


   // inset invert-extended strobe to the appropriate position in 512 bit
   function [511:0] invert_extend_strb(input [3:0] ofs, input [3:0] wstrb);
      begin
	 invert_extend_strb = (ofs == 4'b0000) ? { {480{1'b1}}, invert_replicate_strb(wstrb) } :
			      (ofs == 4'b0001) ? { {448{1'b1}}, invert_replicate_strb(wstrb), {32{1'b1}} } :
			      (ofs == 4'b0010) ? { {416{1'b1}}, invert_replicate_strb(wstrb), {64{1'b1}} } :
			      (ofs == 4'b0011) ? { {384{1'b1}}, invert_replicate_strb(wstrb), {96{1'b1}} } :
			      (ofs == 4'b0100) ? { {352{1'b1}}, invert_replicate_strb(wstrb), {128{1'b1}} } :
			      (ofs == 4'b0101) ? { {320{1'b1}}, invert_replicate_strb(wstrb), {160{1'b1}} } :
			      (ofs == 4'b0110) ? { {288{1'b1}}, invert_replicate_strb(wstrb), {192{1'b1}} } :
			      (ofs == 4'b0111) ? { {256{1'b1}}, invert_replicate_strb(wstrb), {224{1'b1}} } :
			      (ofs == 4'b1000) ? { {224{1'b1}}, invert_replicate_strb(wstrb), {256{1'b1}} } :
			      (ofs == 4'b1001) ? { {192{1'b1}}, invert_replicate_strb(wstrb), {288{1'b1}} } :
			      (ofs == 4'b1010) ? { {160{1'b1}}, invert_replicate_strb(wstrb), {320{1'b1}} } :
			      (ofs == 4'b1011) ? { {128{1'b1}}, invert_replicate_strb(wstrb), {352{1'b1}} } :
			      (ofs == 4'b1100) ? { {96{1'b1}}, invert_replicate_strb(wstrb), {384{1'b1}} } :
			      (ofs == 4'b1101) ? { {64{1'b1}}, invert_replicate_strb(wstrb), {416{1'b1}} } :
			      (ofs == 4'b1110) ? { {32{1'b1}}, invert_replicate_strb(wstrb), {448{1'b1}} } :
			      /* when(ofs == 4'b1111) */ { invert_replicate_strb(wstrb), {480{1'b1}} };
      end
   endfunction


   // insert wdata to the correct 32 word section in the data slice of a cache block
   function [511:0] insert_wdata(input [3:0] ofs, input [511:0] data, input [31:0] wdata, input [3:0] wstrb);
      begin
	 insert_wdata = (data & invert_extend_strb(ofs, wstrb)) | mask_extend_wdata(ofs, wdata, wstrb);
      end
   endfunction


   // hit block in a set <- 4way set associative
   function [533:0] hit_block(input [19:0] tag, input [533:0] b0, input [533:0] b1,
			      input [533:0] b2, input [533:0] b3);
      begin
	 hit_block = (b_valid(b0) & (tag == b_tag(b0))) ? b0 :
		     (b_valid(b1) & (tag == b_tag(b1))) ? b1 :
		     (b_valid(b2) & (tag == b_tag(b2))) ? b2 :
		     (b_valid(b3) & (tag == b_tag(b3))) ? b3 :
		     534'b0; // default : no hit block exists
      end
   endfunction // hit_block


   // hit block's data segment
   function [511:0] hit_data (input [19:0] tag, input [533:0] b0, input [533:0] b1,
			      input [533:0] b2, input [533:0] b3);
      begin
	 hit_data = b_data(hit_block(tag, b0, b1, b2, b3));
      end
   endfunction // hit_data


   // hit block's tag segment
   function [19:0] hit_tag (input [19:0] tag, input [533:0] b0, input [533:0] b1,
			    input [533:0] b2, input [533:0] b3);
      begin
	 hit_tag = b_tag(hit_block(tag, b0, b1, b2, b3));
      end
   endfunction // hit_tag


   // one hot 4 bit vector -> 2 bit binary encoder
   function [1:0] used_way (input [3:0] hit_vec);
      begin
	 used_way = (hit_vec == 4'b0001) ? 2'b00 :
		    (hit_vec == 4'b0010) ? 2'b01 :
		    (hit_vec == 4'b0100) ? 2'b10 :
		    (hit_vec == 4'b1000) ? 2'b11 :
		    /* default */ 2'b00;
      end
   endfunction


   // rotate a LRU tabel entry to place the used way as the top of the entry
   function [7:0] new_lrutbl_entry (input [1:0] used_way, input [7:0] ent);
      // LRU table entry : new <-> old
      begin
	 new_lrutbl_entry = (used_way == ent[7:6]) ? ent :
			    (used_way == ent[5:4]) ? { ent[5:4], ent[7:6], ent[3:0] } :
			    (used_way == ent[3:2]) ? { ent[3:2], ent[7:4], ent[1:0] } :
			    /* when (used_set == ent[1:0]) */ { ent[1:0], ent[7:2] };
      end
   endfunction // new_lrutbl_entry


   function [63:0] m_write_data(input [2:0] addr, input [511:0] data);
      begin
	 m_write_data = (addr == 3'b000) ? { data[31:0], data[63:32] } : 
			(addr == 3'b001) ? { data[95:64], data[127:96] } : 
			(addr == 3'b010) ? { data[159:128], data[191:160] } : 
			(addr == 3'b011) ? { data[223:192], data[255:224] } : 
			(addr == 3'b100) ? { data[287:256], data[319:288] } : 
			(addr == 3'b101) ? { data[351:320], data[383:352] } : 
			(addr == 3'b110) ? { data[415:384], data[447:416] } : 
			/* when (addr == 3'b111) */ { data[479:448], data[511:480] };
      end
   endfunction


   // used when reading from ddr4
   function [511:0] m_extend_data(input [2:0] addr, input [63:0] data);
      begin
	 m_extend_data = (addr == 3'b000) ? { {448{1'b0}}, data[31:0], data[63:32] } :
			 (addr == 3'b001) ? { {384{1'b0}}, data[31:0], data[63:32], {64{1'b0}} } :
			 (addr == 3'b010) ? { {320{1'b0}}, data[31:0], data[63:32], {128{1'b0}} } :
			 (addr == 3'b011) ? { {256{1'b0}}, data[31:0], data[63:32], {192{1'b0}} } :
			 (addr == 3'b100) ? { {192{1'b0}}, data[31:0], data[63:32], {256{1'b0}} } :
			 (addr == 3'b101) ? { {128{1'b0}}, data[31:0], data[63:32], {320{1'b0}} } :
			 (addr == 3'b110) ? { {64{1'b0}}, data[31:0], data[63:32], {384{1'b0}} } :
			 /* when (addr = 3'b111) */ { data[31:0], data[63:32], {448{1'b0}} };
      end
   endfunction


   // temporal registers
   reg [31:0] _addr; // address register for the slave end
   reg [31:0] _data; // data register for the slave end
   reg [3:0]  _strb; // strobe register for the slave end
   reg [25:0]  _wb_addr; // ddr4 base address for write back phase
   reg [25:0] _fetch_addr; // for fetch phase in cache miss handling


   // cache controler
   ////////////////

   task s_init;
      begin
	 s_axi_arready <= 0;

	 s_axi_rdata <= 32'b0;
	 s_axi_rresp <= 2'b0;
	 s_axi_rvalid <= 0;

	 s_axi_awready <= 0;
	 s_axi_wready <= 0;

	 s_axi_bresp <= 2'b0;
	 s_axi_bvalid <= 0;

	 _addr <= 32'b0;
	 _data <= 32'b0;
	 _strb <= 4'b0;

	 counter <= 7'b0;
	 cache_miss <= 0;
	 s_state <= INITIALIZE;
      end
   endtask // s_init


   task bram_init;
      begin
	 bram_addr <= 6'b0;
	 bram_wdata <= 534'b0;
	 ena <= 0;
	 wea0 <= 0;
	 wea1 <= 0;
	 wea2 <= 0;
	 wea3 <= 0;

	 lrutbl_addr <= 6'b0;
	 lrutbl_wdata <= 8'b0;
	 lrutbl_ena <= 0;
	 lrutbl_wea <= 0;
      end
   endtask // bram_init


   task handler_init;
      begin
	 _fetch_addr <= 26'b0;

	 handler_state <= HANDLER_ENTRY;
      end
   endtask // handler_init


   task m_init;
      begin
	 m_axi_araddr <= 32'b0;
	 m_axi_arvalid <= 0;
	 m_axi_arprot <= 3'b0;

	 m_axi_rready <= 0;

	 m_axi_bready <= 0;

	 m_axi_awaddr <= 32'b0;
	 m_axi_awvalid <= 0;
	 m_axi_awprot <= 3'b0;

	 m_axi_wdata <= 64'b0;
	 m_axi_wstrb <= 8'b0;
	 m_axi_wvalid <= 0;

	 m_counter <= 3'b0;
	 m_state <= IDLE;
      end
   endtask


   task bram_read_enable(input [5:0] addr);
      begin
	 bram_addr <= addr;
	 ena <= 1;
      end
   endtask


   task lrutbl_read_enable (input [5:0] addr);
      begin
	 lrutbl_addr <= addr;
	 lrutbl_ena <= 1;
      end
   endtask


   task update_lrutbl (input [3:0] hit_vec, input [7:0] lru_ent, input [5:0] addr);
      begin
	 lrutbl_addr <= addr;
	 lrutbl_wdata <= new_lrutbl_entry(used_way(hit_vec), lru_ent);
	 lrutbl_ena <= 1;
	 lrutbl_wea <= 1;
      end
   endtask // update_lrutbl


   task m_validate_write(input [25:0] awaddr, input [2:0] offset, input [511:0] wdata);
      begin
	 m_axi_awaddr <= { awaddr, offset, 3'b0 };
	 m_axi_wdata <= m_write_data(offset, wdata);
	 m_axi_awvalid <= 1;
	 m_axi_awprot <= 3'b0;
	 m_axi_wvalid <= 1;
	 m_axi_wstrb <= { 8{1'b1} };
      end
   endtask


   task m_validate_read(input [25:0] araddr, input [2:0] offset);
      begin
	 m_axi_araddr <= { araddr, offset, 3'b0 };
	 m_axi_arvalid <= 1;
	 m_axi_arprot <= 3'b0;
      end
   endtask // m_validate_read


   // buffer should be cleared befor calling this task
   task m_write_buff(input [2:0] offset, input [63:0] data);
      begin
	 m_buff <= m_buff | m_extend_data(offset, data);
      end
   endtask


   wire [3:0] hit_vec;
   assign hit_vec = cache_hit(a_tag(_addr), bram_rdata0, bram_rdata1, bram_rdata2, bram_rdata3);

   wire [3:0] _a_ofs;
   assign _a_ofs = a_ofs(_addr);

   wire [19:0] _a_tag;
   assign _a_tag = a_tag(_addr);

   wire [5:0]  _a_index;
   assign _a_index = a_index(_addr);

   wire [511:0] _hit_data;
   assign _hit_data = hit_data(_a_tag, bram_rdata0, bram_rdata1, bram_rdata2, bram_rdata3);

   wire [19:0] 	_hit_tag;
   assign _hit_tag = hit_tag(_a_tag, bram_rdata0, bram_rdata1, bram_rdata2, bram_rdata3);

   always @(posedge clk) begin
      if(rstn) begin

	 // cache hit cycle of the slave end
	 ////////////////

	 if (!cache_miss) begin
	    case(s_state)
	      INITIALIZE : begin
		 if (counter[6] == 1'b0) begin
		    bram_addr <= counter[5:0];
		    bram_wdata <= 534'b0;
		    ena <= 1;
		    wea0 <= 1;
		    wea1 <= 1;
		    wea2 <= 1;
		    wea3 <= 1;
		    lrutbl_addr <= counter[5:0];
		    lrutbl_wdata <= 8'b11100100;
		    lrutbl_ena <= 1;
		    lrutbl_wea <= 1;
		    counter <= counter + 1;
		 end else if (counter[0] == 1) begin // if (counter[6] == 1'b0)

		    // enter the slave main cycle
		    /////////////////

		    bram_init();
		    s_state <= WAITING_MASTER_REQUEST;

		 end else begin
		    counter <= counter + 1;
		 end
	      end // case: INITIALIZE
	      WAITING_MASTER_REQUEST : begin
		 if (s_axi_arvalid) begin
		    _addr <= s_axi_araddr;
		    s_axi_arready <= 1;
		    bram_read_enable(a_index(s_axi_araddr));
		    lrutbl_read_enable(a_index(s_axi_araddr));
		    s_state <= PRE_READ;
		 end else if (s_axi_awvalid || s_axi_wvalid) begin
		    if (s_axi_awvalid && s_axi_wvalid) begin
		       _addr <= s_axi_awaddr;
		       _data <= s_axi_wdata;
		       _strb <= s_axi_wstrb;
		       s_axi_awready <= 1;
		       s_axi_wready <= 1;
		       bram_read_enable(a_index(s_axi_awaddr));
		       lrutbl_read_enable(a_index(s_axi_awaddr));
		       s_state <= PRE_WRITE;
		    end else begin
		       if (s_axi_awvalid) begin
			  _addr <= s_axi_awaddr;
			  s_axi_awready <= 1;
			  s_state <= WAITING_MASTER_WVALID;
		       end
		       if (s_axi_wvalid) begin
			  _data <= s_axi_wdata;
			  _strb <= s_axi_wstrb;
			  s_axi_wready <= 1;
			  s_state <= WAITING_MASTER_AWVALID;
		       end
		    end // else: !if(s_axi_awvalid && s_axi_wvalid)
		 end // if (s_axi_awvalid || s_axi_wvalid)
	      end // case: WAITING_MASTER_REQUEST
	      PRE_READ : begin
		 s_state <= MEM_READ;
	      end
	      MEM_READ : begin
		 if (s_axi_arvalid && s_axi_arready) begin
		    s_axi_arready <= 0;
		 end
		 if (|hit_vec) begin
		    s_axi_rdata <= extract_rdata(_a_ofs, _hit_data);
		    update_lrutbl(hit_vec, lrutbl_rdata, _a_index);
		    s_state <= HOLD_READ;
		 end else begin

		    // jump to the cache miss handler
		    ////////////////

		    _fetch_addr <= { a_tag(_addr), a_index(_addr) }; // 26 bit address of the block which will be fetched from ddr4
		    cache_miss <= 1;

		 end
	      end // case: MEM_READ
	      HOLD_READ : begin
		 s_axi_rvalid <= 1;
		 s_axi_rresp <= 2'b0;
		 s_state <= WAITING_MASTER_RREADY;
	      end
	      WAITING_MASTER_RREADY : begin
		 if (s_axi_rvalid && s_axi_rready) begin

		    // return back to slave waiting state
		    ////////////////

		    s_axi_rvalid <= 0;
		    ena <= 0;
		    lrutbl_ena <= 0;
		    lrutbl_wea <= 0; // asserted in update_lrutbl
		    s_state <= WAITING_MASTER_REQUEST;

		 end
	      end // case: WAITING_MASTER_RREADY
	      WAITING_MASTER_WVALID : begin
		 if (s_axi_awvalid && s_axi_awready) begin
		    s_axi_awready <= 0;
		 end
		 if (s_axi_wvalid) begin
		    _data <= s_axi_wdata;
		    _strb <= s_axi_wstrb;
		    s_axi_wready <= 1;
		    bram_read_enable(a_index(_addr));
		    lrutbl_read_enable(a_index(_addr));
		    s_state <= PRE_WRITE;
		 end
	      end // case: WAITING_MASTER_WVALID
	      WAITING_MASTER_AWVALID : begin
		 if (s_axi_wvalid && s_axi_wready) begin
		    s_axi_wready <= 0;
		 end
		 if (s_axi_awvalid) begin
		    _addr <= s_axi_awaddr;
		    s_axi_awready <= 1;
		    bram_read_enable(a_index(s_axi_awaddr));
		    lrutbl_read_enable(a_index(s_axi_awaddr));
		    s_state <= PRE_WRITE;
		 end
	      end // case: WAITING_MASTER_AWVALID
	      PRE_WRITE: begin
		 s_state <= MEM_WRITE;
	      end
	      MEM_WRITE : begin
		 if (s_axi_awvalid && s_axi_awready) begin
		    s_axi_awready <= 0;
		 end
		 if (s_axi_wvalid && s_axi_wready) begin
		    s_axi_wready <= 0;
		 end
		 if (|hit_vec) begin
		    case (hit_vec)
		      // ena is already asserted at the end of the previous states
		      4'b0001 : begin
			 wea0 <= 1;
		      end
		      4'b0010 : begin
			 wea1 <= 1;
		      end
		      4'b0100 : begin
			 wea2 <= 1;
		      end
		      4'b1000 : begin
			 wea3 <= 1;
		      end
		    endcase // case (hit_vec)
		    bram_wdata <= { 2'b11, // valid & dirty
				    _hit_tag,
				    insert_wdata(a_ofs(_addr), _hit_data, _data, _strb) };
		    update_lrutbl(hit_vec, lrutbl_rdata, a_index(_addr));
		    s_state <= HOLD_WRITE;
		 end else begin

		    // jump to cache miss handler
		    ////////////////

		    _fetch_addr <= { a_tag(_addr), a_index(_addr) }; // 26 bit
		    cache_miss <= 1;

		 end
	      end // case: MEM_WRITE
	      HOLD_WRITE : begin
		 s_axi_bvalid <= 1;
		 s_axi_bresp <= 2'b0;
		 s_state <= WAITING_MASTER_BREADY;
	      end	      
	      WAITING_MASTER_BREADY : begin
		 if (s_axi_bvalid && s_axi_bready) begin

		    // return back to slave waiting state
		    ////////////////

		    s_axi_bvalid <= 0;
		    ena <= 0;
		    wea0 <= 0;
		    wea1 <= 0;
		    wea2 <= 0;
		    wea3 <= 0;
		    lrutbl_ena <= 0;
		    lrutbl_wea <= 0;
		    s_state <= WAITING_MASTER_REQUEST;

		 end
	      end // case: WAITING_MASTER_BREADY
	    endcase // case (s_state)

	    // cache miss handling
	    ////////////////

	 end else begin // if (!cache_miss)
	    case(handler_state)
	      HANDLER_ENTRY : begin
		 case (lrutbl_rdata[1:0]) // lookup LRU table for the oldest referenced/wrote way of the set
		   2'b00 : begin // way 0
		      if (b_valid(bram_rdata0) && b_dirty(bram_rdata0)) begin
			 // write back the block
			 handler_state <= WRITE_BACK;
			 m_validate_write ({ b_tag(bram_rdata0), a_index(_addr) }, 
			   3'b0, // initial offset (= m_counter)
			   b_data(bram_rdata0));
			 _wb_addr <= { b_tag(bram_rdata0), a_index(_addr) };
			 m_buff <= b_data(bram_rdata0);
			 m_counter <= 3'b0;
			 m_state <= WAITING_SLAVE_WREADY;
		      end else begin
			 // no need for write back
			 m_validate_read(_fetch_addr, 3'b0);
			 m_buff <= 512'b0; // clear buffer
			 m_counter <= 3'b0;
			 m_state <= WAITING_SLAVE_ARREADY;
			 handler_state <= FETCH;
		      end
		   end // case: 2'b00
		   2'b01 : begin // way 1
		      if (b_valid(bram_rdata1) && b_dirty(bram_rdata1)) begin
			 handler_state <= WRITE_BACK;
			 m_validate_write ({ b_tag(bram_rdata1), a_index(_addr) }, 
			   3'b0,
			   b_data(bram_rdata1));
			 _wb_addr <= { b_tag(bram_rdata1), a_index(_addr) };
			 m_buff <= b_data(bram_rdata1);
			 m_counter <= 3'b0;
			 m_state <= WAITING_SLAVE_WREADY;
		      end else begin
			 m_validate_read(_fetch_addr, 3'b0);
			 m_buff <= 512'b0; // clear buffer
			 m_counter <= 3'b0;
			 m_state <= WAITING_SLAVE_ARREADY;
			 handler_state <= FETCH;
		      end
		   end // case: 2'b01
		   2'b10 : begin // way 2
		      if (b_valid(bram_rdata2) && b_dirty(bram_rdata2)) begin
			 handler_state <= WRITE_BACK;
			 m_validate_write ({ b_tag(bram_rdata2), a_index(_addr) }, 
			   3'b0,
			   b_data(bram_rdata2));
			 _wb_addr <= { b_tag(bram_rdata2), a_index(_addr) };
			 m_buff <= b_data(bram_rdata2);
			 m_counter <= 3'b0;
			 m_state <= WAITING_SLAVE_WREADY;
		      end else begin
			 m_validate_read(_fetch_addr, 3'b0);
			 m_buff <= 512'b0; // clear buffer
			 m_counter <= 3'b0;
			 m_state <= WAITING_SLAVE_ARREADY;
			 handler_state <= FETCH;
		      end
		   end // case: 2'b10
		   2'b11 : begin // way 3
		      if (b_valid(bram_rdata3) && b_dirty(bram_rdata3)) begin
			 handler_state <= WRITE_BACK;
			 m_validate_write ({ b_tag(bram_rdata3), a_index(_addr) }, 
			   3'b0,
			   b_data(bram_rdata3));
			 _wb_addr <= { b_tag(bram_rdata3), a_index(_addr) };
			 m_buff <= b_data(bram_rdata3);
			 m_counter <= 3'b0;
			 m_state <= WAITING_SLAVE_WREADY;
		      end else begin
			 m_validate_read(_fetch_addr, 3'b0);
			 m_buff <= 512'b0; // clear buffer
			 m_counter <= 3'b0;
			 m_state <= WAITING_SLAVE_ARREADY;
			 handler_state <= FETCH;
		      end
		   end // case: 2'b11
		 endcase
	      end // case: HANDLER_ENTRY
	      WRITE_BACK : begin
		 case (m_state)
		   WAITING_SLAVE_WREADY : begin
		      if (m_axi_awvalid && m_axi_awready) begin
			 m_axi_awvalid <= 0;
		      end
		      if (m_axi_wvalid && m_axi_wready) begin
			 m_axi_wvalid <= 0;
		      end
		      if (!m_axi_awvalid && !m_axi_wvalid) begin
			 m_axi_bready <= 1;
			 m_state <= WAITING_SLAVE_BVALID;
		      end
		   end // case: WAITING_SLAVE_WREADY
		   WAITING_SLAVE_BVALID : begin
		      if (m_axi_bvalid && m_axi_bready) begin
			 m_axi_bready <= 0;

			 if (m_counter == 3'b111) begin

			    // move to FETCH phase
			    ////////////////

			    handler_state <= FETCH;
			    m_validate_read(_fetch_addr, 3'b0);
			    m_buff <= 512'b0; // clear buffer
			    m_counter <= 3'b0;
			    m_state <= WAITING_SLAVE_ARREADY;
			    handler_state <= FETCH;
			    
			 end else begin
			    m_validate_write(_wb_addr, m_counter + 1, m_buff);
			    m_counter <= m_counter + 1;
			    m_state <= WAITING_SLAVE_WREADY;
			 end
		      end
		   end
		 endcase // case (m_state)
	      end // case: WRITE_BACK
	      FETCH : begin
		 case (m_state)
		   WAITING_SLAVE_ARREADY : begin
		      if (m_axi_arvalid && m_axi_arready) begin
			 m_axi_arvalid <= 0;
			 m_axi_rready <= 1;
			 m_state <= WAITING_SLAVE_RVALID;
		      end
		   end
		   WAITING_SLAVE_RVALID : begin
		      if (m_axi_rvalid && m_axi_rready) begin
			 m_write_buff(m_counter, m_axi_rdata);
			 m_axi_rready <= 0;

			 if (m_counter == 3'b111) begin

			    // move to CACHE_WRITE phase
			    ////////////////

			    handler_state <= CACHE_WRITE;
			    m_counter <= 3'b0;
			    m_state <= IDLE;

			 end else begin
			    m_validate_read(_fetch_addr, m_counter + 1);
			    m_counter <= m_counter + 1;
			    m_state <= WAITING_SLAVE_ARREADY;
			 end
		      end
		   end
		 endcase // case (m_state)
	      end // case: FETCH
	      CACHE_WRITE : begin
		 case (lrutbl_rdata[1:0]) // as in the case of HANDLER_INITIAL
		   2'b00 : begin // way 0
		      bram_addr <= _fetch_addr[5:0];
		      bram_wdata <= { 2'b10, _fetch_addr[25:6], m_buff };
		      ena <= 1;
		      wea0 <= 1;
		      handler_state <= HOLD_WEA;
		   end
		   2'b01 : begin // way 1
		      bram_addr <= _fetch_addr[5:0];
		      bram_wdata <= { 2'b10, _fetch_addr[25:6], m_buff };
		      ena <= 1;
		      wea1 <= 1;
		      handler_state <= HOLD_WEA;
		   end
		   2'b10 : begin // way 2
		      bram_addr <= _fetch_addr[5:0];
		      bram_wdata <= { 2'b10, _fetch_addr[25:6], m_buff };
		      ena <= 1;
		      wea2 <= 1;
		      handler_state <= HOLD_WEA;
		   end
		   2'b11 : begin // way 3
		      bram_addr <= _fetch_addr[5:0];
		      bram_wdata <= { 2'b10, _fetch_addr[25:6], m_buff };
		      ena <= 1;
		      wea3 <= 1;
		      handler_state <= HOLD_WEA;
		   end
		 endcase // case (lrutbl_rdata[1:0])
	      end // case: CACHE_WRITE
	      HOLD_WEA: begin
		 handler_state <= DEASSERT_SIGNALS;
	      end
	      DEASSERT_SIGNALS : begin
		 // no need for deasserting ena, lrutbl_ena
		 // brams & lrutbl are referenced in the next MEM_READ/WRITE states

		 wea0 <= 0;
		 wea1 <= 0;
		 wea2 <= 0;
		 wea3 <= 0;

		 // return back to the slave cycle
		 ////////////////

		 cache_miss <= 0;
		 handler_state <= HANDLER_ENTRY;

	      end // case: DEASSERT_SIGNALS
	    endcase // case (handler_state)
	 end // else: !if(!cache_miss)
      end else begin // if (rstn)

	 s_init();
	 bram_init();
	 handler_init();
	 m_init();

      end // else: !if(b_valid(bram_rdata0) & b_dirty(bram_rdata0))
   end // always @ (posedge clk)
endmodule // cache_controller

`default_nettype wire
