#define _LFS_LARGEFILE          1
#define _LFS64_LARGEFILE        1
#define _LFS64_STDIO		1
#define _LARGEFILE64_SOURCE    	1
#define _FILE_OFFSET_BITS 64

#include <stdio.h>
#include <stdlib.h>
#include <string>
#include <cuda.h>
#include <fstream>
#include <iostream>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define MAX_STREAMS 4
#define MAX_CARDS 2

#define BLOCK_SIZE 1014
#define MAX_THREAD_PER_BLOCK 1014

long long unsigned total_sub,total_data;
clock_t t_data1,t_data2;


unsigned long work_per_thread = 100;

#define MAX 1000

#define PATTERNSIZE 32
#define MAX_TOTAL_PATTERN 16

__constant__ char cpattern[sizeof(char)*PATTERNSIZE*MAX_TOTAL_PATTERN];


char *pattern_arr[MAX];
long long unsigned *count_found[MAX];

int total_pattern;
long long  unsigned total_found;
int TOTAL_THREADS_PER_BLOCK ;
int num_devices=0;
unsigned mb=0;        
int Rround=0;
int max_str;

#ifdef CHUNK2G
unsigned long long chunkSize =0x80000000; //2G
#elif CHUNK3G
unsigned long long chunkSize =0xc0000000; //3G
#elif CHUNK4G
 unsigned long long chunkSize =0x100000000; //4G
#elif CHUNK5G
unsigned long long chunkSize =0x140000000; //5G
#elif CHUNK1M
unsigned long long chunkSize =0x100000;//1M
#elif CHUNK64K
unsigned long long chunkSize =0x10000;//64KB
#elif CHUNK1G
 unsigned long long chunkSize =0x40000000; //1G
#elif CHUNK6G
unsigned long long chunkSize =0x180000000; //6G
#else
unsigned long long chunkSize =0x79999999; //1.99G default
#endif



FILE* f_b;
  

char* data_b;

texture<unsigned char, 1, cudaReadModeNormalizedFloat> tpattern;

__global__ void searchb_all(char* data,  unsigned long long len_data, unsigned mb, short* pos, int p_count)
{ 
	// use constant memory cpattern
        unsigned long long mycount=0;
        //For all blocks
        unsigned long long j,i =blockIdx.x * blockDim.x + threadIdx.x;

        const int numThreads = blockDim.x * gridDim.x;
		char found,k;
		char *pattern;


   for (; i < len_data-mb+1; i+=numThreads  ) {

        for(k=0; k < p_count; k++) {
	    found=0;
	    pattern = (cpattern+k*PATTERNSIZE);	//constant memory cpattern

           if (data[i] == pattern[0]) {
	      found=1;

            for ( j=1; i+j < len_data && pattern[j] != '\0' && j<PATTERNSIZE; j++) {
             if (data[i+j] != pattern[j])     {found=0; break;}
            }


             if (found) {
                 pos[i] += 1; 
                 mycount++;
             }

          }//end if matching
       } // end for p_count

   }
}//end of Kernel


__global__ void searchb_all_shared(char* data, char* allpattern, unsigned long long len_data, unsigned mb, short* pos, int p_count)
{


        unsigned long long mycount=0;

        unsigned long long j,i =blockIdx.x * blockDim.x + threadIdx.x;

        const int numThreads = blockDim.x * gridDim.x;
        char found,k;
        char *pattern=allpattern;
	__shared__ char allpattern_s [MAX_TOTAL_PATTERN*PATTERNSIZE];

	if (threadIdx.x < MAX_TOTAL_PATTERN*PATTERNSIZE)
         	allpattern_s[threadIdx.x]= allpattern[threadIdx.x];

	 __syncthreads();

    
     for (; i < len_data-mb+1; i+=numThreads  ) {

        for(k=0; k < p_count; k++) {
            found=0;
            pattern = (allpattern_s+k*PATTERNSIZE);

           if (data[i] == pattern[0]) {
              found=1;

            for ( j=1; i+j < len_data && pattern[j] != '\0' && j<PATTERNSIZE; j++) {
             if (data[i+j] != pattern[j])     {found=0; break;}
            }


             if (found) {
                 pos[i] += 1;
                 mycount++;
             }


          }//end if matching
       } // end for p_count

   }
}//end of Kernel

 

