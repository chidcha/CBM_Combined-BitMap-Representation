#define _LFS_LARGEFILE          1
#define _LFS64_LARGEFILE        1
#define _LFS64_STDIO			1
#define _LARGEFILE64_SOURCE    	1

#include <stdio.h>
#include <stdlib.h>
#include <string>
#include <cuda.h>
#include <fstream>
#include <iostream>
#include <stdlib.h>
#include <string.h>
#include <time.h>

///////////////////////////////////////////////////////////////
//set block size
///////////////////////////////////////////////////////////////
#ifdef BLOCK_SIZE32
#define BLOCK_SIZE 32
#elif BLOCK_SIZE64
#define BLOCK_SIZE 64
#elif BLOCK_SIZE128
#define BLOCK_SIZE 128
#elif BLOCK_SIZE256
#define BLOCK_SIZE 256
#elif BLOCK_SIZE512
#define BLOCK_SIZE 512
#elif BLOCK_SIZE512
#define BLOCK_SIZE 512
#elif BLOCK_SIZE1024
#define BLOCK_SIZE 1024
#else
#define BLOCK_SIZE 32
#endif


#define MAX_THREAD_PER_BLOCK 1014
long long unsigned total_sub, total_data;
clock_t t_sub1, t_sub2, t_data1, t_data2;

///////////////////////////////////////////////////////////////
//set chunk size
///////////////////////////////////////////////////////////////
#ifdef CHUNK2G
unsigned long long chunkSize = 0x80000000; //2G
#elif CHUNK3G
unsigned long long chunkSize = 0xc0000000; //3G
#elif CHUNK4G
unsigned long long chunkSize = 0x100000000; //4G
#elif CHUNK5G
unsigned long long chunkSize = 0x140000000; //5G
#elif CHUNK1G
unsigned long long chunkSize = 0x40000000; //1G
#elif CHUNK6G
unsigned long long chunkSize = 0x180000000; //6G
#elif CHUNK1M
unsigned long long chunkSize = 0x100000;//1MB
#elif CHUNK32M
unsigned long long chunkSize = 0x2000000;//32MB
#elif CHUNK256M
unsigned long long chunkSize =0x10000000;//256MB
#elif CHUNK32KB
unsigned long long chunkSize = 0x8000;//32KB
#else
unsigned long long chunkSize =0x8000000;//128MB
#endif


unsigned long work_per_thread = 100;
#define MAX 100
char *pattern_arr[MAX];
int *count_found[MAX];
int total_pattern;
long unsigned total_found;
int TOTAL_THREADS_PER_BLOCK;



int Rround = 0;

__global__ void searchb(char* data, char* pattern, int len_data, int len_substring, bool*pos, unsigned long work_size)//, int* results)
{

	// int i = threadIdx.x; //for 1 block

	//For all blocks
	int j, i = blockIdx.x * blockDim.x + threadIdx.x;
	const int numThreads = blockDim.x * gridDim.x;

	for (; i < len_data; i += numThreads) {

		if (data[i] == pattern[0]) {

			for (j = 1; i + j < len_data && j<len_substring; j++) {
				if (data[i + j] != pattern[j])    { //yes = 0; 
					break; 
				}
			}

			if (j == len_substring) {
				pos[i] = true;
			}
			else  pos[i] = false; //end if marking position


		}//end if matching

	}

}//end of Kernel

//
// Read in the given data file and hope it doesn't over the memory limits of the machine or that defined by 'DATA_SIZE'
//

FILE* f_b = NULL;
FILE* f_t = NULL;
FILE*pFile = NULL;
unsigned long long fileSize = 0;


size_t currByte = 0;


