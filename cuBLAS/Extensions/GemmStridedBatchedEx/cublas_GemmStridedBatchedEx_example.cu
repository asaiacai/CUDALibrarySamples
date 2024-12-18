/*
 * Copyright 2020 NVIDIA Corporation.  All rights reserved.
 *
 * NOTICE TO LICENSEE:
 *
 * This source code and/or documentation ("Licensed Deliverables") are
 * subject to NVIDIA intellectual property rights under U.S. and
 * international Copyright laws.
 *
 * These Licensed Deliverables contained herein is PROPRIETARY and
 * CONFIDENTIAL to NVIDIA and is being provided under the terms and
 * conditions of a form of NVIDIA software license agreement by and
 * between NVIDIA and Licensee ("License Agreement") or electronically
 * accepted by Licensee.  Notwithstanding any terms or conditions to
 * the contrary in the License Agreement, reproduction or disclosure
 * of the Licensed Deliverables to any third party without the express
 * written consent of NVIDIA is prohibited.
 *
 * NOTWITHSTANDING ANY TERMS OR CONDITIONS TO THE CONTRARY IN THE
 * LICENSE AGREEMENT, NVIDIA MAKES NO REPRESENTATION ABOUT THE
 * SUITABILITY OF THESE LICENSED DELIVERABLES FOR ANY PURPOSE.  IT IS
 * PROVIDED "AS IS" WITHOUT EXPRESS OR IMPLIED WARRANTY OF ANY KIND.
 * NVIDIA DISCLAIMS ALL WARRANTIES WITH REGARD TO THESE LICENSED
 * DELIVERABLES, INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY,
 * NONINFRINGEMENT, AND FITNESS FOR A PARTICULAR PURPOSE.
 * NOTWITHSTANDING ANY TERMS OR CONDITIONS TO THE CONTRARY IN THE
 * LICENSE AGREEMENT, IN NO EVENT SHALL NVIDIA BE LIABLE FOR ANY
 * SPECIAL, INDIRECT, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, OR ANY
 * DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS,
 * WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS
 * ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE
 * OF THESE LICENSED DELIVERABLES.
 *
 * U.S. Government End Users.  These Licensed Deliverables are a
 * "commercial item" as that term is defined at 48 C.F.R. 2.101 (OCT
 * 1995), consisting of "commercial computer software" and "commercial
 * computer software documentation" as such terms are used in 48
 * C.F.R. 12.212 (SEPT 1995) and is provided to the U.S. Government
 * only as a commercial end item.  Consistent with 48 C.F.R.12.212 and
 * 48 C.F.R. 227.7202-1 through 227.7202-4 (JUNE 1995), all
 * U.S. Government End Users acquire the Licensed Deliverables with
 * only those rights set forth herein.
 *
 * Any use of the Licensed Deliverables in individual and commercial
 * software must include, in the user documentation and internal
 * comments to the code, the above Disclaimer and U.S. Government End
 * Users Notice.
 */

#include <cstdio>
#include <cstdlib>
#include <vector>

#include <cublas_v2.h>
#include <cuda_runtime.h>
#include <cuda_bf16.h>
#include <time.h>  
#include "cublas_utils.h"

using data_type = int8_t;

