#include <iostream>
#include <stdio.h>
#include <cuda.h>

#define max_N 100000
#define max_P 30
#define BLOCKSIZE 1024

using namespace std;

//*******************************************

__global__ void totalRequest(int max_fac, int N,int R, int *d_reqcen, int *d_reqfac, int *d_reqstart, int *d_reqslots, int* d_succesreqs, int* d_slots, int* d_success, int* d_failure)
{
    bool flag = true;
    int i, j, k = 0;
    int id = threadIdx.x + blockIdx.x * blockDim.x;
    if(id < max_fac)
    {
        k = 0;
        while(k < R ) 
        {
            int fac_num = d_reqcen[k] * 30 + d_reqfac[k];
            flag = true;
            int picked_slot = d_reqstart[k] + d_reqslots[k];
            if(fac_num == id)
            {
                //Checking, if the requested slot are in the range
                if(picked_slot <= 25)
                {
                    //i is 'requested slots' in the given facility (fac_num).
                    i = d_reqstart[k];
                    while( i < picked_slot )
                    {
                        int aval_cap = d_reqcen[k]*30*24 + d_reqfac[k]*24 + i-1;
                        //Checking , if the requested slot for the facility has the capacity greater than 0.
                        if(d_slots[aval_cap] >= 1)
                        {
                            atomicSub(&d_slots[aval_cap], 1);
                        }
                        else
                        {
                            //when the available capacity in the facility is less than 0.
                            j = d_reqstart[k];
                            flag = false;
                            while(j < i)
                            {
                                aval_cap = d_reqcen[k]*30*24 + d_reqfac[k]*24 + j-1;
                                atomicAdd(&d_slots[aval_cap],1);
                                j++;
                            }
                            break;
                        }
                        i++;  
                    }
                }
                else
                {
                    flag = false;
                }

    
                if (flag == true) 
                {
                    //center-wise, request success incremented.
                    atomicAdd(&d_succesreqs[d_reqcen[k]], 1);
                    //total request success incremented.
                    atomicAdd(&d_success[0], 1);
                }     
                else 
                {
                    //total request failure incremented.
                    atomicAdd(&d_failure[0], 1);
                }
            }
            k++;
        }  
    }
}


//***********************************************


