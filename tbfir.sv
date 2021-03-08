module tbfir;

//inputs

logic Clk;
logic signed [11:0] Xin;
logic Ice;
logic firstDataValid;
logic lastDataValid;
logic [31:0] counter;

// Outputs
logic signed [30:0] Yout;


    // Instantiate the Unit Under Test (UUT)
    genericfir uut (
        .i_clk(Clk),
        .i_ce(Ice), 
        .i_sample(Xin), 
        .o_result(Yout),
        .o_valid_first(firstDataValid),
        .o_valid_result(lastDataValid)
    );

//Generate a clock with 10 ns clock period.
initial 
    begin
        Clk = 0;
        Ice = 1;
        counter = 0;
    end
always #5 Clk =~Clk;




//always #10 Ice =~Ice;

//Initialize and apply the inputs.
    initial begin
          Xin = 1; counter= counter+1;  #10;
          Xin = 0; counter= counter+1; #10;
          Xin = 0; counter= counter+1; #10;
          Xin = 0; counter= counter+1; #10;
          Xin = 0; counter= counter+1;#10;
          Xin = 0; counter= counter+1; #10;
          Xin = 0; counter= counter+1;#10;
          Xin = 0; counter= counter+1;#10;
          

    end

endmodule
