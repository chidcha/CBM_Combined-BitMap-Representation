#define _LFS_LARGEFILE          1
#define _LFS64_LARGEFILE        1
#define _LFS64_STDIO                    1
#define _LARGEFILE64_SOURCE     1

#include <stdio.h>
#include <stdlib.h>
#include <string>
#include <cuda.h>
#include <fstream>
#include <iostream>
#include <stdlib.h>
#include <string.h>
#include <time.h>

//SEP 18-19 AUTHOR: CHANTANA CHANTRAPORNCHAI
//3_1 
//3_2
//3_3 NOO
// 3_6 stream with 2 cards
#define IMAGE_FILE_LARGE_ADDRESS_AWARE 0x0020

#define MAX_STREAMS 4
#define MAX_CARDS 2

#define BLOCK_SIZE 1014
#define MAX_THREAD_PER_BLOCK 1014
#define TOTAL_THREADS 1024
long long unsigned total_sub,total_data;
clock_t t_sub1,t_sub2,t_data1,t_data2;

const unsigned long long chunkSize =1 << 30 ;
unsigned long work_per_thread = 100;
#define MAX 100
char *pattern_arr[MAX];
int *count_found[MAX];

unsigned count_f[1];
unsigned *d_count_f;

int total_pattern;
 unsigned total_found=0;
int TOTAL_THREADS_PER_BLOCK ;
 int num_devices=0;
 	unsigned mb=0;        
int Rround=0;
	// max pattern size bit S
__global__ void searchb(char* data, char* pattern, int len_data,int len_substring, unsigned mb, unsigned* pos, unsigned *count_f)
{  

	// int i = threadIdx.x; //for 1 block
	
	//For all blocks
	int j,i =blockIdx.x * blockDim.x + threadIdx.x;
	int tid = threadIdx.x;
	const int numThreads = blockDim.x * gridDim.x;



	for (; i < len_data-mb+1; i+=numThreads  ) {

	    	
	// Detect the first matching character
	if (data[i] == pattern[0]) {
	
		
	// Loop through next keyword character
	for ( j=1; i < len_data && j<len_substring; j++) {
      if (data[i+j] != pattern[j])     break;     
	 }


	 if (j==len_substring) {
     // Store the first matching character to the result list
		 pos[tid]++;

		// atomicAdd(count_f, 1);
		  
	 }

	   
	}//end if matching
	
	}

}//end of Kernel

//
// Read in the given data file and hope it doesn't over the memory limits of the machine or that defined by 'DATA_SIZE'
//

	 FILE* f_b;
	 unsigned long long fileSize = 0;

	  char* data_b;  
	unsigned long long filesize(const char *filename)
	{
	FILE *f = fopen(filename,"rb");  /* open the file in read only */

		if (fseek(f,0,SEEK_END)==0) /* seek was successful */
			fileSize = ftell(f);
		fclose(f);
		return fileSize;
	}


	 int countR=0;

	char* readfile_b() { // read one gig    

	
			
			fread(data_b,sizeof(char),chunkSize,f_b);
	
		
    return data_b;
}

	 unsigned count_total_found(unsigned *arr, int n)
	{
		 int i;
		 unsigned c=0;
//		 printf("size %d \n",n);
		 for (i=0; i < n; i++)  {
			 
			   c += arr[i]; 
		 }
		 return c;
	}


int main(int argc, char** argv)
{
    printf("start\n");
	int cuda_device = 0; // device ID


	unsigned  arr_nb[MAX_CARDS];           // number of ints in the bit data set
	int j;

	int nStreams= MAX_STREAMS;
	 cudaStream_t stream[MAX_CARDS]; 
	cudaError_t result;

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
    	if( argc > 1 )
       		cuda_device = atoi( argv[1] );

	    // check if the command-line chosen device ID is within range, exit if not
	    if( cuda_device >= num_devices )
	    {
	        printf("choose device ID between 0 and %d\n", num_devices-1);
	        return 1;
	    }

    	cudaSetDevice( cuda_device );

		if ( argc < 4 ) {
      		printf("Usage: StringmatchingGPU <device_number> <data_file_b> <string_pattern1-..99>\n");
      		return -1;
    	}
	} // end of safe checks

	//Cuda Device 
	cudaDeviceProp deviceProp;
	cudaGetDeviceProperties(&deviceProp, cuda_device);
	if( (deviceProp.major == 2) && (deviceProp.minor < 2)){ 
		printf("\n%s does not have compute capability 2.2 or later\n",deviceProp.name);}
	int numSMs;
	cudaDeviceGetAttribute(&numSMs, cudaDevAttrMultiProcessorCount, cuda_device);
	printf("num SMs %d\n",numSMs);//print streaming multiprocessors
