
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