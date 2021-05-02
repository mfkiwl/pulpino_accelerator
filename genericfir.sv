
 `define IDLE_STATE_FILTER      2'b00
 `define TRANSFER_STATE_FILTER  2'b01
 `define EMPTY_OUT_STATE_FILTER 2'b10

module	genericfir(i_clk, i_reset, i_ce, i_ntaps, i_ntaps_en, i_output_lenght, i_tap_wr, i_new_tap, i_sample, o_result, o_valid_first, o_valid_result, o_clean_pip);
	parameter		NTAPS=8, IW=12, TW=IW, OW=2*IW+7;
	input	logic			i_clk, i_reset;

	
	input logic [15:0] i_output_lenght;
	input logic [3:0] i_ntaps; 
	input logic i_ntaps_en;
	input logic i_tap_wr;
	


	input	logic			i_ce;
	input	logic	[(IW-1):0]	i_sample;
	output	logic	[(OW-1):0]	o_result;
	input   logic   [(TW-1):0] i_new_tap		[NTAPS-1:0] ;
  output logic o_valid_first;
  output logic o_valid_result;
  output logic o_clean_pip;

	logic [(TW-1):0] tap		[NTAPS-1:0];
	
	logic	[(TW-1):0] tapout	[NTAPS-1:0];
	logic	[(IW-1):0] sample	[NTAPS:0];
	logic	[(OW-1):0] result	[NTAPS:0];
  logic	           valid	[NTAPS-1:0];

  logic [3:0]      ntaps = NTAPS;
  logic [15:0]     input_counter = 0;
  logic [1:0]      current_state = `IDLE_STATE_FILTER , next_state;
  logic [15:0]     signal_lenght;
  logic [15:0]     output_lenght = 0;
  logic            i_ce_reg;
    
    assign signal_lenght = output_lenght + ntaps-1;
    //assign i_tap_wr =tap_wr;
    
    
    
	// The first sample in our sample chain is the sample we are given
	assign	sample[0]	= i_sample;
	// Initialize the partial summing accumulator with zero
	assign	result[0]	= 0;

	genvar	k;
	generate
	
	begin

		initial $readmemh("/home/andreacongiu/tesiPulpinoMto/pulpino/ips/apb/apb_acc/taps.mem", tap); //change the path according to simulation environment
    //initial $readmemh("taps.mem", tap); //change the path according to simulation environment
		//assign	tap_wr = 1'b0;

	end 
	

	for(k=0; k<NTAPS; k=k+1)
	begin: FILTER

		firtap #(.IW(IW), .OW(OW), .TW(TW)
				)
			tapk(i_clk, i_reset, 
				// Tap update circuitry
				 tap[NTAPS-1-k], tapout[k],
				// Sample delay line
				i_ce, sample[k], sample[k+1],
				// The output accumulator
				result[k], result[k+1],
        // The valid data signal
        valid[k]);



	end endgenerate
	    
   //update output lenght      
  always_ff@(posedge i_clk)
    output_lenght <= i_output_lenght;
        
  //tap update logic 
  always_ff@(posedge i_clk)
    if(i_tap_wr)
        tap <= i_new_tap;
        
  //counter of inputs      
  always_ff@(posedge i_clk)
    if(i_reset || (input_counter >= ( signal_lenght + ntaps)) )
        input_counter <= 0;
    else if(i_ce)
        input_counter <= input_counter + 1;
        
  //selection for the number of taps     
  always_ff@(posedge i_clk)
    if(i_ntaps_en)
        ntaps <= i_ntaps;
        
        
//next state sequential logic (clean_pip signal management)
  always_ff@(posedge i_clk)
    current_state <= next_state;
    
    
 //next state logic (clean_pip signal management)
   always_comb
    begin
      case (current_state)
        `IDLE_STATE_FILTER:
          begin
            if(i_ce)
              next_state = `TRANSFER_STATE_FILTER;
            else if(i_reset)
              next_state = `IDLE_STATE_FILTER;            
          end

        `TRANSFER_STATE_FILTER:
          begin
            if(i_ce && (input_counter >= signal_lenght))
              next_state = `EMPTY_OUT_STATE_FILTER;
            else if((i_ce && (input_counter <= signal_lenght)) && i_reset == 0)
              next_state = `TRANSFER_STATE_FILTER;  
            else if(i_reset == 1)
               next_state = `IDLE_STATE_FILTER;
          end
          
          `EMPTY_OUT_STATE_FILTER:
          begin
            if( ( input_counter >= ( signal_lenght + ntaps-1) ) || i_reset == 1 )
              begin
              next_state = `IDLE_STATE_FILTER;
          
              end
            else 
              next_state = `EMPTY_OUT_STATE_FILTER;  
          end
          
        default:
          next_state = `IDLE_STATE_FILTER;
      endcase

    end
    
 //output logic (clean_pip signal management)
  always_comb
    begin
      case(current_state)
        `IDLE_STATE_FILTER:
          begin
           o_clean_pip = 0; 
          end
        `TRANSFER_STATE_FILTER: o_clean_pip = 0;
        `EMPTY_OUT_STATE_FILTER: o_clean_pip = 1;
        
        default:
         o_clean_pip = 0;
      endcase
    end
    
    
//    always_ff@(posedge i_clk)
//        o_valid_result = ( ( input_counter >= (2*ntaps - 1 ) )  );
  always_ff@(posedge i_clk)
    i_ce_reg <= i_ce;
 
  assign  o_result = result[ntaps]; 
  assign  o_valid_first = valid[0];
  assign  o_valid_result = ( ( input_counter >= (2*ntaps ) )  ) && i_ce_reg;


endmodule