//--------------------------------------------------------	
  num_devices =2;
  for (int l=0; l < num_devices; l++) {
//    int cset=l*2;
    cudaSetDevice(l);
	nStreams = MAX_STREAMS;
		result = cudaStreamCreate(&stream[l]);
 
  }

  error = cudaGetLastError();
		if ( error ) { 	printf("Error caught: %s\n", cudaGetErrorString( error ));}
		     
		
	//OpenFile
	if ((f_b = fopen(argv[2] , "r")) == NULL ) { printf("Error : read file\n"); return 0; }
	 
 
	long double total_diff2=0.0;	
        long double total_time_data = 0.0, total_time_pat =0.0, total_time_pos=0.0;

 
	
	cudaEventCreate(&start_event);
	cudaEventCreate(&stop_event);

	printf("pattern=");
	// copy str pattern to pattern array
	mb = 0;
	for (j=3; j < argc; j++)
	 {
		  pattern_arr[total_pattern] = (char*)malloc( (strlen(argv[j]) + 1) * sizeof(char) ); 
		 // count_found[total_pattern] = (int *) malloc( 2*sizeof(int));
		  //count_found[total_pattern]=0;
			
		  strcpy(pattern_arr[total_pattern],argv[j]);
		  printf(" %s ",pattern_arr[total_pattern]);
		   mb= (mb > strlen(pattern_arr[total_pattern])? mb : strlen(pattern_arr[total_pattern]));
		  total_pattern++;
		 
	 }
	printf("\n");
	//char* mainString_b;
	char* d_data_b = 0;
	unsigned *pos=0;
	unsigned *d_pos=0;
	 
	//Device's text
//	printf ("pointter size %ld \n",sizeof (unsigned*));
	
	// allocate D memory
	char* d_substr_b = 0;


	// read in the filename and string pattern to be searched
	 int alloc_size =(mb-1+chunkSize)*sizeof(char);
	char *arr_data_b[MAX_CARDS];
	int countc;

	unsigned *arr_pos[MAX_CARDS];
	unsigned *arr_d_pos[MAX_CARDS];
	char *arr_d_data_b[MAX_CARDS];
	char *arr_d_substr_b[MAX_CARDS];

	for (int l =0; l < num_devices; l++) {
//    int cset=l*2;
    cudaSetDevice(l);

	      cudaMallocHost((void**)&arr_data_b[l], alloc_size) ; // host pinned
 
	    if (arr_data_b[l] == NULL) printf("alloc data_b error \n");  
	
	
	}
	 for (int l =0; l < num_devices; l++) {
			 
	     arr_pos[l] = (unsigned *)  calloc (TOTAL_THREADS, sizeof(unsigned));
		  
			if(arr_pos[l] == NULL) {printf("error alloc pos\n"); exit(-1);}
			
	 }


	for (int l =0; l < num_devices; l++) {
//    int cset=l*2;
    cudaSetDevice(l);
	
			cudaMalloc((void**)&arr_d_pos[l],(TOTAL_THREADS)*sizeof(unsigned));//
			cudaMalloc((void**)&d_count_f,(1)*sizeof(unsigned));//

     	 if (arr_d_pos[l] == NULL) {
			 printf("couldn't allocate d_pos\n"); exit(-1); }
		 
          cudaMalloc((void**)&arr_d_data_b[l], (mb-1+chunkSize)*sizeof(char)) ;//
	  
	    if (arr_d_data_b[l] == NULL) {
			printf("couldn't allocate d_data_b\n"); exit(-1);  }
	  
		
	    cudaMalloc((void**)&arr_d_substr_b[l], mb*sizeof(char));
	     if (arr_d_substr_b[l] == NULL) {
			 printf("couldn't allocate d_substr_b\n"); exit(-1);  }
	    
	}
	size_t cur_free, cur_total;

	printf("\n");
	for (int l =0; l < num_devices; l++) {
//    int cset=l*2;
    cudaSetDevice(l);
	
	      cudaMemGetInfo(&cur_free,&cur_total); 

//    	   printf("free %ld KB of total %ld KB\n",cur_free/1024,cur_total/1024);
	}
	 
	 
