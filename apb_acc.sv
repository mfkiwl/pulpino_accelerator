

`define REG_ACC_IN         4'b0001 //BASEADDR+0x04
`define REG_ACC_OUT        4'b0010 //BASEADDR+0x08
`define CONFIG_REG         4'b0011 //BASEADDR+0x0C
`define COUNTER_REG        4'b0100 //BASEADDR+0x10
`define REG_ACC_VALID_OUT  4'b0101 //BASEADDR+0x14

`define IDLE_STATE         2'b00 
`define TRANSFER_STATE     2'b01 


module apb_acc
#(
    parameter APB_ADDR_WIDTH = 12  //APB slaves are 4KB by default
)
(
    input  logic                      HCLK,
    input  logic                      HRESETn,
    input  logic [APB_ADDR_WIDTH-1:0] PADDR,
    input  logic               [31:0] PWDATA,
    input  logic                      PWRITE,
    input  logic                      PSEL,
    input  logic                      PENABLE,
    output logic               [31:0] PRDATA,
    output logic                      PREADY,
    output logic                      PSLVERR

);
  logic clk;
  logic [31:0] data_in;
  logic [11:0] addr;
  logic [31:0] data_out = 0;
  //logic [31:0] cfg;
  //logic clock_enable;
  //logic done;
  logic valid;
  logic [31:0] counter = 0 ;
  logic ready;
  logic valid_out;
  logic [1:0] next_state, current_state;


  //next state logic (clock_enable management)
   always_comb
    begin
      case (current_state)
        `IDLE_STATE:
          begin
            if((PSEL && PENABLE && PWRITE) && (addr == `REG_ACC_IN))
              next_state = `TRANSFER_STATE;
            else 
              next_state = `IDLE_STATE;            
          end

        `TRANSFER_STATE:
          begin
            if(ready == 1)
              next_state = `IDLE_STATE;
            else 
              next_state = `TRANSFER_STATE;  
          end

        default:
          next_state = `IDLE_STATE;
      endcase


    end


  genericfir genericfir_i
  (
      .i_clk(clk),
			.i_ce(valid),
			.i_sample(data_in),
			.o_result(data_out),
      .o_valid_first(ready),
      .o_valid_result(valid_out)
  );

  
  assign clk = HCLK;
  assign addr = PADDR[11:2]; //accelerator is word-addressed 
  
  //next state sequential logic (clock enable management)
  always_ff@(posedge HCLK)
    current_state <= next_state;


  //output logic (clock enable management)
  always_comb
    begin
      case(current_state)
        `IDLE_STATE: valid = 0;
        `TRANSFER_STATE: valid = 1;
      endcase
    end






  // always_ff@(posedge HCLK)
  //   begin
  //     if((PSEL && PENABLE && PWRITE) && (addr == `REG_ACC_IN))
        
  //        valid <= 1; 

  //   end

  // always_ff@(negedge HCLK)
	// begin
	// 	if(ready)
	// 	  valid <= 0;
	// end



  //assign inputs from the bus
  always_ff@(posedge HCLK)
    begin
      if(PSEL && PENABLE && PWRITE)
        begin
          case (addr)
			//`CONFIG_REG:
              //cfg[31:0] <= PWDATA[31:0];
            `REG_ACC_IN:
              begin
			          data_in[31:0] <= PWDATA[31:0];
                counter <= counter + 1;
              end
			  		
				
            default:
              data_in[31:0] <= 32'h00000000;

          endcase

        end
    end
  //assign outputs to the bus from the accelerator
  always_comb
    begin
      PRDATA = '0;
      case (addr)
        `REG_ACC_OUT:
          begin
            //data_out[31:0] = data_in[31:0] + 32'h0000BEEF;
            PRDATA[31:0] <= data_out[31:0];
          end

          `COUNTER_REG:
          begin
            //data_out[31:0] = data_in[31:0] + 32'h0000BEEF;
            PRDATA[31:0] <= counter[31:0];
          end

          `REG_ACC_VALID_OUT:
          begin
            
            PRDATA[31:0] <= valid_out;
          end



        default:
          PRDATA[31:0] <= 32'b11111111111111111111111111111111;
      endcase


    end

  assign PREADY = 1'b1;
  assign PSLVERR = 1'b0;



endmodule





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
        `FIRST_STAGE:
          begin
            if(i_ce == 1)
             next_state = `SECOND_STAGE; 
            else 
             next_state = `FIRST_STAGE;
          
          end
          
        `SECOND_STAGE:
          begin
            if(i_ce == 1)
              next_state = `FIRST_STAGE;
          end
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
        `SECOND_STAGE: if (i_ce) o_valid = 0; else o_valid=1;
        
        
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



//
// module	firtap(i_clk, i_tap, o_tap,
// 		i_ce, i_sample, o_sample,
// 		i_partial_acc, o_acc, o_valid);
// 	parameter		IW=16, TW=IW, OW=IW+TW+8; //input width, tap width, output width
// 	//
// 	input	logic			i_clk;
// 	//
// 	input	logic	[(TW-1):0]	i_tap;
// 	output	logic signed [(TW-1):0]	o_tap;
// 	//
// 	input	logic			i_ce;
// 	input	logic signed [(IW-1):0]	i_sample;
// 	output	logic	[(IW-1):0]	o_sample;
// 	//
// 	input	logic	[(OW-1):0]	i_partial_acc;
// 	output	logic	[(OW-1):0]	o_acc;
// 	//
//   output logic o_valid;

// 	logic		[(IW-1):0]	delayed_sample;
// 	logic	signed	[(TW+IW-1):0]	product;

// 	// Our taps are fixed, the tap is given by the i_tap
// 	// external input.  This allows the parent module to be
// 	// able to use readmemh to set all of the taps in a filter
// 	assign	o_tap = i_tap;


// 	// Forward the sample on down the line, to be the input sample for the
// 	// next component
// 	initial	o_sample = 0;
// 	initial	delayed_sample = 0;
//   initial o_valid = 0;
// 	always @(posedge i_clk)
		
//  		if (i_ce)
// 		begin
// 			// Note the two sample delay in this forwarding
// 			// structure.  This aligns the inputs up so that the
// 			// accumulator structure (below) works.
// 			delayed_sample <= i_sample;
// 			o_sample <= delayed_sample;
     
// 		end

//   always @(negedge i_clk)
//     if(i_ce)
//       o_valid = 0;


// 	// Multiply the filter tap by the incoming sample
// 	always @(posedge i_clk)
// 		 if (i_ce)
// 			product <= o_tap * i_sample;


// 	// Continue summing together the output components of the FIR filter
// 	initial	o_acc = 0;
// 	always @(posedge i_clk)

// 		 if (i_ce)
//       begin
//         o_acc <= i_partial_acc
//           + { {(OW-(TW+IW)){product[(TW+IW-1)]}},
//               product }; //sign extension
//         o_valid = 1;
//       end

// endmodule


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
	logic	[(TW-1):0] tapout	[NTAPS:0];
	logic	[(IW-1):0] sample	[NTAPS:0];
	logic	[(OW-1):0] result	[NTAPS:0];
  logic	           valid	[NTAPS:0];
	logic		tap_wr; //delete it?

	// The first sample in our sample chain is the sample we are given
	assign	sample[0]	= i_sample;
	// Initialize the partial summing accumulator with zero
	assign	result[0]	= 0;

	genvar	k;
	generate
	
	begin
		initial $readmemh("/home/andreacongiu/tesiPulpinoMto/pulpino/ips/apb/apb_acc/taps.mem", tap); //change the path according to simulation environment

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