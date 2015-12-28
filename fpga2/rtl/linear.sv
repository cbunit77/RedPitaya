////////////////////////////////////////////////////////////////////////////////
// Module: Linear transformation (gain, offset and saturation)
// Author: Matej Oblak, Iztok Jeras
// (c) Red Pitaya  http://www.redpitaya.com
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
//
// GENERAL DESCRIPTION:
//
// A linear transformation is applied to the signal. Multiplication by gain and
// offset addition. At the end there is a saturation module to meet the output
// data width.
//
// sto = floor (((x * mul) >>> (DWM-1)) + sum)
//
// BLOCK DIAGRAM:
//
//         -----     -------     -----     ------------ 
// sti -->| mul |-->| shift |-->| sum |-->| saturation |--> sto
//         -----     -------     -----     ------------
//           ^                     ^
//           |                     |
//          mul                   sum
//
////////////////////////////////////////////////////////////////////////////////

module linear #(
  int unsigned DWI = 14,   // data width for input
  int unsigned DWO = 14,   // data width for output
  int unsigned DWM = 16,   // data width for multiplier (gain)
  int unsigned DWS = DWO   // data width for summation (offset)
)(
  // system signals
  input  logic                  clk ,  // clock
  input  logic                  rstn,  // reset - active low
  // input stream input/output
  str_bus_if.d                  sti,      // input
  str_bus_if.s                  sto,      // output
  // configuration
  input  logic signed [DWM-1:0] cfg_mul,  // gain
  input  logic signed [DWS-1:0] cfg_sum   // offset
);

////////////////////////////////////////////////////////////////////////////////
// local signals
////////////////////////////////////////////////////////////////////////////////

str_bus_if #(.DAT_T (logic signed [DWI+DWM  -1:0])) str_mul (.clk (clk), .rstn (rstn));
str_bus_if #(.DAT_T (logic signed [DWI+    1-1:0])) str_shf (.clk (clk), .rstn (rstn));
str_bus_if #(.DAT_T (logic signed [DWI+    2-1:0])) str_sum (.clk (clk), .rstn (rstn));

logic str_mul_trn;
logic str_shf_trn;
logic str_sum_trn;

////////////////////////////////////////////////////////////////////////////////
// multiplication
////////////////////////////////////////////////////////////////////////////////

assign sti_trn = sti.vld & sti.rdy;

always_ff @(posedge clk)
if (sti_trn)  str_mul.dat <= sti.dat * cfg_mul;

always_ff @(posedge clk)
if (~rstn)         str_mul.vld <= 1'b0;
else if (sti.rdy)  str_mul.vld <= sti.vld;

assign sti.rdy = str_mul.rdy | ~str_mul.vld;

////////////////////////////////////////////////////////////////////////////////
// shift
////////////////////////////////////////////////////////////////////////////////

assign str_shf.dat = str_mul.dat >>> (DWM-2);

assign str_shf.vld = str_mul.vld;

assign str_mul.rdy = str_shf.rdy;

////////////////////////////////////////////////////////////////////////////////
// summation
////////////////////////////////////////////////////////////////////////////////

assign shf_trn = str_shf.vld & str_shf.rdy;

always_ff @(posedge clk)
if (shf_trn)  str_sum.dat <= str_shf.dat + cfg_sum;

always_ff @(posedge clk)
if (~rstn)             str_sum.vld <= 1'b0;
else if (str_shf.rdy)  str_sum.vld <= str_shf.vld;

assign str_shf.rdy = sto.rdy | ~str_sum.vld;

////////////////////////////////////////////////////////////////////////////////
// saturation
////////////////////////////////////////////////////////////////////////////////

assign sum_trn = str_sum.vld & str_sum.rdy;

always_ff @(posedge clk)
if (sum_trn)  sto.dat <= ^str_sum.dat[DWO:DWO-1] ? {str_sum.dat[DWO], {DWO-1{~str_sum.dat[DWO-1]}}}
                                                 :  str_sum.dat[DWO-1:0];

always_ff @(posedge clk)
if (~rstn)             sto.vld <= 1'b0;
else if (str_sum.rdy)  sto.vld <= str_sum.vld;

assign str_sum.rdy = sto.rdy | ~str_sum.vld;

endmodule: linear