int main(int argc,char **argv)
{
	// variable declarations...
    int N,*centre,*facility,*capacity,*fac_ids, *succ_reqs, *tot_reqs;


    FILE *inputfilepointer;
    
    //File Opening for read
    char *inputfilename = argv[1];
    inputfilepointer    = fopen( inputfilename , "r");

    if ( inputfilepointer == NULL )  {
        printf( "input.txt file failed to open." );
        return 0; 
    }

    fscanf( inputfilepointer, "%d", &N ); // N is number of centres
	int *offset = (int *) malloc ( (N) * sizeof (int) );
    // Allocate memory on cpu
    centre=(int*)malloc(N * sizeof (int));  // Computer  centre numbers
    facility=(int*)malloc(N * sizeof (int));  // Number of facilities in each computer centre
    fac_ids=(int*)malloc(max_P * N  * sizeof (int));  // Facility room numbers of each computer centre
    capacity=(int*)malloc(max_P * N *  sizeof (int));  // stores capacities of each facility for every computer centre 

    int success=0;  // total successful requests
    int fail = 0;   // total failed requests
    tot_reqs = (int *)malloc(N*sizeof(int));   // total requests for each centre
    succ_reqs = (int *)malloc(N*sizeof(int)); // total successful requests for each centre

    // Input the computer centres data
    int k1=0 , k2 = 0, k3=0, *slots;
    slots=(int*)malloc(max_P * N * 24 * sizeof (int));
    for(int i=0;i<N;i++)
    {
      fscanf( inputfilepointer, "%d", &centre[i] );
      fscanf( inputfilepointer, "%d", &facility[i] );
      k3 = 0;
      offset[i]=k1;
      for(int j=0;j<facility[i];j++)
      {
        fscanf( inputfilepointer, "%d", &fac_ids[k1] );
        k1++;
      }
      for(int j=0;j<facility[i];j++)
      {
        fscanf( inputfilepointer, "%d", &capacity[k2]);
        for(int k4=0;k4<24;k4++){
            slots[centre[i]*30*24 + k3]=capacity[k2];
            k3++;
        }
        k2++; 
        
      }
    }

    // variable declarations
    int *req_id, *req_cen, *req_fac, *req_start, *req_slots;   // Number of slots requested for every request
    
    // Allocate memory on CPU 
	int R;
	fscanf( inputfilepointer, "%d", &R); // Total requests
    req_id = (int *) malloc ( (R) * sizeof (int) );  // Request ids
    req_cen = (int *) malloc ( (R) * sizeof (int) );  // Requested computer centre
    req_fac = (int *) malloc ( (R) * sizeof (int) );  // Requested facility
    req_start = (int *) malloc ( (R) * sizeof (int) );  // Start slot of every request
    req_slots = (int *) malloc ( (R) * sizeof (int) );   // Number of slots requested for every request
    
    // Input the user request data
    for(int j = 0; j < R; j++)
    {
       fscanf( inputfilepointer, "%d", &req_id[j]);
       fscanf( inputfilepointer, "%d", &req_cen[j]);
       fscanf( inputfilepointer, "%d", &req_fac[j]);
       fscanf( inputfilepointer, "%d", &req_start[j]);
       fscanf( inputfilepointer, "%d", &req_slots[j]);
       tot_reqs[req_cen[j]]+=1;  
    }

	int *d_center, *d_facility, *d_facids , *d_capacity , *d_offset , *d_reqid, *d_reqcen, *d_reqfac, *d_reqstart, *d_reqslots, *d_slots, *d_totalreqs, *d_succesreqs,*d_success,*d_failure;
    cudaMalloc(&d_succesreqs, (N) * sizeof(int));
    cudaMalloc(&d_success,sizeof(int));
    cudaMalloc(&d_totalreqs, (N) * sizeof(int));
    cudaMalloc(&d_failure,  sizeof(int));
    cudaMalloc(&d_succesreqs, (N) * sizeof(int));
	cudaMalloc(&d_facids, (max_P*N) * sizeof(int));
	cudaMalloc(&d_capacity, (max_P*N) * sizeof(int));
	cudaMalloc(&d_offset, (N) * sizeof(int));
	cudaMalloc(&d_reqid, (R) * sizeof(int));	
    cudaMalloc(&d_reqcen, (R) * sizeof(int));
	cudaMalloc(&d_reqfac, (R) * sizeof(int));
	cudaMalloc(&d_reqstart, (R) * sizeof(int));
    cudaMalloc(&d_reqslots, (R) * sizeof(int));
	cudaMalloc(&d_slots, (max_P*N*24) * sizeof(int));
    cudaMalloc(&d_center, (N) * sizeof(int));
	cudaMalloc(&d_facility, (N) * sizeof(int));

    // Copy memory from host to device
	cudaMemcpy(d_reqid, req_id, R * sizeof(int), cudaMemcpyHostToDevice);
	cudaMemcpy(d_reqcen, req_cen, R * sizeof(int), cudaMemcpyHostToDevice);
	cudaMemcpy(d_capacity, capacity, max_P * N * sizeof(int), cudaMemcpyHostToDevice);
	cudaMemcpy(d_offset, offset,  N * sizeof(int), cudaMemcpyHostToDevice);
	cudaMemcpy(d_reqfac, req_fac, R * sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(d_slots, slots, N*max_P*24 * sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(d_reqslots, req_slots, R * sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(d_success, &success, sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(d_failure, &fail,sizeof(int), cudaMemcpyHostToDevice); 
    cudaMemcpy(d_reqstart, req_start, R * sizeof(int), cudaMemcpyHostToDevice);
	cudaMemcpy(d_succesreqs, succ_reqs, N * sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(d_center, centre, N * sizeof(int), cudaMemcpyHostToDevice);
	cudaMemcpy(d_facility, facility, N * sizeof(int), cudaMemcpyHostToDevice);
	cudaMemcpy(d_facids, fac_ids, max_P * N * sizeof(int), cudaMemcpyHostToDevice);
    cudaMemcpy(d_totalreqs, tot_reqs, N * sizeof(int), cudaMemcpyHostToDevice);

    //*********************************
    // Call the kernels here
    
    int max_fac = max_P * N;
    dim3 grid(ceil(float(N*max_P)/1024));
    dim3 block(1024);

    totalRequest<<<grid, block>>>(max_fac, N, R, d_reqcen, d_reqfac, d_reqstart, d_reqslots, d_succesreqs, d_slots, d_success, d_failure);
    cudaMemcpy(&fail, d_failure, sizeof(int), cudaMemcpyDeviceToHost);
    cudaMemcpy(&success, d_success, sizeof(int), cudaMemcpyDeviceToHost);
    cudaDeviceSynchronize();  
    
    //********************************

    // Output
    char *outputfilename = argv[2]; 
    FILE *outputfilepointer;
    outputfilepointer = fopen(outputfilename,"w");
    cudaMemcpy(succ_reqs,d_succesreqs, N * sizeof(int), cudaMemcpyDeviceToHost);
    fprintf( outputfilepointer, "%d %d\n", success, fail);
    for(int j = 0; j < N; j++)
    {
      fprintf( outputfilepointer, "%d %d\n", succ_reqs[j], tot_reqs[j]-succ_reqs[j]);
    }
    fclose( inputfilepointer );
    fclose( outputfilepointer );
    cudaDeviceSynchronize();
	return 0;
}