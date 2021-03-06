// Copyright 2017 ETH Zurich and University of Bologna.
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the “License”); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.


#include <stdio.h>
#include <bench.h>
#include <stdint.h>

#define ACCELERATOR_BASE_ADDRESS 0x1A108000
#define ACCELERATOR_REGISTER_IN (ACCELERATOR_BASE_ADDRESS + 0x4)
#define ACCELERATOR_REGISTER_OUT (ACCELERATOR_BASE_ADDRESS + 0x8)
#define ACCELERATOR_REGISTER_CONFIG (ACCELERATOR_BASE_ADDRESS + 0xC)
#define ACCELERATOR_REGISTER_COUNTER (ACCELERATOR_BASE_ADDRESS + 0x10)
#define ACCELERATOR_REGISTER_VALID_OUT (ACCELERATOR_BASE_ADDRESS + 0x14)
#define ACCELERATOR_REGISTER_NTAPS (ACCELERATOR_BASE_ADDRESS + 0x18)
#define ACCELERATOR_REGISTER_TAP_0 (ACCELERATOR_BASE_ADDRESS + 0x1C)
#define ACCELERATOR_REGISTER_TAP_1 (ACCELERATOR_BASE_ADDRESS + 0x20)
#define ACCELERATOR_REGISTER_TAP_2 (ACCELERATOR_BASE_ADDRESS + 0x24)
#define ACCELERATOR_REGISTER_TAP_3 (ACCELERATOR_BASE_ADDRESS + 0x28)
#define ACCELERATOR_REGISTER_TAP_4 (ACCELERATOR_BASE_ADDRESS + 0x2C)
#define ACCELERATOR_REGISTER_TAP_5 (ACCELERATOR_BASE_ADDRESS + 0x30)
#define ACCELERATOR_REGISTER_TAP_6 (ACCELERATOR_BASE_ADDRESS + 0x34)
#define ACCELERATOR_REGISTER_TAP_7 (ACCELERATOR_BASE_ADDRESS + 0x38)
#define ACCELERATOR_REGISTER_TAP_8 (ACCELERATOR_BASE_ADDRESS + 0x3C)
#define ACCELERATOR_REGISTER_OUTPUT_LENGHT (ACCELERATOR_BASE_ADDRESS + 0x40)


#define DEBUG



#define NUMBER_OF_TEST 8

#define NumberOf(a) (sizeof (a) / sizeof *(a))

int sendToAccelerator(int *dataInAddress, int data);
int receiveFromAccelerator(int *dataOutAddress);
int setNtaps(int ntaps);
int configNtapsEn(int param);
int writeTap(int tapNumber, int value);
int readTap(int tapNumber);
int configTapWr(int param);
int configResetFilter(int param);
int setOutputLenght(int value);
int readOutputLenght(void);
int configFIFOen(int param);
int resetFIFO(int param);
int checkFIFOfull(void);
int checkFIFOempty(void);
int configFilter(int *taps, int size );

void impulse_test(int ntaps, int *dataInAddress, int *dataOutAddress, int *validOutAddress, unsigned int benchParam);

/*  Convolve Signal with Filter.

    Signal must contain OutputLength + FilterLength - 1 elements.  Conversely,
    if there are N elements in Signal, OutputLength may be at most
    N+1-FilterLength.
*/
// input =                    {0,0,0,0,1,0,0,0,0,0}
// filter = {5,4,3,2,1} -->   {1,2,3,4,5}
// 0) input|0| = |1,0,0,0,0| 1*5 + 0*4 + 0*3 + 0*2 + 0*1 = 5
// 1) input|1| = |0,0,0,0,0| 0*5 + 0*4 + 0*3 + 0*2 + 0*1 = 0 
//output = {5,0}
static void convolve(
    int *Signal,
    int *Filter, int FilterLength,
    int *Output, int OutputLength)
{
    for (int i = 0; i < OutputLength; ++i)
    {
        long int sum = 0;
        for (int j = 0; j < FilterLength; ++j) {
            // printf("%d, %d --> %d += %d %d\n\r",i,j,sum,Signal[i+j],Filter[FilterLength - 1 - j]);
            sum += Signal[i+j] * Filter[FilterLength - 1 - j];
            // printf("%d\n\r",sum);
        }
        Output[i] = sum;
        // printf("%d\n\r", Output[i]);
    }
}

