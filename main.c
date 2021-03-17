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

#define DEBUG



#define NUMBER_OF_TEST 8

#define NumberOf(a) (sizeof (a) / sizeof *(a))

int sendToAccelerator(int *dataInAddress, int data);
int receiveFromAccelerator(int *dataOutAddress, int *validOutAddress);
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
    int *Filter, int FilterLength,
    int *Output, int OutputLength)
{
    int* registerIn = (int *)(ACCELERATOR_REGISTER_IN);
    int* registerOut = (int *)(ACCELERATOR_REGISTER_OUT);
    int i;
    for (i = 0; i < FilterLength+OutputLength; ++i)
    {
        sendToAccelerator(registerIn, Signal[i]);
        if(i >= 9) 
          Output[i-9] = receiveFromAccelerator(registerOut, (int*)(ACCELERATOR_REGISTER_VALID_OUT));     
    }
    i++;
    while (i < FilterLength+2*(OutputLength)) {
      sendToAccelerator(registerIn, 0xFF);
      Output[i-10] = receiveFromAccelerator(registerOut, (int*)(ACCELERATOR_REGISTER_VALID_OUT));     
      i++;
    }  
}


int receiveFromAccelerator(int *dataOutAddress, int *validOutAddress)
{
  if(*validOutAddress != 1)
    {
      // #ifdef DEBUG
      // printf("No data available, NUMBER OF INPUTS %d\n",*(int*)(ACCELERATOR_REGISTER_COUNTER));
      // #endif

      return 0;
    }
  else
    {
      // #ifdef DEBUG
      // printf("Read %d at address %X, NUMBER OF INPUTS %d \n",*dataOutAddress,dataOutAddress,*(int*)(ACCELERATOR_REGISTER_COUNTER));
      // #endif

      return *dataOutAddress;
    }
  
}

int sendToAccelerator(int *dataInAddress, int data)
{
  *dataInAddress = data;
  // #ifdef DEBUG
   //printf("Written %d at address %X\n",data,dataInAddress);
  // #endif
  return 0;
}

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
  receiveFromAccelerator(dataOutAddress,validOutAddress);
  int counter;
  for(int i=0;i<(ntaps*2)-1;i++)
  {
    sendToAccelerator(dataInAddress,0);
    receiveFromAccelerator(dataOutAddress,validOutAddress);
  }
  perf_stop();
  perfResult = cpu_perf_get(benchParam);
  printf("Test done.\n Perf #%s: %d.\n\n",SPR_PCER_NAME(benchParam), perfResult);

}

#define LongEnough  128

int main()
{ 
  unsigned int perfCounterSw;
  unsigned int perfCounterHw;

  int* registerIn = (int *)(ACCELERATOR_REGISTER_IN);

   //sendToAccelerator(registerIn,0xdeadbeef);

     int Filter0[] = { 5, 4, 3, 2, 1 };
 
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
     //N -= Filter0Length - 1;
      N = 10;
     printf("N = %d\n",N);

     perf_reset();
     perf_enable_id(SPR_PCER_CYCLES);
     convolve(UnitImpulse,    Filter0, Filter0Length, Output, N);
     perf_stop();
     perfCounterSw = cpu_perf_get(SPR_PCER_CYCLES);

     perf_reset();
     perf_enable_id(SPR_PCER_CYCLES);
     convolve_hw(UnitImpulse,    Filter0, Filter0Length, Output_hw, N);
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


