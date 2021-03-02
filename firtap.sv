
`default_nettype	none
//
module	firtap(i_clk, i_tap, o_tap,
		i_ce, i_sample, o_sample,
		i_partial_acc, o_acc);
	parameter		IW=16, TW=IW, OW=IW+TW+8; //input width, tap width, output width
	//
	input	wire			i_clk;
	//
	input	wire	[(TW-1):0]	i_tap;
	output	wire signed [(TW-1):0]	o_tap;
	//
	input	wire			i_ce;
	input	wire signed [(IW-1):0]	i_sample;
	output	reg	[(IW-1):0]	o_sample;
	//
	input	wire	[(OW-1):0]	i_partial_acc;
	output	reg	[(OW-1):0]	o_acc;
	//

	reg		[(IW-1):0]	delayed_sample;
	reg	signed	[(TW+IW-1):0]	product;

	// Our taps are fixed, the tap is given by the i_tap
	// external input.  This allows the parent module to be
	// able to use readmemh to set all of the taps in a filter
	assign	o_tap = i_tap;


	// Forward the sample on down the line, to be the input sample for the
	// next component
	initial	o_sample = 0;
	initial	delayed_sample = 0;
	always @(posedge i_clk)
		
 		if (i_ce)
		begin
			// Note the two sample delay in this forwarding
			// structure.  This aligns the inputs up so that the
			// accumulator structure (below) works.
			delayed_sample <= i_sample;
			o_sample <= delayed_sample;
		end


	// Multiply the filter tap by the incoming sample
	always @(posedge i_clk)
		 if (i_ce)
			product <= o_tap * i_sample;


	// Continue summing together the output components of the FIR filter
	initial	o_acc = 0;
	always @(posedge i_clk)

		 if (i_ce)
			o_acc <= i_partial_acc
				+ { {(OW-(TW+IW)){product[(TW+IW-1)]}},
						product }; //sign extension

endmodule