static void convolve_hw(
    int *Signal,
    int FilterLength,
    int *Output, int OutputLength)
{
    int* registerIn = (int *)(ACCELERATOR_REGISTER_IN);
    int* registerOut = (int *)(ACCELERATOR_REGISTER_OUT);
    int i,j;
    for (i = 0; i < FilterLength+OutputLength; ++i)
    {
        sendToAccelerator(registerIn, Signal[i]);

    }
    while(checkFIFOempty())
   {
     ;
   }
    for (j=0; j < OutputLength; j++ )
     {
        Output[j]=receiveFromAccelerator(registerOut);
     }
}

/*Receive data from the FIFO*/
int receiveFromAccelerator(int *dataOutAddress)
{
  if(checkFIFOempty() == 1)
    {
      // #ifdef DEBUG
      // printf("No data available, NUMBER OF INPUTS %d\n",*(int*)(ACCELERATOR_REGISTER_COUNTER));
      // #endif

      return 0xFFFFFFFF;
    }
  else
    {
      // #ifdef DEBUG
      // printf("Read %d at address %X, NUMBER OF INPUTS %d \n",*dataOutAddress,dataOutAddress,*(int*)(ACCELERATOR_REGISTER_COUNTER));
      // #endif

      return *dataOutAddress;
    }
  
}

/*send data to dataInAddress*/
int sendToAccelerator(int *dataInAddress, int data)
{
  *dataInAddress = data;
  // #ifdef DEBUG
   //printf("Written %d at address %X\n",data,dataInAddress);
  // #endif
  return 0;
}


/*set the number of taps of the filter*/
int setNtaps(int ntaps)
{
  *(int*)(ACCELERATOR_REGISTER_NTAPS) = ntaps;
  return 0;
}


/*set the bit of configuration for the enable of ntaps*/
int configNtapsEn(int param)
{
  if(param == 1)   
    {
      int config = *(int *)(ACCELERATOR_REGISTER_CONFIG);
     // printf("%X\n",config);
     *(int *)(ACCELERATOR_REGISTER_CONFIG) = ( config | 0x1 ) ;
    }
  else 
  if(param == 0)
  {
       *(int *)(ACCELERATOR_REGISTER_CONFIG) = ( *(int *)(ACCELERATOR_REGISTER_CONFIG) & 0xFFFFFFFE ) ;
  }
  return 0;

}


/*set the value to the tap indicated by tapNumber, returns 1 if successful , 0 otherwise */
int writeTap(int tapNumber, int value)
{
  switch (tapNumber)
	{
		case 0:
      {
        *(int *)(ACCELERATOR_REGISTER_TAP_0) = value;        
		    break; 
      } 
	
		case 1:
      {
        *(int *)(ACCELERATOR_REGISTER_TAP_1) = value;        
		    break; 
      } 


		case 2:
      {
        *(int *)(ACCELERATOR_REGISTER_TAP_2) = value;        
		    break; 
      } 


		case 3:
      {
        *(int *)(ACCELERATOR_REGISTER_TAP_3) = value;        
		    break; 
      } 


		case 4:
      {
        *(int *)(ACCELERATOR_REGISTER_TAP_4) = value;        
		    break; 
      } 


		case 5:
      {
        *(int *)(ACCELERATOR_REGISTER_TAP_5) = value;        
		    break; 
      } 

		case 6:
      {
        *(int *)(ACCELERATOR_REGISTER_TAP_6) = value;        
		    break; 
      }       

		case 7:
      {
        *(int *)(ACCELERATOR_REGISTER_TAP_7) = value;        
		    break; 
      } 
       

		default:
      { printf("Not a valid tap\n");
        return 0;
      }
		break;
	}
  return 1;
}


/*read the value of the tap indicated by tapNumber, returns the value of the indicated tap, 0 otherwise*/
int readTap(int tapNumber)
{
  int value;
    switch(tapNumber)
	{
		case 0:
      {
        value = *(int *)(ACCELERATOR_REGISTER_TAP_0);      
		    break; 
      } 
	
		case 1:
      {
        value = *(int *)(ACCELERATOR_REGISTER_TAP_1);      
		    break; 
      } 


		case 2:
      {
        value = *(int *)(ACCELERATOR_REGISTER_TAP_2);      
		    break; 
      } 


		case 3:
      {
        value = *(int *)(ACCELERATOR_REGISTER_TAP_3);      
		    break; 
      } 


		case 4:
      {
        value = *(int *)(ACCELERATOR_REGISTER_TAP_4);      
		    break;  
      } 


		case 5:
      {
        value = *(int *)(ACCELERATOR_REGISTER_TAP_5);      
		    break; 
      } 

		case 6:
      {
        value = *(int *)(ACCELERATOR_REGISTER_TAP_6);      
		    break; 
      }       

		case 7:
      {
        value = *(int *)(ACCELERATOR_REGISTER_TAP_7);      
		    break;  
      } 


		default:
      { printf("Not a valid tap\n");
        return 0;
      }
		break;
	}

  return value;

}