unsigned long long filesize(const char *filename)
{
	FILE *f = fopen(filename, "rb");  /* open the file in read only */
#ifdef __linux__
	if (fseeko(f, 0, SEEK_END) == 0) /* seek was successful */
		fileSize = ftell(f);
	fclose(f);
#elif _WIN32
	if (_fseeki64(f, 0, SEEK_END) == 0) /* seek was successful */
		fileSize = ftell(f);
	fclose(f);

#endif
	printf("fileSize = %llu", fileSize);
	return fileSize;
}


int countR = 0;



long unsigned count_total_found(bool *arr, int n)
{
	int i;
	long unsigned c = 0;
	for (i = 0; i < n; i++)
	{
		if (arr[i]) {
			c++;
			//printf("%d,%u\n",i, c);//position, order
			printf("%d\n", i);//position
		}
	}
	return c;
}


void checkGpuMem(unsigned long long size)
{
	double free_m, total_m, used_m, mem_used, temp1, here1;
	size_t free_t, total_t, temp;
	unsigned int mem, rana, here;

	cudaMemGetInfo(&free_t, &total_t);
	free_m = (unsigned int)free_t / 1048576.0;
	total_m = (unsigned int)total_t / 1048576.0;
	temp = (unsigned int)size / 1048576.0;
	used_m = total_m - free_m;
	here1 = free_t - (unsigned int)size / 1048576.0;
	mem = free_m - temp;
	rana = temp - free_m;
	printf(" checkGPU mem %lu %lf %ud %lf %lf %i %i %lf\n", free_t, free_m, (unsigned)total_t, total_m, used_m, mem, rana, here1);
	//printf ( "mem free %d .... %f MB mem \ntotal %d....%f MB mem \nused %f MB\n",free_t,free_m,total_t,total_m,used_m);
	//printf(" mem free after array %i MB\n",mem);
	//printf(" negative mem free after array %i MB\n",rana);
	//printf(" bytes mem free after array %i MB\n",here1);

}


void printDevProp(cudaDeviceProp devProp)
{
	printf("Major revision number:         %d\n", devProp.major);
	printf("Minor revision number:         %d\n", devProp.minor);
	printf("Name:                          %s\n", devProp.name);
	printf("Total global memory:           %lu\n", devProp.totalGlobalMem);
	printf("Total shared memory per block: %lu\n", devProp.sharedMemPerBlock);
	printf("Total registers per block:     %d\n", devProp.regsPerBlock);
	printf("Warp size:                     %d\n", devProp.warpSize);
	printf("Maximum memory pitch:          %lu\n", devProp.memPitch);
	printf("Maximum threads per block:     %d\n", devProp.maxThreadsPerBlock);
	for (int i = 0; i < 3; ++i)
		printf("Maximum dimension %d of block:  %d\n", i, devProp.maxThreadsDim[i]);
	for (int i = 0; i < 3; ++i)
		printf("Maximum dimension %d of grid:   %d\n", i, devProp.maxGridSize[i]);
	printf("Clock rate:                    %d\n", devProp.clockRate);
	printf("Total constant memory:         %lu\n", devProp.totalConstMem);
	printf("Texture alignment:             %lu\n", devProp.textureAlignment);
	printf("Concurrent copy and execution: %s\n", (devProp.deviceOverlap ? "Yes" : "No"));
	printf("Number of multiprocessors:     %d\n", devProp.multiProcessorCount);
	printf("Kernel execution timeout:      %s\n", (devProp.kernelExecTimeoutEnabled ? "Yes" : "No"));
	return;
}



//void print_shifts(int *iptr, int strlen) {
//	for (unsigned int i = 0; i < strlen; i++) {
//		if (iptr[i] == 1)
//			printf("%d\n", i);
//	}
//}

//char* readfile(const char* filename) {
//	FILE* f;
//	char* data = (char*)malloc(1181741 * sizeof(char));
//
//	if ((f = fopen(filename, "r")) != NULL) {
//		// read in the entire file and store into memory
//		// hopefully it doesn't exhause the entire RAM on
//		// the machine or defy the limits as defined by DATA_SIZE
//		fscanf(f, "%s", data);
//	}
//	fclose(f);
//	return data;
//}

