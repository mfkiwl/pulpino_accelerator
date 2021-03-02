`default_nettype	none
<<<<<<< HEAD
//hello
=======
//
>>>>>>> 14a8d2dd0be5df05cb4ee966d516bd6cde6ff680
module	genericfir(i_clk, i_ce, i_sample, o_result);
	parameter		NTAPS=5, IW=12, TW=IW, OW=2*IW+7;
	input	wire			i_clk;
	//
	//
	input	wire			i_ce;
	input	wire	[(IW-1):0]	i_sample;
	output	wire	[(OW-1):0]	o_result;

	reg    	[(TW-1):0] tap		[NTAPS:0];
	wire	[(TW-1):0] tapout	[NTAPS:0];
	wire	[(IW-1):0] sample	[NTAPS:0];
	wire	[(OW-1):0] result	[NTAPS:0];
	wire		tap_wr; //delete it?

	// The first sample in our sample chain is the sample we are given
	assign	sample[0]	= i_sample;
	// Initialize the partial summing accumulator with zero
	assign	result[0]	= 0;

	genvar	k;
	generate
	
	begin
		initial $readmemh("taps.txt", tap);

		assign	tap_wr = 1'b0;
	end 

	for(k=0; k<NTAPS; k=k+1)
	begin: FILTER

		firtap #(.IW(IW), .OW(OW), .TW(TW)
				)
			tapk(i_clk, 
				// Tap update circuitry
				 tap[NTAPS-1-k], tapout[k],
				// Sample delay line
				i_ce, sample[k], sample[k+1],
				// The output accumulator
				result[k], result[k+1]);



	end endgenerate

	assign	o_result = result[NTAPS];



endmodule