int main(int argc, char *argv[]) {
    cublasHandle_t cublasH = NULL;
    cudaStream_t stream = NULL;

    const int m = 1024;
    const int n = 2048;
    const int k = 512;
    const int lda = 1024;
    const int ldb = 2048;
    const int ldc = 1024;
    const int batch_count = 5;

    // const long long int strideA = m * k;
    // const long long int strideB = k * n;
    // const long long int strideC = m * n;
    const long long int strideA = 4096;
    const long long int strideB = 4096;
    const long long int strideC = 2097152;

    /*
     *   A = | 1.0 | 2.0 | 5.0 | 6.0 |
     *       | 3.0 | 4.0 | 7.0 | 8.0 |
     *
     *   B = | 5.0 | 6.0 |  9.0 | 10.0 |
     *       | 7.0 | 8.0 | 11.0 | 12.0 |
     */

    const std::vector<data_type> A(m * k * batch_count);
    const std::vector<data_type> B(n * k * batch_count);
    std::vector<int32_t> C(m * n * batch_count);
    const int32_t alpha = 1.1;
    const int32_t beta = 1.0;

    data_type *d_A = nullptr;
    data_type *d_B = nullptr;
    int32_t *d_C = nullptr;

    cublasOperation_t transa = CUBLAS_OP_N;
    cublasOperation_t transb = CUBLAS_OP_T;

    // printf("A[0]\n");
    // print_matrix(m, k, A.data(), lda);
    // printf("=====\n");

    // printf("A[1]\n");
    // print_matrix(m, k, A.data() + (m * k), lda);
    // printf("=====\n");

    // printf("B[0]\n");
    // print_matrix(k, n, B.data(), ldb);
    // printf("=====\n");

    // printf("B[1]\n");
    // print_matrix(k, n, B.data() + (k * n), ldb);
    // printf("=====\n");

    /* step 1: create cublas handle, bind a stream */
    CUBLAS_CHECK(cublasCreate(&cublasH));

    CUDA_CHECK(cudaStreamCreateWithFlags(&stream, cudaStreamNonBlocking));
    CUBLAS_CHECK(cublasSetStream(cublasH, stream));

    /* step 2: copy data to device */
    CUDA_CHECK(cudaMalloc(reinterpret_cast<void **>(&d_A), sizeof(data_type) * A.size()));
    CUDA_CHECK(cudaMalloc(reinterpret_cast<void **>(&d_B), sizeof(data_type) * B.size()));
    CUDA_CHECK(cudaMalloc(reinterpret_cast<void **>(&d_C), sizeof(int32_t) * C.size()));

    CUDA_CHECK(cudaMemcpyAsync(d_A, A.data(), sizeof(data_type) * A.size(), cudaMemcpyHostToDevice,
                               stream));
    CUDA_CHECK(cudaMemcpyAsync(d_B, B.data(), sizeof(data_type) * B.size(), cudaMemcpyHostToDevice,
                               stream));

    CUDA_CHECK(cudaStreamSynchronize(stream));
    const clock_t begin_time = clock();

    /* step 3: compute */
    // CUBLAS_CHECK(cublasGemmStridedBatchedEx(
    //     cublasH, transa, transb, m, n, k, &alpha, d_A, traits<data_type>::cuda_data_type, lda,
    //     strideA, d_B, traits<data_type>::cuda_data_type, ldb, strideB, &beta, d_C,
    //     traits<data_type>::cuda_data_type, ldc, strideC, batch_count, CUBLAS_COMPUTE_16F,
    //     CUBLAS_GEMM_DEFAULT_TENSOR_OP));
    const int iterations = 100;
    for (int i = 0; i < iterations; i++) {
        // CUBLAS_CHECK(cublasGemmStridedBatchedEx(
        //     cublasH, transa, transb, m, n, k, &alpha, d_A, CUDA_R_16BF, lda,
        //     strideA, d_B, CUDA_R_16BF, ldb, strideB, &beta, d_C,
        //     CUDA_R_16BF, ldc, strideC, batch_count, CUBLAS_COMPUTE_32F_FAST_16BF,
        //     CUBLAS_GEMM_DEFAULT));
        cublasGemmStridedBatchedEx(
            cublasH, transa, transb, m, n, k, &alpha, d_A, CUDA_R_8I, lda,
            strideA, d_B, CUDA_R_8I, ldb, strideB, &beta, d_C,
            CUDA_R_32I, ldc, strideC, batch_count, CUBLAS_COMPUTE_32I,
            CUBLAS_GEMM_DEFAULT);
    }

    CUDA_CHECK(cudaStreamSynchronize(stream));
    const clock_t end_time = clock();
    std::cout << float( end_time - begin_time ) /  CLOCKS_PER_SEC / iterations;
    std::cout << " seconds/iter \n";
    const float flop = (2.0 * m * n * k + 3.0 * m * n ) * iterations * batch_count;
    printf ("FLOP = %f \n", flop);
    printf ("FLOPS = %f \n", flop / (float( end_time - begin_time ) /  CLOCKS_PER_SEC) / pow(10.0, 9.0));

    /* step 4: copy data to host */
    CUDA_CHECK(cudaMemcpyAsync(C.data(), d_C, sizeof(data_type) * C.size(), cudaMemcpyDeviceToHost,
                               stream));

    

    /*
     *   C = | 19.0 | 22.0 | 111.0 | 122.0 |
     *       | 43.0 | 50.0 | 151.0 | 166.0 |
     */

    // printf("C[0]\n");
    // print_matrix(m, n, C.data(), ldc);
    // printf("=====\n");

    // printf("C[1]\n");
    // print_matrix(m, n, C.data() + (m * n), ldc);
    // printf("=====\n");

    /* free resources */
    CUDA_CHECK(cudaFree(d_A));
    CUDA_CHECK(cudaFree(d_B));
    CUDA_CHECK(cudaFree(d_C));

    CUBLAS_CHECK(cublasDestroy(cublasH));

    CUDA_CHECK(cudaStreamDestroy(stream));

    CUDA_CHECK(cudaDeviceReset());

    return EXIT_SUCCESS;
}
