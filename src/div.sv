module div_stage #(
  parameter STAGE = 1
) (
  input wire [63:0] s_prev,
  input wire [63:0] t_prev,
  input wire [31:0] q_prev,
  input wire ssign_prev,
  input wire tsign_prev,
  output wire [63:0] s_next,
  output wire [63:0] t_next,
  output wire [31:0] q_next,
  output wire ssign_next,
  output wire tsign_next
);

assign q_next[31:1] = q_prev[30:0];
assign q_next[0:0] = (s_prev >= t_prev) ? 1'b1 : 1'b0;
assign s_next = (s_prev >= t_prev) ? s_prev - t_prev : s_prev;
assign t_next = t_prev >> 1;
assign ssign_next = ssign_prev;
assign tsign_next = tsign_prev;

endmodule


module div(
  input wire clk,
  input wire enable,
  output wire completed,
  input wire is_signed,
  input wire [31:0] s,
  input wire [31:0] t,
  output wire [31:0] q,
  output wire [31:0] r
);

wire [63:0] s1_prev, s2_prev, s3_prev, s4_prev, s5_prev, s6_prev, s7_prev, s8_prev, s9_prev, s10_prev, s11_prev, s12_prev, s13_prev, s14_prev, s15_prev, s16_prev, s17_prev, s18_prev, s19_prev, s20_prev, s21_prev, s22_prev, s23_prev, s24_prev, s25_prev, s26_prev, s27_prev, s28_prev, s29_prev, s30_prev, s31_prev, s32_prev;
wire [63:0] s1_next, s2_next, s3_next, s4_next, s5_next, s6_next, s7_next, s8_next, s9_next, s10_next, s11_next, s12_next, s13_next, s14_next, s15_next, s16_next, s17_next, s18_next, s19_next, s20_next, s21_next, s22_next, s23_next, s24_next, s25_next, s26_next, s27_next, s28_next, s29_next, s30_next, s31_next, s32_next;
wire [63:0] t1_prev, t2_prev, t3_prev, t4_prev, t5_prev, t6_prev, t7_prev, t8_prev, t9_prev, t10_prev, t11_prev, t12_prev, t13_prev, t14_prev, t15_prev, t16_prev, t17_prev, t18_prev, t19_prev, t20_prev, t21_prev, t22_prev, t23_prev, t24_prev, t25_prev, t26_prev, t27_prev, t28_prev, t29_prev, t30_prev, t31_prev, t32_prev;
wire [63:0] t1_next, t2_next, t3_next, t4_next, t5_next, t6_next, t7_next, t8_next, t9_next, t10_next, t11_next, t12_next, t13_next, t14_next, t15_next, t16_next, t17_next, t18_next, t19_next, t20_next, t21_next, t22_next, t23_next, t24_next, t25_next, t26_next, t27_next, t28_next, t29_next, t30_next, t31_next, t32_next;
wire [31:0] q1_prev, q2_prev, q3_prev, q4_prev, q5_prev, q6_prev, q7_prev, q8_prev, q9_prev, q10_prev, q11_prev, q12_prev, q13_prev, q14_prev, q15_prev, q16_prev, q17_prev, q18_prev, q19_prev, q20_prev, q21_prev, q22_prev, q23_prev, q24_prev, q25_prev, q26_prev, q27_prev, q28_prev, q29_prev, q30_prev, q31_prev, q32_prev;
wire [31:0] q1_next, q2_next, q3_next, q4_next, q5_next, q6_next, q7_next, q8_next, q9_next, q10_next, q11_next, q12_next, q13_next, q14_next, q15_next, q16_next, q17_next, q18_next, q19_next, q20_next, q21_next, q22_next, q23_next, q24_next, q25_next, q26_next, q27_next, q28_next, q29_next, q30_next, q31_next, q32_next;
wire ssign1_prev, ssign2_prev, ssign3_prev, ssign4_prev, ssign5_prev, ssign6_prev, ssign7_prev, ssign8_prev, ssign9_prev, ssign10_prev, ssign11_prev, ssign12_prev, ssign13_prev, ssign14_prev, ssign15_prev, ssign16_prev, ssign17_prev, ssign18_prev, ssign19_prev, ssign20_prev, ssign21_prev, ssign22_prev, ssign23_prev, ssign24_prev, ssign25_prev, ssign26_prev, ssign27_prev, ssign28_prev, ssign29_prev, ssign30_prev, ssign31_prev, ssign32_prev;
wire ssign1_next, ssign2_next, ssign3_next, ssign4_next, ssign5_next, ssign6_next, ssign7_next, ssign8_next, ssign9_next, ssign10_next, ssign11_next, ssign12_next, ssign13_next, ssign14_next, ssign15_next, ssign16_next, ssign17_next, ssign18_next, ssign19_next, ssign20_next, ssign21_next, ssign22_next, ssign23_next, ssign24_next, ssign25_next, ssign26_next, ssign27_next, ssign28_next, ssign29_next, ssign30_next, ssign31_next, ssign32_next;
wire tsign1_prev, tsign2_prev, tsign3_prev, tsign4_prev, tsign5_prev, tsign6_prev, tsign7_prev, tsign8_prev, tsign9_prev, tsign10_prev, tsign11_prev, tsign12_prev, tsign13_prev, tsign14_prev, tsign15_prev, tsign16_prev, tsign17_prev, tsign18_prev, tsign19_prev, tsign20_prev, tsign21_prev, tsign22_prev, tsign23_prev, tsign24_prev, tsign25_prev, tsign26_prev, tsign27_prev, tsign28_prev, tsign29_prev, tsign30_prev, tsign31_prev, tsign32_prev;
wire tsign1_next, tsign2_next, tsign3_next, tsign4_next, tsign5_next, tsign6_next, tsign7_next, tsign8_next, tsign9_next, tsign10_next, tsign11_next, tsign12_next, tsign13_next, tsign14_next, tsign15_next, tsign16_next, tsign17_next, tsign18_next, tsign19_next, tsign20_next, tsign21_next, tsign22_next, tsign23_next, tsign24_next, tsign25_next, tsign26_next, tsign27_next, tsign28_next, tsign29_next, tsign30_next, tsign31_next, tsign32_next;