/*set the bit of tap_wr in cfg register*/
int configTapWr(int param)
{
   if(param == 1)   
    {

     *(int *)(ACCELERATOR_REGISTER_CONFIG) = ( *(int *)(ACCELERATOR_REGISTER_CONFIG)| 0x2 ) ;
    }
  else 
  if(param == 0)
  {
       *(int *)(ACCELERATOR_REGISTER_CONFIG) = ( *(int *)(ACCELERATOR_REGISTER_CONFIG) & 0xFFFFFFFD ) ;
  }
  return 0;
}

/*set the bit of reset_filter in cfg register*/
int configResetFilter(int param)
{
  if(param == 1)   
    {

     *(int *)(ACCELERATOR_REGISTER_CONFIG) = ( *(int *)(ACCELERATOR_REGISTER_CONFIG)| 0x4 ) ;
    }
  else 
  if(param == 0)
  {
       *(int *)(ACCELERATOR_REGISTER_CONFIG) = ( *(int *)(ACCELERATOR_REGISTER_CONFIG) & 0xFFFFFFFB ) ;
  }
  return 0;

}

/*set the output lenght in the output_lenght genericfir register*/
int setOutputLenght(int value)
{
  *(int *)(ACCELERATOR_REGISTER_OUTPUT_LENGHT) = value;
  return 0;
}

/*read the output lenght set in the output_lenght genericfir register*/
int readOutputLenght(void)
{
  int value = *(int *)(ACCELERATOR_REGISTER_OUTPUT_LENGHT);
  //printf("%x\n",value);
  return value;
}

/*set the bit of fifo_en in cfg register*/
int configFIFOen(int param)
{
     if(param == 1)   
    {

     *(int *)(ACCELERATOR_REGISTER_CONFIG) = ( *(int *)(ACCELERATOR_REGISTER_CONFIG)| 0x10 ) ;
    }
  else 
  if(param == 0)
  {
       *(int *)(ACCELERATOR_REGISTER_CONFIG) = ( *(int *)(ACCELERATOR_REGISTER_CONFIG) & 0xFFFFFFEF ) ;
  }
  return 0;

}

/*set the bit of fifo_en in cfg register*/
int resetFIFO(int param)
{
       if(param == 1)   
    {

     *(int *)(ACCELERATOR_REGISTER_CONFIG) = ( *(int *)(ACCELERATOR_REGISTER_CONFIG)| 0x8 ) ;
    }
  else 
  if(param == 0)
  {
       *(int *)(ACCELERATOR_REGISTER_CONFIG) = ( *(int *)(ACCELERATOR_REGISTER_CONFIG) & 0xFFFFFFF7 ) ;
  }
  return 0;
}

/*checks if the FIFO is empty, if yes returns 1, 0 otherwise*/
int checkFIFOempty(void)
{
  int value;
  value = *(int *)(ACCELERATOR_REGISTER_CONFIG) & 0x00000020;
  if(value == 0x20) return 1;
  else return 0;
}

/*maps the performance counter according to the eventID*/
void perf_enable_id( int eventid){
  cpu_perf_conf_events(SPR_PCER_EVENT_MASK(eventid));
  cpu_perf_conf(SPR_PCMR_ACTIVE | SPR_PCMR_SATURATE);
};



void impulse_test(int ntaps, int *dataInAddress, int *dataOutAddress, int *validOutAddress, unsigned int benchParam)
{
  int perfResult;
  printf("Starting Test\n");
  perf_reset();
  perf_enable_id(benchParam);
  sendToAccelerator(dataInAddress,1);
  receiveFromAccelerator(dataOutAddress);
  int counter;
  for(int i=0;i<(ntaps*2)-1;i++)
  {
    sendToAccelerator(dataInAddress,0);
    receiveFromAccelerator(dataOutAddress);
  }
  perf_stop();
  perfResult = cpu_perf_get(benchParam);
  printf("Test done.\n Perf #%s: %d.\n\n",SPR_PCER_NAME(benchParam), perfResult);

}

