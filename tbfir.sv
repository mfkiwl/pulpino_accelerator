module tbfir;

parameter		NTAPS=8, IW=12, TW=IW, OW=2*IW+7;

//inputs

logic Clk;
logic signed [11:0] Xin;
logic Ice;
logic firstDataValid;
logic OutputDataValid;
logic cleanpip;
logic [31:0] counter;
logic   [(TW-1):0] newtap		[NTAPS:0] ;
logic Reset=0;
logic [3:0] ntaps = 5;
logic ntapsen = 1;


logic [31:0] cfg = 32'h00000000;
logic tapwr=0;

logic [15:0] outputlenght = 2;

logic end_input;


// Outputs
logic signed [30:0] Yout;


    // Instantiate the Unit Under Test (UUT)
    genericfir uut (
        .i_clk(Clk),
        .i_reset(Reset),
        .i_ce(Ice), 
        .i_sample(Xin), 
        .i_tap_wr(tapwr),
        .i_ntaps(ntaps),
        .i_ntaps_en(ntapsen),
        .o_result(Yout),
        .o_valid_first(firstDataValid),        
        .o_valid_result(OutputDataValid),
        .o_clean_pip(cleanpip),
        .i_output_lenght(outputlenght),
        .i_new_tap(newtap)
    );

//Generate a clock with 10 ns clock period.
initial 
    begin
        Clk = 0;
        counter = 0;
    end
always #5 Clk =~Clk;

always_comb
    if(end_input)
        Ice=cleanpip;
     else
        Ice=1;
 


//always #10 Ice =~Ice;

//Initialize and apply the inputs.
    initial begin
    //Xin=0;
//    #50
        tapwr=1;
        
        newtap[7]=8;
        newtap[6]=7;
        newtap[5]=6;
        newtap[4]=5;
        newtap[3]=4;
        newtap[2]=3;
        newtap[1]=2;
        newtap[0]=1;
//        #10
//         //tapwr=0;
         
        


        end_input = 0;
          Xin = 1; counter= counter+1;  #10;
          Xin = 0; counter= counter+1; #10;
          Xin = 0; counter= counter+1; #10;
          Xin = 0; counter= counter+1; #10;
          Xin = 0; counter= counter+1;#10;
          Xin = 0; counter= counter+1;#10;
          Xin = 0; counter= counter+1;#10;
          Xin = 0; counter= counter+1;#10;
          Xin = 0; counter= counter+1;#10; 
          end_input = 1;
//          Xin = 0; counter= counter+1;#10;
//          Xin = 0; counter= counter+1;#10;
//          Xin = 0; counter= counter+1;#10;
//          Xin = 0; counter= counter+1;#10;
//          Xin = 0; counter= counter+1;#10;
//          Xin = 0; counter= counter+1;#10;
//          Xin = 0; counter= counter+1;#10;
//          Xin = 0; counter= counter+1;#10;
//          Xin = 0; counter= counter+1;#10;
          Xin = 0'bX;
          
//          #80
//          Reset=1;
//          #10
//          Reset=0;
//          counter= counter+1;#10;
//          counter= counter+1;#10;
//          counter= counter+1;#10;
//          counter= counter+1;#10;
//          counter= counter+1;#10;
//          counter= counter+1;#10;
//          counter= counter+1;#10;
//          counter= counter+1;#10;
//          counter= counter+1;#10;
//          counter= counter+1;#10;
//          counter= counter+1;#10;
//          counter= counter+1;#10;
//          counter= counter+1;#10;
          
          
//          seltap=7;
//          tapwr=1;
//          itap=15;
//          #10
//          //tapwr=0;
//          #10
          
//          seltap=6;
//          tapwr=1;
//          itap=14;
//          #10
//          //tapwr=0;
//          #10
          
//          seltap=5;
//          tapwr=1;
//          itap=13;
//          #10
//          //tapwr=0;
//          #10
          
          
//          seltap=4;
//          tapwr=1;
//          itap=12;
//          #10
//          //tapwr=0;
//          #10
          
//          seltap=3;
//          tapwr=1;
//          itap=11;
//          #10
//          //tapwr=0;
//          #10
//          tapwr=0;
          
          
//          Xin = 1; counter= counter+1;  #10;
//          Xin = 0; counter= counter+1; #10;
//          Xin = 0; counter= counter+1; #10;
//          Xin = 0; counter= counter+1; #10;
//          Xin = 0; counter= counter+1;#10;
//          Xin = 0; counter= counter+1; #10;
//          Xin = 0; counter= counter+1;#10;
//          Xin = 0; counter= counter+1;#10;
          
          

    end

endmodule