int main(int argc, char** argv)
{
	printf("start\n");
	int cuda_device = 0; // device ID
	long dposSize = 0;
	int mb = 0;           // pattern size bit S
	int nb = 0;           // number of ints in the bit data set
	int j, k;


	//int increasestep=1;

	//start Timer
	cudaError_t error;   // capture returned error code
	cudaEvent_t start_event, stop_event; // data structures to capture events in GPU
	float time_main_b;
	double total_time_main_b = 0.0;

	// Sanity checks
	{
		// check the compute capability of the device A
		int num_devices = 0;

		cudaGetDeviceCount(&num_devices);
		if (0 == num_devices)
		{
			printf("your system does not have a CUDA capable A device\n");
			return 1;
		}
		//if (argc > 1)
			cuda_device = atoi("0");

		// check if the command-line chosen device ID is within range, exit if not
		if (cuda_device >= num_devices)
		{
			printf("choose device ID between 0 and %d\n", num_devices - 1);
			return 1;
		}

		cudaSetDevice(cuda_device);

		//if (argc < 4) {
		//	printf("Usage: StringmatchingGPU <device_number> <data_file_b> <string_pattern1-..99>\n");
		//	return -1;
		//}
	} // end of safe checks

	//Cuda Device 
	cudaDeviceProp deviceProp;
	cudaGetDeviceProperties(&deviceProp, cuda_device);
	//printDevProp(deviceProp);
	if ((deviceProp.major == 2) && (deviceProp.minor < 2)){
		printf("\n%s does not have compute capability 2.2 or later\n", deviceProp.name);
	}
	int numSMs;
	cudaDeviceGetAttribute(&numSMs, cudaDevAttrMultiProcessorCount, cuda_device);
	printf(" num SMs %d\n", numSMs);
	// printf(" %s ", deviceProp.name );
	//  printf(" %d.%d %d ", deviceProp.major, deviceProp.minor, deviceProp.multiProcessorCount);

	//char bitfilename[60];
	char uriIdx[3][2];

	//OpenFile
	
//	if ((f_b = fopen("I:\\Compress\\swdf_2012_11_28_b.txt", "r")) == NULL) { printf("Error : read file b\n"); return 0; }

	if ((f_b = fopen("/data/noo/data/compress/freebase10M_b.txt", "r")) == NULL) { printf("Error : read file b\n"); return 0; }

//"/data/noo/data/compress/freebase10M_b.txt"
//"/data/noo/data/compress/freebase10M_t.txt"


	//filesize(argv[2]);
	//if ((f_t = fopen("I:\\Compress\\swdf_2012_11_28_t.txt", "r")) == NULL) { printf("Error : read file t\n"); return 0; }
	//unsigned long chunkSize = 1073741824;
	unsigned long long currSize = fileSize;
	long double total_diff2 = 0.0;
	long double total_time_data = 0.0, total_time_pat = 0.0, total_time_pos = 0.0;



	while (currSize>chunkSize){
		currSize = (unsigned long)(currSize - chunkSize);
		//printf("\nround |");
		countR++;
	}

	strcpy(uriIdx[0], "11");
	//strcpy(uriIdx[1], "10");
	//strcpy(uriIdx[2], "0");


	//Substring
	char* subString_b = (char*)malloc((strlen(uriIdx[0]) + 1) * sizeof(char));
	strcpy(subString_b, uriIdx[0]);



	cudaEventCreate(&start_event);
	cudaEventCreate(&stop_event);

	// copy str pattern to pattern array
	mb = 0;
	for (j = 0; j < 1; j++)
	{
		pattern_arr[total_pattern] = (char*)malloc((strlen(uriIdx[j]) + 1) * sizeof(char));
		count_found[total_pattern] = (int *)malloc(2 * sizeof(int));
		count_found[total_pattern] = 0;

		strcpy(pattern_arr[total_pattern], uriIdx[j]);
		printf("pattern= %s \n", pattern_arr[total_pattern]);
		mb = (mb > strlen(pattern_arr[total_pattern]) ? mb : strlen(pattern_arr[total_pattern]));

		total_pattern++;
	}

	char* mainString_b;
	char* d_data_b = 0, *data_b;
	bool* pos = 0;
	bool* d_pos = 0;
	//Device's text


	// allocate D memory
	char* d_substr_b = 0;

	// read in the filename and string pattern to be searched

	int alloc_size = (chunkSize + mb - 1)*sizeof(char);
	int countc;
	unsigned int cur_size, my_size;
	char *cur_p, *next_p;

	data_b = (char *)malloc((chunkSize + mb - 1)*sizeof(char));
	pos = (bool *)malloc((chunkSize + mb - 1)*sizeof(bool));
	cudaMalloc((void**)&d_pos, (chunkSize + mb - 1)*sizeof(bool));//
	if (d_pos == NULL)
		printf("couldn't allocate d_pos\n");
	dposSize = dposSize + (long)pos;

	cudaMalloc((void**)&d_data_b, alloc_size);//
	if (d_data_b == NULL)
		printf("couldn't allocate d_data_b\n");
	cudaMalloc((void**)&d_substr_b, (strlen(subString_b))*sizeof(char));

	
	//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	//char* mainString = readfile(argv[2]);
	//int*  d_finalres = 0;
	//int* finalres = (int*)malloc((strlen(mainString))*sizeof(int));
	//
	//cudaMalloc((void**)&d_finalres, (strlen(mainString))*sizeof(int));
	//cudaMemset(d_finalres, 0, sizeof(int)*strlen(mainString));
	
	////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
	size_t cur_free, cur_total;



	printf("\n");

	cudaMemGetInfo(&cur_free, &cur_total);

	printf("%ld KB free of total %ld KB\n", cur_free / 1024, cur_total / 1024);


	while ((countc = fread(data_b, sizeof(char), (chunkSize + mb - 1), f_b))>0){


		mainString_b = data_b;
		nb = (int)countc / sizeof(char);
		nb = nb - (mb - 1);
		printf("size read (byte) %d ", nb);


		TOTAL_THREADS_PER_BLOCK = MAX_THREAD_PER_BLOCK;  /**/


		dim3 threadsPerBlocks(TOTAL_THREADS_PER_BLOCK, 1);
		dim3 numBlocks((int)ceil((double)nb / TOTAL_THREADS_PER_BLOCK), 1);

		work_per_thread = (unsigned long)(ceil((double)BLOCK_SIZE / TOTAL_THREADS_PER_BLOCK));

		//Print Block / Threads

		printf("numblock %d  thread perblock %d work perThread %ld\n", numBlocks.x, threadsPerBlocks.x, work_per_thread);

		if (work_per_thread <= 0) work_per_thread = 1;


		//H2D 
		t_data1 = clock();
		cudaMemcpy(d_data_b, data_b, (nb + (mb - 1)), cudaMemcpyHostToDevice);//**maybe be Asynccopy
		t_data2 = clock();
		long double diff2 = (((double)t_data2 - (double)t_data1) / CLOCKS_PER_SEC) * 1000;

		printf("timeCopyH2D-1 %Lf ms \n", diff2);
		Rround++;
		total_diff2 += diff2;
		total_time_data += diff2;

		// start timer!

		// using Kernel
		for (j = 0; j < total_pattern; j++) {
			//mb = strlen(pattern_arr[j]);


			//pos[0] = -1;
			memset(pos, false, nb);
			cudaMemset(d_pos, false, nb);
			t_data1 = clock();
			cudaMemcpy(d_substr_b, pattern_arr[j], sizeof(char)*(strlen(pattern_arr[j])), cudaMemcpyHostToDevice);

			t_data2 = clock();
			diff2 = (((long double)t_data2 - (double)t_data1) / CLOCKS_PER_SEC) * 1000;
			printf("timeCopyH2D-2 %Lf ms \n", diff2);
			Rround++;
			total_diff2 += diff2;
			total_time_pat += diff2;


			cudaEventRecord(start_event, 0);
			///////////////////////////////////////////////////////////////////////////////////////////////////////
			//Call kernel
			///////////////////////////////////////////////////////////////////////////////////////////////////////
			searchb << <BLOCK_SIZE,1024>> >(d_data_b, d_substr_b, nb, strlen(pattern_arr[j]), d_pos, work_per_thread);
			

			cudaEventRecord(stop_event, 0);
			cudaEventSynchronize(stop_event);
			//Calculate time
			cudaEventElapsedTime(&time_main_b, start_event, stop_event);
			//Getting Error 
			error = cudaGetLastError();
			if (error) { printf("Error caught: %s\n", cudaGetErrorString(error)); }
			t_data1 = clock();
			cudaMemcpy(pos, d_pos, nb, cudaMemcpyDeviceToHost); // result position
			//cudaMemcpy(finalres, d_finalres, (strlen(mainString))*sizeof(int), cudaMemcpyDeviceToHost);
			t_data2 = clock();
			diff2 = (((long double)t_data2 - (double)t_data1) / CLOCKS_PER_SEC) * 1000;
			printf("timeCopyH2D-3 %Lf ms \n", diff2);
			Rround++;
			total_diff2 += diff2;
			total_time_pos += diff2;

			//Print Time
			printf("timeMainSearch %f ms ", time_main_b);
			total_time_main_b += time_main_b;
			int t_f = count_total_found(pos, nb);
			printf(" cur_found %d  \n", t_f);
			total_found += t_f;

			//printf("-------------------------------\n");
			//print_shifts(finalres, strlen(mainString) + 1);
			//printf("-------------------------------\n");
			// cleanup

			// cudaMemcpy(pos, d_pos, sizeof(int)*2, cudaMemcpyDeviceToHost) ;
			//if (pos[0] != -1)
			//count_found[j]++;
		}
		// stop timer



		//		checkGpuMem(chunkSize);

#ifdef __linux__
		if (!feof(f_b)) fseeko(f_b, -((long long)mb - 1), SEEK_CUR);
		else break;
#elif _WIN32
		if (!feof(f_b)) _fseeki64(f_b, -((long long)mb - 1), SEEK_CUR);
		else break;
#endif


	}//end while main stream

	//Free Substring

	cudaFree(d_substr_b);
	free(subString_b);

	printf("\ntimeCopyH2D %Lf ms ", total_diff2);
	printf("timeMainSearch %lf ms ", total_time_main_b);
	printf("totalAll = %Lf ", total_diff2 + total_time_main_b);
	printf("Found %lu ", total_found);
	printf("Round %d \n", Rround);

	printf("\ntotal_time_data %Lf ms total_time_pat %Lf ms ", total_time_data, total_time_pat);
	printf(" total_time_pos %Lf ms TotalH2D %Lf ms ", total_time_pos, total_time_data + total_time_pat + total_time_pos);
	printf("\n dposSize %ld bool %zu\n", dposSize, sizeof(bool));

	//} //end for receive Pattern


	//Free Input

	//free(mainString_b);
	free(data_b);

	cudaFree(d_data_b);
	cudaFree(d_pos);

	cudaEventDestroy(start_event);
	cudaEventDestroy(stop_event);

	//               printf("\npos");
	free(pos);

	for (j = 0; j < total_pattern; j++)
	{
		free(pattern_arr[j]);
		free(count_found[j]);
	}
	//Close Input File
	/*cudaFree(d_finalres);
	free(finalres);*/

	//                printf("\nfclose end");
	fclose(f_b);

	printf("\nEnd");
	return 0;

}
