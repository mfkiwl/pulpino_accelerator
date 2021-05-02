

`define REG_ACC_IN         5'b00001 //BASEADDR+0x04
`define REG_ACC_OUT        5'b00010 //BASEADDR+0x08
`define CONFIG_REG         5'b00011 //BASEADDR+0x0C
`define COUNTER_REG        5'b00100 //BASEADDR+0x10
`define REG_ACC_VALID_OUT  5'b00101 //BASEADDR+0x14
`define REG_ACC_NTAPS      5'b00110 //BASEADDR+0x18
`define REG_TAP_0          5'b00111 //BASEADDR+0x1C
`define REG_TAP_1          5'b01000 //BASEADDR+0x20
`define REG_TAP_2          5'b01001 //BASEADDR+0x24
`define REG_TAP_3          5'b01010 //BASEADDR+0x28
`define REG_TAP_4          5'b01011 //BASEADDR+0x2C
`define REG_TAP_5          5'b01100 //BASEADDR+0x30
`define REG_TAP_6          5'b01101 //BASEADDR+0x34
`define REG_TAP_7          5'b01110 //BASEADDR+0x38
`define REG_TAP_8          5'b01111 //BASEADDR+0x3C
`define REG_OUTPUT_LENGHT  5'b10000 //BASEADDR+0x40



