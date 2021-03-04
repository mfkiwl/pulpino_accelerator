`define REG_ACC_IN       4'b0001 //BASEADDR+0x04
`define REG_ACC_OUT      4'b0010 //BASEADDR+0x08
`define CONFIG_REG       4'b0011 //BASEADDR+0x0C
`define COUNTER_REG       4'b0100 //BASEADDR+0x10

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
  logic [31:0] data_out;
  //logic [31:0] cfg;
  //logic clock_enable;
  //logic done;
  logic valid;
  logic [31:0] counter = 0 ;
  logic ready;

  // initial
  // counter = 0;

  genericfir genericfir_i
  (
            .i_clk(clk),
            //.i_ce(clock_enable),
			.i_ce(valid),
			.i_sample(data_in),
			.o_result(data_out),
      .o_valid_first(ready)
  );

  //initial
  //clock_enable = 1;
  //assign clock_enable = cfg[0];
  //assign done = cfg[1];

  //assign valid = (PSEL && PENABLE && PWRITE) && (addr == `REG_ACC_IN);
  
  assign clk = HCLK;
  assign addr = PADDR[11:2]; //accelerator is word-addressed  //assign inputs from the bus
  
  always_ff@(posedge HCLK)
    begin
      if((PSEL && PENABLE && PWRITE) && (addr == `REG_ACC_IN))
        
         valid <= 1; 

    end

  always_ff@(negedge HCLK)
	begin
		if(ready)
		  valid <= 0;
	end



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


        default:
          PRDATA[31:0] <= 32'b11111111111111111111111111111111;
      endcase


    end

  assign PREADY = 1'b1;
  assign PSLVERR = 1'b0;



endmodule