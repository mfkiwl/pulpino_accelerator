//module	firtap(i_clk, i_tap, o_tap,
//		i_ce, i_sample, o_sample,
//		i_partial_acc, o_acc, o_valid);
//	parameter		IW=16, TW=IW, OW=IW+TW+8; //input width, tap width, output width
//	//
//	input	logic			i_clk;
//	//
//	input	logic	[(TW-1):0]	i_tap;
//	output	logic signed [(TW-1):0]	o_tap;
//	//
//	input	logic			i_ce;
//	input	logic signed [(IW-1):0]	i_sample;
//	output	logic	[(IW-1):0]	o_sample;
//	//
//	input	logic	[(OW-1):0]	i_partial_acc;
//	output	logic	[(OW-1):0]	o_acc;
//	//
//  output logic o_valid;

//	logic		[(IW-1):0]	delayed_sample;
//	logic	signed	[(TW+IW-1):0]	product;

//	// Our taps are fixed, the tap is given by the i_tap
//	// external input.  This allows the parent module to be
//	// able to use readmemh to set all of the taps in a filter
//	assign	o_tap = i_tap;


//	// Forward the sample on down the line, to be the input sample for the
//	// next component
//	initial	o_sample = 0;
//	initial	delayed_sample = 0;
//  initial o_valid = 0;
//	always @(posedge i_clk)
		
// 		if (i_ce)
//		begin
//			// Note the two sample delay in this forwarding
//			// structure.  This aligns the inputs up so that the
//			// accumulator structure (below) works.
//			delayed_sample <= i_sample;
//			o_sample <= delayed_sample;
     
//		end

//  always @(negedge i_clk)
//    if(i_ce)
//      o_valid = 0;


//	// Multiply the filter tap by the incoming sample
//	always @(posedge i_clk)
//		 if (i_ce)
//			product <= o_tap * i_sample;


//	// Continue summing together the output components of the FIR filter
//	initial	o_acc = 0;
//	always @(posedge i_clk)

//		 if (i_ce)
//      begin
//        o_acc <= i_partial_acc
//          + { {(OW-(TW+IW)){product[(TW+IW-1)]}},
//              product }; //sign extension
//        o_valid = 1;
//      end

//endmodule


 `define FIRST_STAGE 2'b00
 `define SECOND_STAGE 2'b01



module	firtap(i_clk, i_tap, o_tap,
		i_ce, i_sample, o_sample,
		i_partial_acc, o_acc, o_valid);
	parameter		IW=16, TW=IW, OW=IW+TW+8; //input width, tap width, output width
	//
	input	logic			i_clk;
	//
	input	logic	[(TW-1):0]	i_tap;
	output	logic signed [(TW-1):0]	o_tap;
	//
	input	logic			i_ce;
	input	logic signed [(IW-1):0]	i_sample;
	output	logic	[(IW-1):0]	o_sample;
	//
	input	logic	[(OW-1):0]	i_partial_acc;
	output	logic	[(OW-1):0]	o_acc;
	//
    output logic o_valid;
    logic [1:0] current_state, next_state;
    

  //next state logic (o_valid signal management)
   always_comb
    begin
      case (current_state)
        `FIRST_STAGE: next_state = `SECOND_STAGE;
          
        `SECOND_STAGE: next_state = `FIRST_STAGE;
        
        default:       next_state = `FIRST_STAGE;
          
      endcase
    end
        
      //next state sequential logic (o_valid signal management)
  always_ff@(posedge i_clk)
    current_state <= next_state;


  //output logic (clock enable management)
  always_comb
    begin
      case(current_state)
        `FIRST_STAGE: if(i_ce) o_valid = 1; else o_valid=0;
        `SECOND_STAGE:if(i_ce) o_valid = 0; else o_valid=1;
        
        
      endcase
    end    
        
    
	logic		[(IW-1):0]	delayed_sample;
	logic	signed	[(TW+IW-1):0]	product;

	// Our taps are fixed, the tap is given by the i_tap
	// external input.  This allows the parent module to be
	// able to use readmemh to set all of the taps in a filter
	assign	o_tap = i_tap;


	// Forward the sample on down the line, to be the input sample for the
	// next component
	initial	o_sample = 0;
	initial	delayed_sample = 0;
  //initial o_valid = 0;
	always @(posedge i_clk)
		
 		if (i_ce)
		begin
			// Note the two sample delay in this forwarding
			// structure.  This aligns the inputs up so that the
			// accumulator structure (below) works.
			delayed_sample <= i_sample;
			o_sample <= delayed_sample;
     
		end

//  always @(negedge i_clk)
//    if(i_ce)
//      o_valid = 0;


	// Multiply the filter tap by the incoming sample
	always @(posedge i_clk)
		 if (i_ce)
			product <= o_tap * i_sample;


	// Continue summing together the output components of the FIR filter
	initial	o_acc = 0;
	always @(posedge i_clk)

		 if (i_ce)
      begin
        o_acc <= i_partial_acc
          + { {(OW-(TW+IW)){product[(TW+IW-1)]}},
              product }; //sign extension
//        o_valid = 1;
      end

endmodule