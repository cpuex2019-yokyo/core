`default_nettype none

module div_stage #(
                   parameter STAGE = 1
                   ) (
                      input wire [63:0]  s_prev,
                      input wire [63:0]  t_prev,
                      input wire [31:0]  q_prev,
                      input wire         ssign_prev,
                      input wire         tsign_prev,
                      output wire [63:0] s_next,
                      output wire [63:0] t_next,
                      output wire [31:0] q_next,
                      output wire        ssign_next,
                      output wire tsign_next
                      );

   wire [63:0]                           s_array [4:0];
   wire [63:0]                           t_array [4:0];
   assign s_array[0] = s_prev;
   assign t_array[0] = t_prev;

   assign q_next[31:4] = q_prev[27:0];

   genvar                                i;
   generate
      for (i=0;i<4;i=i+1) begin: for_q
         assign q_next[3-i] = (s_array[i] >= t_array[i]) ? 1'b1 : 1'b0;
      end
      for (i=0;i<4;i=i+1) begin: for_s_array
         assign s_array[i+1] = (s_array[i] >= t_array[i]) ? s_array[i] - t_array[i] : s_array[i];
      end
      for (i=0;i<4;i=i+1) begin: for_t_array
         assign t_array[i+1] = t_array[i] >> 1;
      end
   endgenerate
   assign s_next = s_array[4];
   assign t_next = t_array[4];
   assign ssign_next = ssign_prev;
   assign tsign_next = tsign_prev;

endmodule

module div(
           input wire         clk,
           input wire         enable,
           output wire        completed,
           input wire         is_signed,
           input wire [31:0]  s,
           input wire [31:0]  t,
           output wire [31:0] q,
           output wire [31:0] r
           );

   wire [63:0]                s1_prev, s2_prev, s3_prev, s4_prev, s5_prev, s6_prev, s7_prev, s8_prev;
   wire [63:0]                s1_next, s2_next, s3_next, s4_next, s5_next, s6_next, s7_next, s8_next;
   wire [63:0]                t1_prev, t2_prev, t3_prev, t4_prev, t5_prev, t6_prev, t7_prev, t8_prev;
   wire [63:0]                t1_next, t2_next, t3_next, t4_next, t5_next, t6_next, t7_next, t8_next;
   wire [31:0]                q1_prev, q2_prev, q3_prev, q4_prev, q5_prev, q6_prev, q7_prev, q8_prev;
   wire [31:0]                q1_next, q2_next, q3_next, q4_next, q5_next, q6_next, q7_next, q8_next;
   wire                       ssign1_prev, ssign2_prev, ssign3_prev, ssign4_prev, ssign5_prev, ssign6_prev, ssign7_prev, ssign8_prev, ssign1_next, ssign2_next, ssign3_next, ssign4_next, ssign5_next, ssign6_next, ssign7_next, ssign8_next;
   wire                       tsign1_prev, tsign2_prev, tsign3_prev, tsign4_prev, tsign5_prev, tsign6_prev, tsign7_prev, tsign8_prev, tsign1_next, tsign2_next, tsign3_next, tsign4_next, tsign5_next, tsign6_next, tsign7_next, tsign8_next;
   reg                        ssign1_reg, ssign2_reg, ssign3_reg, ssign4_reg, ssign5_reg, ssign6_reg, ssign7_reg, ssign8_reg;
   reg                        tsign1_reg, tsign2_reg, tsign3_reg, tsign4_reg, tsign5_reg, tsign6_reg, tsign7_reg, tsign8_reg;

   wire [31:0]                s_in, t_in;

   reg [6:0]                  done;

   assign completed = done[0];

   assign s1_prev = {32'b0, s_in};
   assign t1_prev = {1'b0, t_in, 31'b0};
   assign q1_prev = 32'b0;
   assign ssign1_prev = is_signed && s[31];
   assign tsign1_prev = is_signed && t[31];
   assign s_in = ssign1_prev ? ~s + 32'b1 : s;
   assign t_in = tsign1_prev ? ~t + 32'b1 : t;

   // NOTE: div
   // assign q = 
   //   (ssign8_next==1'b0 && tsign8_next == 1'b0) ? q8_next :
   //   (ssign8_next==1'b1 && tsign8_next == 1'b0) ? ~q8_next + 32'b1 :
   //   (ssign8_next==1'b0 && tsign8_next == 1'b1) ? ~q8_next :
   //   q8_next + 32'b1;
   // assign r = 
   //   (ssign8_next==1'b0 && tsign8_next == 1'b0) ? s8_next :
   //   (ssign8_next==1'b1 && tsign8_next == 1'b0) ? ~s8_next + 32'b1 :
   //   (ssign8_next==1'b0 && tsign8_next == 1'b1) ? s8_next + 32'b1 :
   //   ~s8_next;

   // NOTE: div on verilog
   assign q = 
              (ssign8_next==1'b0 && tsign8_next == 1'b0) ? q8_next :
              (ssign8_next==1'b1 && tsign8_next == 1'b0) ? ~q8_next + 32'b1 :
              (ssign8_next==1'b0 && tsign8_next == 1'b1) ? ~q8_next + 32'b1 :
              q8_next;
   assign r = 
              (ssign8_next==1'b0 && tsign8_next == 1'b0) ? s8_next :
              (ssign8_next==1'b1 && tsign8_next == 1'b0) ? ~s8_next + 32'b1 :
              (ssign8_next==1'b0 && tsign8_next == 1'b1) ? s8_next :
              ~s8_next + 1;

   div_stage #(.STAGE(1)) u1(s1_prev,t1_prev,q1_prev,ssign1_prev, tsign1_prev,s1_next,t1_next,q1_next,ssign1_next, tsign1_next);
   div_stage #(.STAGE(2)) u2(s2_prev,t2_prev,q2_prev,ssign2_prev, tsign2_prev,s2_next,t2_next,q2_next,ssign2_next, tsign2_next);
   div_stage #(.STAGE(3)) u3(s3_prev,t3_prev,q3_prev,ssign3_prev, tsign3_prev,s3_next,t3_next,q3_next,ssign3_next, tsign3_next);
   div_stage #(.STAGE(4)) u4(s4_prev,t4_prev,q4_prev,ssign4_prev, tsign4_prev,s4_next,t4_next,q4_next,ssign4_next, tsign4_next);
   div_stage #(.STAGE(5)) u5(s5_prev,t5_prev,q5_prev,ssign5_prev, tsign5_prev,s5_next,t5_next,q5_next,ssign5_next, tsign5_next);
   div_stage #(.STAGE(6)) u6(s6_prev,t6_prev,q6_prev,ssign6_prev, tsign6_prev,s6_next,t6_next,q6_next,ssign6_next, tsign6_next);
   div_stage #(.STAGE(7)) u7(s7_prev,t7_prev,q7_prev,ssign7_prev, tsign7_prev,s7_next,t7_next,q7_next,ssign7_next, tsign7_next);
   div_stage #(.STAGE(8)) u8(s8_prev,t8_prev,q8_prev,ssign8_prev, tsign8_prev,s8_next,t8_next,q8_next,ssign8_next, tsign8_next);

   reg [63:0]                 s12, s23, s34, s45, s56, s67, s78;
   reg [63:0]                 t12, t23, t34, t45, t56, t67, t78;
   reg [31:0]                 q12, q23, q34, q45, q56, q67, q78;
   reg                        ssign12, ssign23, ssign34, ssign45, ssign56, ssign67, ssign78;
   reg                        tsign12, tsign23, tsign34, tsign45, tsign56, tsign67, tsign78;

   assign s2_prev = s12;
   assign s3_prev = s23;
   assign s4_prev = s34;
   assign s5_prev = s45;
   assign s6_prev = s56;
   assign s7_prev = s67;
   assign s8_prev = s78;
   assign t2_prev = t12;
   assign t3_prev = t23;
   assign t4_prev = t34;
   assign t5_prev = t45;
   assign t6_prev = t56;
   assign t7_prev = t67;
   assign t8_prev = t78;
   assign q2_prev = q12;
   assign q3_prev = q23;
   assign q4_prev = q34;
   assign q5_prev = q45;
   assign q6_prev = q56;
   assign q7_prev = q67;
   assign q8_prev = q78;
   assign ssign2_prev = ssign12;
   assign ssign3_prev = ssign23;
   assign ssign4_prev = ssign34;
   assign ssign5_prev = ssign45;
   assign ssign6_prev = ssign56;
   assign ssign7_prev = ssign67;
   assign ssign8_prev = ssign78;
   assign tsign2_prev = tsign12;
   assign tsign3_prev = tsign23;
   assign tsign4_prev = tsign34;
   assign tsign5_prev = tsign45;
   assign tsign6_prev = tsign56;
   assign tsign7_prev = tsign67;
   assign tsign8_prev = tsign78;

   always @(posedge clk) begin
      done <= {enable, done[6:1]};
      s12 <= s1_next;
      s23 <= s2_next;
      s34 <= s3_next;
      s45 <= s4_next;
      s56 <= s5_next;
      s67 <= s6_next;
      s78 <= s7_next;
      t12 <= t1_next;
      t23 <= t2_next;
      t34 <= t3_next;
      t45 <= t4_next;
      t56 <= t5_next;
      t67 <= t6_next;
      t78 <= t7_next;
      q12 <= q1_next;
      q23 <= q2_next;
      q34 <= q3_next;
      q45 <= q4_next;
      q56 <= q5_next;
      q67 <= q6_next;
      q78 <= q7_next;
      ssign12 <= ssign1_next;
      ssign23 <= ssign2_next;
      ssign34 <= ssign3_next;
      ssign45 <= ssign4_next;
      ssign56 <= ssign5_next;
      ssign67 <= ssign6_next;
      ssign78 <= ssign7_next;
      tsign12 <= tsign1_next;
      tsign23 <= tsign2_next;
      tsign34 <= tsign3_next;
      tsign45 <= tsign4_next;
      tsign56 <= tsign5_next;
      tsign67 <= tsign6_next;
      tsign78 <= tsign7_next;
   end

endmodule
`default_nettype wire