__global__ void searchb_all_texture(char* data,   unsigned long long len_data, unsigned mb, short* pos, int p_count)
{


        unsigned long long mycount=0;
        //For all blocks
        unsigned long long j,i =blockIdx.x * blockDim.x + threadIdx.x;
        int p;
        const int numThreads = blockDim.x * gridDim.x;
        char found,k;
        char *pattern;
	__shared__ char allpattern_s [MAX_TOTAL_PATTERN*PATTERNSIZE];
		char c;

	if (i< MAX_TOTAL_PATTERN*PATTERNSIZE) //copy pattern from texture to shared
      { 	
	p=i; c= allpattern_s[i]=  tex1Dfetch(tpattern, p); 
      	
      }

	 __syncthreads();

         
      for (; i < len_data-mb+1; i+=numThreads  ) {

        for(p=0,k=0; k < p_count; k++) {
            found=0;
            p += k*PATTERNSIZE; 

            pattern = (allpattern_s+k*PATTERNSIZE);
            c=*pattern;

        // Detect the first matching character
           if (data[i] == c) {

              found=1;

        // Loop through next keyword character
              for ( j=1; i+j < len_data && c != '\0' && j<PATTERNSIZE; j++) {
       	
                c=pattern[j];	
             if (data[i+j] != c)     {found=0; break;}
            }


             if (found) {
     // Store the first matching character to the result list

                 pos[i] += 1;
                 mycount++;
             }

          }//end if matching
       } // end for p_count

   }
}//end of Kernel

 