/*sets the filter taps  according to the values contained in taps, in case of too many taps returns 0, 1 otherwise*/
int configFilter(int *taps, int size )
{
 if(size>7)
 return 0;
 for(int i=0; i<size; i++)
  {
    writeTap((7-i),taps[i]); 
  }

 return 1;
}

#define LongEnough  128

int main()
 { 
   int Filter0[] = { 5, 4, 3, 2, 1 };
   //configFilter(Filter0,NumberOf(Filter0));


  //  configFIFOen(1);
  //  resetFIFO(1);
  //  resetFIFO(0);
  //  setNtaps(5);
  //  configNtapsEn(1);
  //  configNtapsEn(0);
  //  writeTap(7,Filter0[0]);
  //  writeTap(6,Filter0[1]);
  //  writeTap(5,Filter0[2]);
  //  writeTap(4,Filter0[3]);
  //  writeTap(3,Filter0[4]);
  //  //writeTap(5,3);
  //  //writeTap(1,2);
  //  //writeTap(0,1);
  //  configTapWr(1);
  //  configTapWr(0);

  //  setOutputLenght(2);
  //  int input[] ={20,0,0,0,0,0,0,0,3};
  //  int  output[2];
  //  int* registerIn = (int *)(ACCELERATOR_REGISTER_IN);
  //  int* registerOut = (int *)(ACCELERATOR_REGISTER_OUT);
  
  //  for(int i=0;i<9;i++)
  //  sendToAccelerator(registerIn,input[i]);
  //  while(checkFIFOempty())
  //  {
  //    ;
  //  }
  

    // output[0] =receiveFromAccelerator(registerOut);
    // output[1] = receiveFromAccelerator(registerOut);
    // //output[0] =receiveFromAccelerator(registerOut);

    // printf("value == %d\n",output[0]);
    // printf("value == %d\n",output[1]);



   unsigned int perfCounterSw;
   unsigned int perfCounterHw;



 
  unsigned int Filter0Length = NumberOf(Filter0);


//  Define a unit impulse positioned so it captures all of the filters.
  unsigned int UnitImpulsePosition = Filter0Length - 1 ;
  int UnitImpulse[LongEnough];
  memset(UnitImpulse, 0, sizeof UnitImpulse);
  UnitImpulse[UnitImpulsePosition] = 1;

  //  Calculate a filter that is Filter0 and Filter1 combined.
  int Output[LongEnough];
  int Output_hw[LongEnough]; 
  memset(Output_hw, 0, sizeof Output_hw);

  //  Set N to number of inputs that must be used.
  unsigned int N = UnitImpulsePosition + 1 + Filter0Length - 1 ;

  //  Subtract to find number of outputs of first convolution, then convolve.
  N -= Filter0Length - 1;
  N = 10;
  printf("N = %d\n",N);

  perf_reset();
  perf_enable_id(SPR_PCER_CYCLES);
  convolve(UnitImpulse,    Filter0, Filter0Length, Output, N);
  perf_stop();
  perfCounterSw = cpu_perf_get(SPR_PCER_CYCLES);

  perf_reset();
  setOutputLenght(N);
  perf_enable_id(SPR_PCER_CYCLES);
  configFIFOen(1);
  resetFIFO(1);
  resetFIFO(0);
   setNtaps(5);
   configNtapsEn(1);
   configNtapsEn(0);
   configFilter(Filter0,NumberOf(Filter0));
  //  writeTap(7,Filter0[0]);
  //  writeTap(6,Filter0[1]);
  //  writeTap(5,Filter0[2]);
  //  writeTap(4,Filter0[3]);
  //  writeTap(3,Filter0[4]);
   //writeTap(5,3);
   //writeTap(1,2);
   //writeTap(0,1);
   configTapWr(1);
   configTapWr(0);
     convolve_hw(UnitImpulse,   Filter0Length, Output_hw, N);
     perf_stop();
     perfCounterHw = cpu_perf_get(SPR_PCER_CYCLES);
    


     //  Remember size of resulting filter.
     unsigned int OutputLength = N;

    //  Display filter.
     for (unsigned int i = 0; i < OutputLength; ++i)
         printf("SwFilter[%d] = %d.\n", i, Output[i]);

     for (unsigned int i = 0; i < OutputLength; ++i)
         printf("HwFilter[%d] = %d.\n", i, Output_hw[i]);

          printf("Perf: %s: SW %d  HW %d\n", SPR_PCER_NAME(SPR_PCER_CYCLES), perfCounterSw, perfCounterHw );
  


  return 0;
}


