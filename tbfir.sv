module tbfir;

//inputs

logic Clk;
logic signed [11:0] Xin;
logic Ice;

// Outputs
logic signed [30:0] Yout;


    // Instantiate the Unit Under Test (UUT)
    genericfir uut (
        .i_clk(Clk),
        .i_ce(Ice), 
        .i_sample(Xin), 
        .o_result(Yout)
    );

//Generate a clock with 10 ns clock period.
initial 
    begin
        Clk = 0;
        Ice = 1;
    end
always #5 Clk =~Clk;

//Initialize and apply the inputs.
    initial begin
          Xin = 0;  #40;
          Xin = 1; #10;
          Xin = 0;  #10;
          Xin = 0;  #10;
          Xin = 0; #10;
          Xin = 0; #10;
          Xin = 0;  #10;
          Xin = 0; #10;
          Xin = 0;  #10;
          Xin = 0;  #10;
    end

endmodule
