module	genericfir(i_clk, i_ce, i_sample, o_result,o_valid_first,o_valid_result);
	parameter		NTAPS=5, IW=12, TW=IW, OW=2*IW+7;
	input	logic			i_clk;
	//
	//
	input	logic			i_ce;
	input	logic	[(IW-1):0]	i_sample;
	output	logic	[(OW-1):0]	o_result;
    output logic o_valid_first;
    output logic o_valid_result;

	logic   	[(TW-1):0] tap		[NTAPS:0];
	logic	    [(TW-1):0] tapout   [NTAPS:0];
	logic	[(IW-1):0] sample	    [NTAPS:0];
	logic	[(OW-1):0] result	    [NTAPS:0];
    logic	  [0:0]         valid	[NTAPS:0];
	logic		tap_wr; //delete it?

	// The first sample in our sample chain is the sample we are given
	assign	sample[0]	= i_sample;
	// Initialize the partial summing accumulator with zero
	assign	result[0]	= 0;

	genvar	k;
	generate
	
	begin
		initial $readmemh("taps.txt", tap); //change the path according to simulation environment

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
				result[k], result[k+1],
        // The valid data signal
        valid[k]);



	end endgenerate

	assign	o_result = result[NTAPS];
    assign  o_valid_first = valid[0];
    assign  o_valid_result = (o_result !== 'X) ? 1 : 0;



endmodule