unsigned long long count_total_found(short *arr,  unsigned long long   n)
	{
		 unsigned long long i;
		 unsigned long long c=0;
		 printf(" size %lld ",n);
		 for (i=0; i < n; i++)  {
			 //printf("i%ld arr[i] %d\n", i, arr[i]);  
			 if (arr[i] >0 ) { 
 			    c += (unsigned long long) arr[i]; //("here:");
			 }
		 }
		 return c;
}

 
int main(int argc, char** argv)
{
    printf("Running with chunksize %ld \n",chunkSize);
	int cuda_device = 0; // device ID


	unsigned long long arr_nb[MAX_CARDS];           // number of ints in the bit data set
	int j;

	int nStreams= MAX_STREAMS;
	cudaStream_t stream[MAX_CARDS]; 
	 

	//start Timer
	cudaError_t error;   // capture returned error code
    cudaEvent_t start_event, stop_event; // data structures to capture events in GPU
     float time_main_b, total_time_main_b=0.0;
	
	// Sanity checks
	{
	    // check the compute capability of the device A

		cudaGetDeviceCount(&num_devices) ;
	    if(0==num_devices)
	    {
	        printf("your system does not have a CUDA capable A device\n");
	        return 1;
	    }
    	 
	    // check if the command-line chosen device ID is within range, exit if not
	    

    	cudaSetDevice( cuda_device );

		if ( argc < 3 ) {
      		printf("Usage: %s  <data_file_b> <string_substring1-..99>\n",argv[0]);
      		return -1;
    	}
	} // end of safe checks

	//Cuda Device  information

	cudaDeviceProp deviceProp;
	cudaGetDeviceProperties(&deviceProp, cuda_device);
	printDevProp(deviceProp);
	if( (deviceProp.major == 2) && (deviceProp.minor < 2)){ 
		printf("\ndevice %s does not have compute capability 2.2 or later\n",deviceProp.name);}
	int numSMs;
	cudaDeviceGetAttribute(&numSMs, cudaDevAttrMultiProcessorCount, cuda_device);
	printf("***num SMs %d\n",numSMs);//print streaming multiprocessors
	

	//create stream for each device
  for (int l=0; l < num_devices; l++) {
    cudaSetDevice(l);
	nStreams = MAX_STREAMS;
	error = cudaStreamCreate(&stream[l]);
 
  }

  	error = cudaGetLastError();
	if ( error ) { 	
		printf("Error caught-1: %s\n", cudaGetErrorString( error ));
	}
		     
		
	//Open data File
	if ((f_b = fopen(argv[1] , "r")) == NULL ) { 
		printf("Error : read file %s\n",argv[1]); return 0; }
	 
 
	long double total_diff2=0.0;	
    long double total_time_data = 0.0, total_time_pat =0.0, total_time_pos=0.0;
 
   
	
	cudaEventCreate(&start_event);
	cudaEventCreate(&stop_event);

	printf("texture memory substring, chunksize %lld",chunkSize);
	// copy input substring to host substring array called pattern

	mb = 0;
 
 char *pattern= (char *) malloc(sizeof(char)*PATTERNSIZE*MAX_TOTAL_PATTERN);
	if (pattern == NULL) 
	    printf("error alloc whole patterns\n");
	    memset(pattern,0,sizeof(char)*PATTERNSIZE*MAX_TOTAL_PATTERN); 
        pattern_arr[0] =  pattern;
	for (j=2; j < argc; j++)
	 {
		   
		  pattern_arr[total_pattern] = pattern+(PATTERNSIZE*total_pattern);
		  memcpy(pattern_arr[total_pattern], argv[j], sizeof(char)*(strlen(argv[j])+1));
		  printf(" %s ",pattern_arr[total_pattern]);
		   mb= (mb > strlen(pattern_arr[total_pattern])? mb : strlen(pattern_arr[total_pattern]));
		  total_pattern++; 
		 
	 }
 	max_str = mb; // keep max string length
	printf("\n total_pattern =%d \n", total_pattern);

	
	//Device's text
	//allocate Device memory
	 
	// read in the filename and string pattern to be searched
	
	unsigned long long  alloc_size =(mb-1+chunkSize)*sizeof(char);
	char *arr_data_b[MAX_CARDS];
	unsigned long long  countc;

	short *arr_pos[MAX_CARDS];
	short *arr_d_pos[MAX_CARDS];
	char *arr_d_data_b[MAX_CARDS];
	char *arr_d_substr_b[MAX_CARDS];

	for (int l =0; l < num_devices; l++) {
	cudaSetDevice(l);
	      cudaMallocHost((void**)&arr_data_b[l], alloc_size) ; // host pinned
 
	    if (arr_data_b[l] == NULL) printf("alloc data_b error \n");  
	
	
	}
	 for (int l =0; l < num_devices; l++) {
			cudaSetDevice(l);
			arr_pos[l] = (short *) malloc (((mb-1)+chunkSize)*sizeof(short));
		  
			if(arr_pos[l] == NULL) {printf("error alloc pos\n"); exit(-1);}
			
	 }


	for (int l =0; l < num_devices; l++) {
			cudaSetDevice(l);
	
	        cudaMalloc((void**)&arr_d_pos[l],(mb-1+chunkSize)*sizeof(short));//

     	    if (arr_d_pos[l] == NULL)
	    	  printf("couldn't allocate d_pos device %d\n",l);
		 
	     cudaMalloc((void**)&arr_d_data_b[l], alloc_size) ;//
	  
	    if (arr_d_data_b[l] == NULL)
		   printf("couldn't allocate d_data_b device %ld\n",l);
	      
	      // ** we use these code if we copy copy substring to device global mem
	       cudaMalloc((void**)&arr_d_substr_b[l], sizeof(char)*PATTERNSIZE*MAX_TOTAL_PATTERN);
			//arr_d_substr_b[l] = &cpattern[l][0];
            if (arr_d_substr_b[l] == NULL)
                printf("couldn't allocate d__substr_b device %ld\n",l);

	      error = cudaMemset(arr_d_substr_b[l],0,sizeof(char)*PATTERNSIZE*MAX_TOTAL_PATTERN);
          if ( error ) {  printf("Error caught-cudaMemset d_substr_b: %s %d\n", cudaGetErrorString( error ),error);}  
		//** 

		for (j=0; j < total_pattern; j++)
	           printf("copy arr_d_sub %s \n",pattern_arr[j]);
	    error= cudaMemcpy(arr_d_substr_b[l],pattern_arr[0],PATTERNSIZE*MAX_TOTAL_PATTERN*sizeof(char),cudaMemcpyHostToDevice);

         if ( error ) {  printf("Error caught-cudaMemcpyToSymbol cpattern: %s %d device %d\n", cudaGetErrorString( error ),error,l);}  

	}





	size_t cur_free, cur_total;

	printf("end memcpy arr_d_substr\n");
	for (int l =0; l < num_devices; l++) {
			cudaSetDevice(l);
	
	      cudaMemGetInfo(&cur_free,&cur_total); 

    	   printf("device %d: free %ld KB of total %ld KB\n",l,cur_free/1024,cur_total/1024);
	}
	 
	 
	int num_block;
	while ( !feof (f_b)) {
		num_block=0;
		for (int l =0; l < num_devices; l++) {  // looping read file chunk to devices
		  
		   countc=fread(arr_data_b[l],sizeof(char),chunkSize+mb-1,f_b);
		   if (countc <= 0 ) break;
			  
			arr_nb[l] =   ( unsigned long long ) (countc/sizeof(char));
			if (!feof(f_b)) fseeko(f_b,-((unsigned long long)mb-1),SEEK_CUR);
		  printf("read for card %d size %u \n",l, arr_nb[l]);
		  num_block++;
		}
 

	 
	   
	
	//Find 
		TOTAL_THREADS_PER_BLOCK = MAX_THREAD_PER_BLOCK ;  /**/
		
	 

		//H2D copy all data_b to all device
		t_data1= clock();

		for (int l =0; l < num_devices; l++) {
			cudaSetDevice(l);
			if (l >= num_block)  break; // handle the case when  the numblock read is less than  numdevice
			cudaMemcpyAsync( arr_d_data_b[l], arr_data_b[l],  arr_nb[l]*sizeof(char), cudaMemcpyHostToDevice,stream[l]);
			printf("copy up data_b device %d\n",l);
		}	

		for (int l =0; l < num_devices; l++) {
		     cudaSetDevice(l);
		     cudaStreamSynchronize(stream[l]);
		}
		t_data2= clock();
	    long double diff2 = (((long double)t_data2 - (double)t_data1) / CLOCKS_PER_SEC) *1000;
	
	    printf("\ntimeCopyH2D-1 %Lf ms ",diff2);
            Rround++;
		total_diff2 += diff2;total_time_data += diff2;

		// clear device memory for results pos
	 
			 	
		for (int l =0; l < num_devices; l++) {
			   cudaSetDevice(l);
			   memset(arr_pos[l],(short) 0,arr_nb[l]*sizeof(short));  
			   cudaMemset(arr_d_pos[l],(short)0,sizeof(short)*arr_nb[l]);
		}

         error = cudaGetLastError();
         if ( error ) {  printf("Error caught-2- memset d_pos: %s\n", cudaGetErrorString( error ));}
	     printf("after mem set pos pattern . \n" );
			 
		// stop timer
		
		
	    cudaEventRecord(start_event, 0);


        for (int l =0; l < num_devices; l++) {
             cudaSetDevice(l);
             printf("RunK>Dev %d\n ",l);
             if (l >= num_block)  break;

	  		error =cudaBindTexture(0, tpattern, arr_d_substr_b[l], PATTERNSIZE*MAX_TOTAL_PATTERN*sizeof(char));
			if ( error ) {  printf("Error caught-1.1: %s\n", cudaGetErrorString( error ));}

            searchb_all_texture<<<16*numSMs,128,0,stream[l] >>>(arr_d_data_b[l],arr_nb[l],mb,arr_d_pos[l],total_pattern);
		 
            error = cudaGetLastError();
            if ( error ) {  printf("Error caught-1: %s\n", cudaGetErrorString( error ));}
            cudaUnbindTexture(tpattern);
         }	
		cudaEventRecord(stop_event, 0);
        cudaEventSynchronize( stop_event );
        //Calculate time
        cudaEventElapsedTime( &time_main_b, start_event, stop_event );
	    
        error = cudaGetLastError();
         if ( error ) {  printf("Error caught-1: %s\n", cudaGetErrorString( error ));}

		// copy results back from pos
            for (int l =0; l < num_devices; l++) {
	             cudaSetDevice(l);
	             t_data1 =clock();
	             if (l >= num_block)  break;
	             cudaMemcpy(arr_pos[l], arr_d_pos[l], (arr_nb[l])*sizeof(short), cudaMemcpyDeviceToHost) ;
	             error = cudaGetLastError();
	             if ( error ) {  printf("Error caught-2: %s\n", cudaGetErrorString( error ));}

	              t_data2= clock();
	              diff2 = (((long double)t_data2 - (double)t_data1) / CLOCKS_PER_SEC) *1000;
	             printf("timeCopyD2H-3 %Lf ms ",diff2);
	             Rround++;
	             total_diff2 += diff2;
	             total_time_pos += diff2;

                //Print Time
                printf(" timeMainSearch %lf ms ", time_main_b);
                total_time_main_b += time_main_b;

                 unsigned long long  t_f= count_total_found(arr_pos[l],arr_nb[l]-mb+1);
                 printf ("nb %llu : \n ",arr_nb[l]);
                 
                printf("current_found %llu  \n", t_f);
                total_found += t_f;
                
             }

		if (feof(f_b) || countc <=0 )
		 break;
	    

		}//end while main eof
		 

		
        printf("\ntimeCopyH2D %Lf ms ",total_diff2);
		printf("time main search %lf ms ", total_time_main_b);
        printf("totalAll = %Lf ", total_diff2+total_time_main_b);
		printf("Found %lu ",total_found);
        printf("Round %d \n", Rround);

		printf("\ntotal_time_data %Lf ms total_time_pat %Lf ms " , total_time_data, total_time_pat);
        printf(" total_time_pos %Lf ms TotalH2D %Lf ms ", total_time_pos, total_time_data+total_time_pat+total_time_pos);

		

		//Free Input
		 
	for (int l =0; l < num_devices; l++) {
		cudaSetDevice(l);
		
		cudaFree(arr_d_data_b[l]); 
		cudaFree(arr_d_pos[l]); 
		cudaFree(arr_d_substr_b[l]);  
	 
	}
	cudaEventDestroy( start_event ); 
	cudaEventDestroy( stop_event ); 

			 
	for (int l =0; l < num_devices; l++) {
		free(arr_pos[l]);
		cudaFreeHost(arr_data_b[l]);
	}
 
	free(pattern);

		//Close Input File
	fclose(f_b);
	for (int l =0; l < num_devices; l++) {
		cudaSetDevice(l);
	 	error = cudaStreamDestroy(stream[l]);
 
	}
	printf("\nEnd");
	return 0;

}//**********************************************************************************