int num_block;
	while ( !feof (f_b)) {
		num_block=0;
		for (int l =0; l < num_devices; l++) {  // looping read file chunk to devices
		 
		   countc=fread(arr_data_b[l],sizeof(char),chunkSize+mb-1,f_b);
		   if (countc <= 0 ) break;
			  
			arr_nb[l] =   ( unsigned ) countc/sizeof(char);
			if (!feof(f_b)) fseeko(f_b,-((long long)mb-1),SEEK_CUR);
//		  printf("read for card %d size %u \n",l, arr_nb[l]);
		  num_block++;
		}
 

	
	//Find 
		TOTAL_THREADS_PER_BLOCK = MAX_THREAD_PER_BLOCK ;  /**/

		

		//Print Block / Threads



		//H2D 
		t_data1= clock();
	// cudaMemcpy(d_data_b, data_b, nb, cudaMemcpyHostToDevice );//**maybe be Asynccopy

	 unsigned DATA_STEP  =1<<30;

		int sid = 0;
		 

		for (int l =0; l < num_devices; l++) {

//    int cset=l*2;
    cudaSetDevice(l);

			if (l >= num_block)  break; // handle the case when  the numblock read is less than  numdevice
			cudaMemcpyAsync( arr_d_data_b[l], arr_data_b[l],  arr_nb[l]*sizeof(char), cudaMemcpyHostToDevice,stream[l]);
			printf("dev %d ",l);
		}	

	printf("\n");


		for (int l =0; l < num_devices; l++) {

//    int cset=l*2;
    cudaSetDevice(l);
	
		     cudaStreamSynchronize(stream[l]);
		}
		t_data2= clock();
	    long double diff2 = (((long double)t_data2 - (double)t_data1) / CLOCKS_PER_SEC) *1000;
	
	    printf("timeCopyH2D-1 %Lf ms \n",diff2);Rround++;
		total_diff2 += diff2;
                total_time_data += diff2; 
		// using Kernel
		
		for (j=0; j < total_pattern; j++) {
			 	

//		   printf("after mem set pos pattern no. %d\n", j);
			t_data1= clock();
	    
			for (int l =0; l < num_devices; l++) {
//    int cset=l*2;
    cudaSetDevice(l);
			   
			   if (l >= num_block)  break;
			   cudaMemcpy(arr_d_substr_b[l], pattern_arr[j], sizeof(char)*(strlen(pattern_arr[j])), cudaMemcpyHostToDevice) ;
//			    printf("after copy to d_subs dev %d\n",l);
				cudaMemcpy(arr_d_pos[l], arr_pos[l], (TOTAL_THREADS)*sizeof(unsigned), cudaMemcpyHostToDevice) ; 
			}
			
		
			t_data2= clock();
		     diff2 = (((long double)t_data2 - (double)t_data1) / CLOCKS_PER_SEC) *1000;
		        printf("timeCopyH2D-2 %Lf ms \n",diff2);Rround++;
                        total_diff2 += diff2;
			total_time_pat += diff2;
			 cudaEventRecord(start_event, 0);
		
			
	       for (int l =0; l < num_devices; l++) {
			   
//    int cset=l*2;
    cudaSetDevice(l);

//			   printf("Runing in kernel dev %d\n",l);
			   if (l >= num_block)  break;
			searchb <<<32*numSMs,TOTAL_THREADS,0,stream[l] >>>(arr_d_data_b[l], arr_d_substr_b[l],arr_nb[l],strlen(pattern_arr[j]),mb,arr_d_pos[l],&d_count_f[0]);
		   }
			cudaEventRecord(stop_event, 0);
			cudaEventSynchronize( stop_event );
			//Calculate time
			cudaEventElapsedTime( &time_main_b, start_event, stop_event );
		//Getting Error 
		error = cudaGetLastError();
		if ( error ) { 	printf("Error caught: %s\n", cudaGetErrorString( error ));}
		     
		
	    for (int l =0; l < num_devices; l++) {
			  
//    int cset=l*2;
    cudaSetDevice(l);

			t_data1 =clock();
			if (l >= num_block)  break;
			 //cudaMemcpyAsync(arr_pos[l], arr_d_pos[l], (arr_nb[l])*sizeof(bool), cudaMemcpyDeviceToHost,stream[l]) ; // result position
			cudaMemcpy(arr_pos[l], arr_d_pos[l], (TOTAL_THREADS)*sizeof(unsigned), cudaMemcpyDeviceToHost) ; 
			//cudaMemcpy(count_f, d_count_f,   sizeof(unsigned), cudaMemcpyDeviceToHost) ; 
	         error = cudaGetLastError();
			if ( error ) { 	printf("Error caught ===: %s\n", cudaGetErrorString( error ));}
		     
			 t_data2= clock();
		     diff2 = (((long double)t_data2 - (double)t_data1) / CLOCKS_PER_SEC) *1000;
			 printf("\ntimeCopyH2D-3 %Lf ms ",diff2);Rround++;
			 total_diff2 += diff2;
			 total_time_pos +=diff2;
			//Print Time
			printf(" timeMainSearch %lf ms \n", time_main_b);
			total_time_main_b += time_main_b;
			//cudaHostGetDevicePointer((void **)&arr_pos[l], (void *)pos, 0);
			 
			
			// cleanup
		 }
		}
			 
		// stop timer
		
		
		
		//checkGpuMem(chunkSize);

		if (feof(f_b) || countc <=0 )
		 break;

		}//end while main stream
		//Free Substring


		
		printf("\ntimeMainSearch %lf ms ", total_time_main_b);
		printf("time copy H2D %Lf ms: total all = %Lf  ",total_diff2, total_diff2+total_time_main_b);

		for (int l=0; l < num_devices; l++)
		{
			 unsigned   t_f= count_total_found(arr_pos[l],TOTAL_THREADS);
			printf(" cur_found %u  \n", t_f);
			total_found += t_f;
		//printf("count_f %lu \n",count_f[0]);
		}

                printf("\ntimeCopyH2D %Lf ms ",total_diff2);
                printf("timeMainSearch %lf ms ", total_time_main_b);
                printf("totalAll = %Lf ", total_diff2+total_time_main_b);
                printf("Found %d ",total_found);
                printf("Round %d \n", Rround);