`define IDLE_STATE         2'b00 
`define TRANSFER_STATE     2'b01 
`define EMPTY_OUT_STATE    2'b10 


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

  parameter		NTAPS=8, IW=12, TW=IW, OW=2*IW+7;
  logic clk;
  logic [31:0] data_in;
  logic [11:0] addr;
  logic [31:0] data_out = 0;
  logic [3:0]  ntaps;


  // bit[0] -> ntaps_en || bit[1] -> tap_wr || bit[2] -> reset_filter || bit[3] -> reset_fifo || bit[4] -> fifo_en || bit[5] -> fifo_empty || bit[6] -> fifo_full || 
  logic [31:0] cfg = 0 ; 
  logic valid;
  logic [31:0] counter = 0 ;
  logic ready;
  logic valid_out;
  logic clean_pip;
  logic [1:0] next_state, current_state;
  logic [(TW-1):0] new_tap	[NTAPS-1:0] ;
  logic [31:0] output_lenght;
  logic [31:0] filter_output;



  //next state logic (clock_enable management)
  always_comb
    begin
      case (current_state)
        `IDLE_STATE:
          begin
            if((PSEL && PENABLE && PWRITE) && (addr == `REG_ACC_IN))
              next_state = `TRANSFER_STATE;
            else
            if(clean_pip == 1)
              next_state = `EMPTY_OUT_STATE;            
          end

        `TRANSFER_STATE:
          begin
            if(ready == 1)
              next_state = `IDLE_STATE;
            else 
              next_state = `TRANSFER_STATE;  
          end

        `EMPTY_OUT_STATE:
          begin
            if(clean_pip == 1)
              next_state = `EMPTY_OUT_STATE;
            else 
              next_state = `IDLE_STATE;  
          end


        default:
          next_state = `IDLE_STATE;
      endcase

    end


  genericfir genericfir_i
  (
      .i_clk(clk),
      .i_reset(cfg[2]),
			.i_ce(valid),
      .i_ntaps(ntaps),
      .i_ntaps_en(cfg[0]),
      .i_output_lenght(output_lenght),
      .i_new_tap(new_tap),
      .i_tap_wr(cfg[1]),
      .o_result(filter_output),
			.i_sample(data_in),
      .o_valid_first(ready),
      .o_valid_result(valid_out),
      .o_clean_pip(clean_pip)

  );



  FIFObuffer #(.DATA_SIZE(OW),.SIZE(16)) FIFObuffer_i
  (
      .i_clk(clk),
      .i_reset(cfg[3]),
      .i_en(cfg[4]),
      .i_write(valid_out),
      .i_read(read_fifo),
      .i_data(filter_output),
      .o_data(data_out),
      .o_empty(cfg[5]),
      .o_full(cfg[6])
			
  );


  assign read_fifo = (PSEL && PENABLE && !PWRITE && (addr == `REG_ACC_OUT));
  
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
        `EMPTY_OUT_STATE: valid = 1;

      endcase
    end
  


  //assign inputs from the bus
  always_ff@(posedge HCLK)
    begin
      if(PSEL && PENABLE && PWRITE)
        begin
          case (addr)

			      `CONFIG_REG:
              cfg[31:0] <= PWDATA[31:0];

            `REG_ACC_IN:
              begin
			          data_in[31:0] <= PWDATA[31:0];
                counter <= counter + 1;
              end

            `REG_ACC_NTAPS:
              begin
                ntaps[3:0] <= PWDATA[31:0];
              end

            `REG_TAP_0:
              begin
                new_tap[0] <= PWDATA[31:0];
              end

            `REG_TAP_1:
              begin
                new_tap[1] <= PWDATA[31:0];
              end

            `REG_TAP_2:
              begin
                new_tap[2] <= PWDATA[31:0];
              end

            `REG_TAP_3:
              begin
                new_tap[3] <= PWDATA[31:0];
              end

            `REG_TAP_4:
              begin
                new_tap[4] <= PWDATA[31:0];
              end 

            `REG_TAP_5:
              begin
                new_tap[5] <= PWDATA[31:0];
              end

            `REG_TAP_6:
              begin
                new_tap[6] <= PWDATA[31:0];
              end

            `REG_TAP_7:
              begin
                new_tap[7] <= PWDATA[31:0];
              end

            `REG_OUTPUT_LENGHT:
              begin
                output_lenght <= PWDATA[31:0];
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
            
            PRDATA[31:0] <= data_out[31:0];
          end

        `COUNTER_REG:
          begin
            
            PRDATA[31:0] <= counter[31:0];
          end

        `REG_ACC_VALID_OUT:
          begin
            
            PRDATA[31:0] <= valid_out;
          end

        `CONFIG_REG:
          begin
            
            PRDATA[31:0] <= cfg[31:0];
          end

        `REG_TAP_0:
          begin
            PRDATA[31:0] <= new_tap[0];
          end

        `REG_TAP_1:
          begin
            PRDATA[31:0] <= new_tap[1];
          end

        `REG_TAP_2:
          begin
            PRDATA[31:0] <= new_tap[2];
          end

        `REG_TAP_3:
          begin
            PRDATA[31:0] <= new_tap[3];
          end

        `REG_TAP_4:
          begin
            PRDATA[31:0] <= new_tap[4];
          end 

        `REG_TAP_5:
          begin
            PRDATA[31:0] <= new_tap[5];
          end

        `REG_TAP_6:
          begin
            PRDATA[31:0] <= new_tap[6];
          end

        `REG_TAP_7:
          begin
            PRDATA[31:0] <= new_tap[7];
          end 

        `REG_OUTPUT_LENGHT:
          begin
            PRDATA[31:0] <= output_lenght;
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



module	firtap(i_clk, i_reset, i_tap, o_tap,
		i_ce, i_sample, o_sample,
		i_partial_acc, o_acc, o_valid);
	parameter		IW=16, TW=IW, OW=IW+TW+8; //input width, tap width, output width
	//
	input	logic			i_clk, i_reset;
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
            else if(i_reset == 1 || i_ce == 0)
             next_state = `FIRST_STAGE;
          end
          
        `SECOND_STAGE:
          begin
            if(i_ce == 1 || i_reset == 1)
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

	// Taps are initially fixed, new taps are given by 
	// external input.  This allows the parent module to be
	// able to use readmemh to set all of the taps in a filter
	assign	o_tap = i_tap;


	// Forward the sample on down the line, to be the input sample for the
	// next component
	initial	o_sample = 0;
	initial	delayed_sample = 0;
  
	always @(posedge i_clk)
	if (i_reset)
	   begin
		delayed_sample <= 0;
		o_sample <= 0;	
	   end
	else if (i_ce)
		begin
			// Note the two sample delay in this forwarding
			// structure.  This aligns the inputs up so that the
			// accumulator structure (below) works.
			delayed_sample <= i_sample;
			o_sample <= delayed_sample;
     
		end


	// Multiply the filter tap by the incoming sample
	always @(posedge i_clk)
	   if (i_reset)
			product <= 0;
	   else if (i_ce)
			product <= o_tap * i_sample;


	// Continue summing together the output components of the FIR filter
	initial	o_acc = 0;
	always @(posedge i_clk)
	   if (i_reset)
		  o_acc <= 0;
	else if (i_ce)
      begin
        o_acc <= i_partial_acc
          + { {(OW-(TW+IW)){product[(TW+IW-1)]}},
              product }; //sign extension

      end

endmodule


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


module FIFObuffer#(parameter DATA_SIZE=16, parameter SIZE=8, parameter ADDR_SIZE=$clog2(SIZE))( i_clk, i_data, i_read, i_write, i_en, o_data, i_reset, o_empty, o_full); 

                   
input logic  i_clk, i_read, i_write, i_en, i_reset;

output logic  o_empty, o_full;

input logic   [DATA_SIZE-1:0]    i_data;

output logic [DATA_SIZE-1:0] o_data;

 // internal registers 
logic last_write_not_read;


logic [ADDR_SIZE:0]  counter = 0; 

logic [DATA_SIZE-1:0] FIFO [0:SIZE-1]; 

logic [ADDR_SIZE:0]  readCounter = 0,  writeCounter = 0; 

assign o_empty = (counter==0)? 1'b1:1'b0; 

assign o_full  = (counter==SIZE)? 1'b1:1'b0; 

assign o_data  = FIFO[readCounter]; 

always @ (posedge i_clk or posedge i_reset) 
    begin
        if(i_reset)
            last_write_not_read <= 0;
        else if(i_read && !i_write)
            last_write_not_read <= 0;
        else if(!i_read && i_write)
            last_write_not_read <= 1;
    end

always @ (posedge i_clk) 

begin 

 if (i_en==0); 

 else 
 begin 

      if (i_reset)
       begin 
    
         readCounter = 0; 
    
         writeCounter = 0; 
    
       end 
    
      else if (i_read ==1'b1 && counter!=0)
       begin 
    
         //o_data  = FIFO[readCounter]; 
    
         readCounter = readCounter+1; 
    
       end 
    
      else if (i_write==1'b1 && counter<SIZE)
       begin
         FIFO[writeCounter]  = i_data; 
    
         writeCounter  = writeCounter+1; 
    
       end 
    
      else; 

 end 

 if (writeCounter==SIZE) 

  writeCounter=0; 

 else if (readCounter==SIZE) 

          readCounter=0; 

      else;

 if (readCounter > writeCounter)
  begin 

    counter=SIZE-(readCounter-writeCounter); 

  end 

 else if (writeCounter > readCounter) 

  counter = writeCounter-readCounter; 

 else if(last_write_not_read)
    counter=SIZE;
else
    counter=0;

end 

endmodule