wire [31:0] s_in, t_in;

assign s1_prev = {32'b0, s_in};
assign t1_prev = {1'b0, t_in, 31'b0};
assign q1_prev = 32'b0;
assign ssign1_prev = is_signed && s[31:31];
assign tsign1_prev = is_signed && t[31:31];
assign s_in = ssign1_prev ? ~s + 32'b1 : s;
assign t_in = tsign1_prev ? ~t + 32'b1 : t;

// NOTE: div on verilog
assign q = 
  (ssign32_next==1'b0 && tsign32_next == 1'b0) ? q32_next :
  (ssign32_next==1'b1 && tsign32_next == 1'b0) ? ~q32_next + 32'b1 :
  (ssign32_next==1'b0 && tsign32_next == 1'b1) ? ~q32_next + 32'b1 :
  q32_next;
assign r = 
  (ssign32_next==1'b1 && tsign32_next == 1'b0) ? ~s32_next + 32'b1 :
  (ssign32_next==1'b0 && tsign32_next == 1'b1) ? s32_next :
  (ssign32_next==1'b0 && tsign32_next == 1'b0) ? s32_next :
  ~s32_next + 1;

div_stage #(.STAGE(1)) u1(s1_prev,t1_prev,q1_prev,ssign1_prev, tsign1_prev,s1_next,t1_next,q1_next,ssign1_next, tsign1_next);
div_stage #(.STAGE(2)) u2(s2_prev,t2_prev,q2_prev,ssign2_prev, tsign2_prev,s2_next,t2_next,q2_next,ssign2_next, tsign2_next);
div_stage #(.STAGE(3)) u3(s3_prev,t3_prev,q3_prev,ssign3_prev, tsign3_prev,s3_next,t3_next,q3_next,ssign3_next, tsign3_next);
div_stage #(.STAGE(4)) u4(s4_prev,t4_prev,q4_prev,ssign4_prev, tsign4_prev,s4_next,t4_next,q4_next,ssign4_next, tsign4_next);
div_stage #(.STAGE(5)) u5(s5_prev,t5_prev,q5_prev,ssign5_prev, tsign5_prev,s5_next,t5_next,q5_next,ssign5_next, tsign5_next);
div_stage #(.STAGE(6)) u6(s6_prev,t6_prev,q6_prev,ssign6_prev, tsign6_prev,s6_next,t6_next,q6_next,ssign6_next, tsign6_next);
div_stage #(.STAGE(7)) u7(s7_prev,t7_prev,q7_prev,ssign7_prev, tsign7_prev,s7_next,t7_next,q7_next,ssign7_next, tsign7_next);
div_stage #(.STAGE(8)) u8(s8_prev,t8_prev,q8_prev,ssign8_prev, tsign8_prev,s8_next,t8_next,q8_next,ssign8_next, tsign8_next);
div_stage #(.STAGE(9)) u9(s9_prev,t9_prev,q9_prev,ssign9_prev, tsign9_prev,s9_next,t9_next,q9_next,ssign9_next, tsign9_next);
div_stage #(.STAGE(10)) u10(s10_prev,t10_prev,q10_prev,ssign10_prev, tsign10_prev,s10_next,t10_next,q10_next,ssign10_next, tsign10_next);
div_stage #(.STAGE(11)) u11(s11_prev,t11_prev,q11_prev,ssign11_prev, tsign11_prev,s11_next,t11_next,q11_next,ssign11_next, tsign11_next);
div_stage #(.STAGE(12)) u12(s12_prev,t12_prev,q12_prev,ssign12_prev, tsign12_prev,s12_next,t12_next,q12_next,ssign12_next, tsign12_next);
div_stage #(.STAGE(13)) u13(s13_prev,t13_prev,q13_prev,ssign13_prev, tsign13_prev,s13_next,t13_next,q13_next,ssign13_next, tsign13_next);
div_stage #(.STAGE(14)) u14(s14_prev,t14_prev,q14_prev,ssign14_prev, tsign14_prev,s14_next,t14_next,q14_next,ssign14_next, tsign14_next);
div_stage #(.STAGE(15)) u15(s15_prev,t15_prev,q15_prev,ssign15_prev, tsign15_prev,s15_next,t15_next,q15_next,ssign15_next, tsign15_next);
div_stage #(.STAGE(16)) u16(s16_prev,t16_prev,q16_prev,ssign16_prev, tsign16_prev,s16_next,t16_next,q16_next,ssign16_next, tsign16_next);
div_stage #(.STAGE(17)) u17(s17_prev,t17_prev,q17_prev,ssign17_prev, tsign17_prev,s17_next,t17_next,q17_next,ssign17_next, tsign17_next);
div_stage #(.STAGE(18)) u18(s18_prev,t18_prev,q18_prev,ssign18_prev, tsign18_prev,s18_next,t18_next,q18_next,ssign18_next, tsign18_next);
div_stage #(.STAGE(19)) u19(s19_prev,t19_prev,q19_prev,ssign19_prev, tsign19_prev,s19_next,t19_next,q19_next,ssign19_next, tsign19_next);
div_stage #(.STAGE(20)) u20(s20_prev,t20_prev,q20_prev,ssign20_prev, tsign20_prev,s20_next,t20_next,q20_next,ssign20_next, tsign20_next);
div_stage #(.STAGE(21)) u21(s21_prev,t21_prev,q21_prev,ssign21_prev, tsign21_prev,s21_next,t21_next,q21_next,ssign21_next, tsign21_next);
div_stage #(.STAGE(22)) u22(s22_prev,t22_prev,q22_prev,ssign22_prev, tsign22_prev,s22_next,t22_next,q22_next,ssign22_next, tsign22_next);
div_stage #(.STAGE(23)) u23(s23_prev,t23_prev,q23_prev,ssign23_prev, tsign23_prev,s23_next,t23_next,q23_next,ssign23_next, tsign23_next);
div_stage #(.STAGE(24)) u24(s24_prev,t24_prev,q24_prev,ssign24_prev, tsign24_prev,s24_next,t24_next,q24_next,ssign24_next, tsign24_next);
div_stage #(.STAGE(25)) u25(s25_prev,t25_prev,q25_prev,ssign25_prev, tsign25_prev,s25_next,t25_next,q25_next,ssign25_next, tsign25_next);
div_stage #(.STAGE(26)) u26(s26_prev,t26_prev,q26_prev,ssign26_prev, tsign26_prev,s26_next,t26_next,q26_next,ssign26_next, tsign26_next);
div_stage #(.STAGE(27)) u27(s27_prev,t27_prev,q27_prev,ssign27_prev, tsign27_prev,s27_next,t27_next,q27_next,ssign27_next, tsign27_next);
div_stage #(.STAGE(28)) u28(s28_prev,t28_prev,q28_prev,ssign28_prev, tsign28_prev,s28_next,t28_next,q28_next,ssign28_next, tsign28_next);
div_stage #(.STAGE(29)) u29(s29_prev,t29_prev,q29_prev,ssign29_prev, tsign29_prev,s29_next,t29_next,q29_next,ssign29_next, tsign29_next);
div_stage #(.STAGE(30)) u30(s30_prev,t30_prev,q30_prev,ssign30_prev, tsign30_prev,s30_next,t30_next,q30_next,ssign30_next, tsign30_next);
div_stage #(.STAGE(31)) u31(s31_prev,t31_prev,q31_prev,ssign31_prev, tsign31_prev,s31_next,t31_next,q31_next,ssign31_next, tsign31_next);
div_stage #(.STAGE(32)) u32(s32_prev,t32_prev,q32_prev,ssign32_prev, tsign32_prev,s32_next,t32_next,q32_next,ssign32_next, tsign32_next);


reg [63:0] s12, s23, s34, s45, s56, s67, s78, s89, s910, s1011, s1112, s1213, s1314, s1415, s1516, s1617, s1718, s1819, s1920, s2021, s2122, s2223, s2324, s2425, s2526, s2627, s2728, s2829, s2930, s3031, s3132;
reg [63:0] t12, t23, t34, t45, t56, t67, t78, t89, t910, t1011, t1112, t1213, t1314, t1415, t1516, t1617, t1718, t1819, t1920, t2021, t2122, t2223, t2324, t2425, t2526, t2627, t2728, t2829, t2930, t3031, t3132;
reg [31:0] q12, q23, q34, q45, q56, q67, q78, q89, q910, q1011, q1112, q1213, q1314, q1415, q1516, q1617, q1718, q1819, q1920, q2021, q2122, q2223, q2324, q2425, q2526, q2627, q2728, q2829, q2930, q3031, q3132;
reg ssign12, ssign23, ssign34, ssign45, ssign56, ssign67, ssign78, ssign89, ssign910, ssign1011, ssign1112, ssign1213, ssign1314, ssign1415, ssign1516, ssign1617, ssign1718, ssign1819, ssign1920, ssign2021, ssign2122, ssign2223, ssign2324, ssign2425, ssign2526, ssign2627, ssign2728, ssign2829, ssign2930, ssign3031, ssign3132;
reg tsign12, tsign23, tsign34, tsign45, tsign56, tsign67, tsign78, tsign89, tsign910, tsign1011, tsign1112, tsign1213, tsign1314, tsign1415, tsign1516, tsign1617, tsign1718, tsign1819, tsign1920, tsign2021, tsign2122, tsign2223, tsign2324, tsign2425, tsign2526, tsign2627, tsign2728, tsign2829, tsign2930, tsign3031, tsign3132;


assign s2_prev = s12;
assign s3_prev = s23;
assign s4_prev = s34;
assign s5_prev = s45;
assign s6_prev = s56;
assign s7_prev = s67;
assign s8_prev = s78;
assign s9_prev = s89;
assign s10_prev = s910;
assign s11_prev = s1011;
assign s12_prev = s1112;
assign s13_prev = s1213;
assign s14_prev = s1314;
assign s15_prev = s1415;
assign s16_prev = s1516;
assign s17_prev = s1617;
assign s18_prev = s1718;
assign s19_prev = s1819;
assign s20_prev = s1920;
assign s21_prev = s2021;
assign s22_prev = s2122;
assign s23_prev = s2223;
assign s24_prev = s2324;
assign s25_prev = s2425;
assign s26_prev = s2526;
assign s27_prev = s2627;
assign s28_prev = s2728;
assign s29_prev = s2829;
assign s30_prev = s2930;
assign s31_prev = s3031;
assign s32_prev = s3132;
assign t2_prev = t12;
assign t3_prev = t23;
assign t4_prev = t34;
assign t5_prev = t45;
assign t6_prev = t56;
assign t7_prev = t67;
assign t8_prev = t78;
assign t9_prev = t89;
assign t10_prev = t910;
assign t11_prev = t1011;
assign t12_prev = t1112;
assign t13_prev = t1213;
assign t14_prev = t1314;
assign t15_prev = t1415;
assign t16_prev = t1516;
assign t17_prev = t1617;
assign t18_prev = t1718;
assign t19_prev = t1819;
assign t20_prev = t1920;
assign t21_prev = t2021;
assign t22_prev = t2122;
assign t23_prev = t2223;
assign t24_prev = t2324;
assign t25_prev = t2425;
assign t26_prev = t2526;
assign t27_prev = t2627;
assign t28_prev = t2728;
assign t29_prev = t2829;
assign t30_prev = t2930;
assign t31_prev = t3031;
assign t32_prev = t3132;
assign q2_prev = q12;
assign q3_prev = q23;
assign q4_prev = q34;
assign q5_prev = q45;
assign q6_prev = q56;
assign q7_prev = q67;
assign q8_prev = q78;
assign q9_prev = q89;
assign q10_prev = q910;
assign q11_prev = q1011;
assign q12_prev = q1112;
assign q13_prev = q1213;
assign q14_prev = q1314;
assign q15_prev = q1415;
assign q16_prev = q1516;
assign q17_prev = q1617;
assign q18_prev = q1718;
assign q19_prev = q1819;
assign q20_prev = q1920;
assign q21_prev = q2021;
assign q22_prev = q2122;
assign q23_prev = q2223;
assign q24_prev = q2324;
assign q25_prev = q2425;
assign q26_prev = q2526;
assign q27_prev = q2627;
assign q28_prev = q2728;
assign q29_prev = q2829;
assign q30_prev = q2930;
assign q31_prev = q3031;
assign q32_prev = q3132;
assign ssign2_prev = ssign12;
assign ssign3_prev = ssign23;
assign ssign4_prev = ssign34;
assign ssign5_prev = ssign45;
assign ssign6_prev = ssign56;
assign ssign7_prev = ssign67;
assign ssign8_prev = ssign78;
assign ssign9_prev = ssign89;
assign ssign10_prev = ssign910;
assign ssign11_prev = ssign1011;
assign ssign12_prev = ssign1112;
assign ssign13_prev = ssign1213;
assign ssign14_prev = ssign1314;
assign ssign15_prev = ssign1415;
assign ssign16_prev = ssign1516;
assign ssign17_prev = ssign1617;
assign ssign18_prev = ssign1718;
assign ssign19_prev = ssign1819;
assign ssign20_prev = ssign1920;
assign ssign21_prev = ssign2021;
assign ssign22_prev = ssign2122;
assign ssign23_prev = ssign2223;
assign ssign24_prev = ssign2324;
assign ssign25_prev = ssign2425;
assign ssign26_prev = ssign2526;
assign ssign27_prev = ssign2627;
assign ssign28_prev = ssign2728;
assign ssign29_prev = ssign2829;
assign ssign30_prev = ssign2930;
assign ssign31_prev = ssign3031;
assign ssign32_prev = ssign3132;
assign tsign2_prev = tsign12;
assign tsign3_prev = tsign23;
assign tsign4_prev = tsign34;
assign tsign5_prev = tsign45;
assign tsign6_prev = tsign56;
assign tsign7_prev = tsign67;
assign tsign8_prev = tsign78;
assign tsign9_prev = tsign89;
assign tsign10_prev = tsign910;
assign tsign11_prev = tsign1011;
assign tsign12_prev = tsign1112;
assign tsign13_prev = tsign1213;
assign tsign14_prev = tsign1314;
assign tsign15_prev = tsign1415;
assign tsign16_prev = tsign1516;
assign tsign17_prev = tsign1617;
assign tsign18_prev = tsign1718;
assign tsign19_prev = tsign1819;
assign tsign20_prev = tsign1920;
assign tsign21_prev = tsign2021;
assign tsign22_prev = tsign2122;
assign tsign23_prev = tsign2223;
assign tsign24_prev = tsign2324;
assign tsign25_prev = tsign2425;
assign tsign26_prev = tsign2526;
assign tsign27_prev = tsign2627;
assign tsign28_prev = tsign2728;
assign tsign29_prev = tsign2829;
assign tsign30_prev = tsign2930;
assign tsign31_prev = tsign3031;
assign tsign32_prev = tsign3132;

reg [30:0] done;
assign completed = done[0:0];

always @(posedge clk) begin
  done <= {enable, done[30:1]};
  s12 <= s1_next;
  s23 <= s2_next;
  s34 <= s3_next;
  s45 <= s4_next;
  s56 <= s5_next;
  s67 <= s6_next;
  s78 <= s7_next;
  s89 <= s8_next;
  s910 <= s9_next;
  s1011 <= s10_next;
  s1112 <= s11_next;
  s1213 <= s12_next;
  s1314 <= s13_next;
  s1415 <= s14_next;
  s1516 <= s15_next;
  s1617 <= s16_next;
  s1718 <= s17_next;
  s1819 <= s18_next;
  s1920 <= s19_next;
  s2021 <= s20_next;
  s2122 <= s21_next;
  s2223 <= s22_next;
  s2324 <= s23_next;
  s2425 <= s24_next;
  s2526 <= s25_next;
  s2627 <= s26_next;
  s2728 <= s27_next;
  s2829 <= s28_next;
  s2930 <= s29_next;
  s3031 <= s30_next;
  s3132 <= s31_next;
  t12 <= t1_next;
  t23 <= t2_next;
  t34 <= t3_next;
  t45 <= t4_next;
  t56 <= t5_next;
  t67 <= t6_next;
  t78 <= t7_next;
  t89 <= t8_next;
  t910 <= t9_next;
  t1011 <= t10_next;
  t1112 <= t11_next;
  t1213 <= t12_next;
  t1314 <= t13_next;
  t1415 <= t14_next;
  t1516 <= t15_next;
  t1617 <= t16_next;
  t1718 <= t17_next;
  t1819 <= t18_next;
  t1920 <= t19_next;
  t2021 <= t20_next;
  t2122 <= t21_next;
  t2223 <= t22_next;
  t2324 <= t23_next;
  t2425 <= t24_next;
  t2526 <= t25_next;
  t2627 <= t26_next;
  t2728 <= t27_next;
  t2829 <= t28_next;
  t2930 <= t29_next;
  t3031 <= t30_next;
  t3132 <= t31_next;
  q12 <= q1_next;
  q23 <= q2_next;
  q34 <= q3_next;
  q45 <= q4_next;
  q56 <= q5_next;
  q67 <= q6_next;
  q78 <= q7_next;
  q89 <= q8_next;
  q910 <= q9_next;
  q1011 <= q10_next;
  q1112 <= q11_next;
  q1213 <= q12_next;
  q1314 <= q13_next;
  q1415 <= q14_next;
  q1516 <= q15_next;
  q1617 <= q16_next;
  q1718 <= q17_next;
  q1819 <= q18_next;
  q1920 <= q19_next;
  q2021 <= q20_next;
  q2122 <= q21_next;
  q2223 <= q22_next;
  q2324 <= q23_next;
  q2425 <= q24_next;
  q2526 <= q25_next;
  q2627 <= q26_next;
  q2728 <= q27_next;
  q2829 <= q28_next;
  q2930 <= q29_next;
  q3031 <= q30_next;
  q3132 <= q31_next;
  ssign12 <= ssign1_next;
  ssign23 <= ssign2_next;
  ssign34 <= ssign3_next;
  ssign45 <= ssign4_next;
  ssign56 <= ssign5_next;
  ssign67 <= ssign6_next;
  ssign78 <= ssign7_next;
  ssign89 <= ssign8_next;
  ssign910 <= ssign9_next;
  ssign1011 <= ssign10_next;
  ssign1112 <= ssign11_next;
  ssign1213 <= ssign12_next;
  ssign1314 <= ssign13_next;
  ssign1415 <= ssign14_next;
  ssign1516 <= ssign15_next;
  ssign1617 <= ssign16_next;
  ssign1718 <= ssign17_next;
  ssign1819 <= ssign18_next;
  ssign1920 <= ssign19_next;
  ssign2021 <= ssign20_next;
  ssign2122 <= ssign21_next;
  ssign2223 <= ssign22_next;
  ssign2324 <= ssign23_next;
  ssign2425 <= ssign24_next;
  ssign2526 <= ssign25_next;
  ssign2627 <= ssign26_next;
  ssign2728 <= ssign27_next;
  ssign2829 <= ssign28_next;
  ssign2930 <= ssign29_next;
  ssign3031 <= ssign30_next;
  ssign3132 <= ssign31_next;
  tsign12 <= tsign1_next;
  tsign23 <= tsign2_next;
  tsign34 <= tsign3_next;
  tsign45 <= tsign4_next;
  tsign56 <= tsign5_next;
  tsign67 <= tsign6_next;
  tsign78 <= tsign7_next;
  tsign89 <= tsign8_next;
  tsign910 <= tsign9_next;
  tsign1011 <= tsign10_next;
  tsign1112 <= tsign11_next;
  tsign1213 <= tsign12_next;
  tsign1314 <= tsign13_next;
  tsign1415 <= tsign14_next;
  tsign1516 <= tsign15_next;
  tsign1617 <= tsign16_next;
  tsign1718 <= tsign17_next;
  tsign1819 <= tsign18_next;
  tsign1920 <= tsign19_next;
  tsign2021 <= tsign20_next;
  tsign2122 <= tsign21_next;
  tsign2223 <= tsign22_next;
  tsign2324 <= tsign23_next;
  tsign2425 <= tsign24_next;
  tsign2526 <= tsign25_next;
  tsign2627 <= tsign26_next;
  tsign2728 <= tsign27_next;
  tsign2829 <= tsign28_next;
  tsign2930 <= tsign29_next;
  tsign3031 <= tsign30_next;
  tsign3132 <= tsign31_next;
end

endmodule