printf("\ntotal_time_data %Lf ms total_time_pat %Lf ms " , total_time_data, total_time_pat);
printf(" total_time_pos %Lf ms TotalH2D %Lf ms ", total_time_pos, total_time_data+total_time_pat+total_time_pos);

		
		

		//Free Input
		   
		 
	 
	for (int l =0; l < num_devices; l++) {
		

//    int cset=l*2;
    cudaSetDevice(l);
	
		cudaFree(arr_d_data_b[l]); 
		cudaFree(arr_d_pos[l]); 
		cudaFree(arr_d_substr_b[l]);
		//cudaFree(d_pos);
	}
		cudaEventDestroy( start_event ); 
		cudaEventDestroy( stop_event ); 

			 
	for (int l =0; l < num_devices; l++) {
	 
		free(arr_pos[l]);
		//free(arr_data_b[l]);
		cudaFreeHost(arr_data_b[l]);
		//    cudaFreeHost(arr_pos[l]);
	}
		for (j=0; j < total_pattern; j++) { 
			free(pattern_arr[j]);
		  }
		//Close Input File
		fclose(f_b);
	for (int l =0; l < num_devices; l++) {
//    int cset=l*2;
    cudaSetDevice(l);
		
		//for (int i = 0; i < nStreams; ++i)  {
		 result = cudaStreamDestroy(stream[l]);
 
	//}
	}
	cudaFree(d_count_f);

		printf("\nEnd");
		return 0;

}
