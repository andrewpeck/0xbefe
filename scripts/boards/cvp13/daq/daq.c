/*
 * This file is part of the Xilinx DMA IP Core driver tool for Linux
 *
 * Copyright (c) 2016-present,  Xilinx, Inc.
 * All rights reserved.
 *
 * This source code is licensed under BSD-style license (found in the
 * LICENSE file in the root directory of this source tree)
 */

#define _BSD_SOURCE
#define _XOPEN_SOURCE 500
#include <assert.h>
#include <fcntl.h>
#include <getopt.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <signal.h>
#include <stdbool.h>

#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/types.h>
#include <unistd.h>

#include "dma_utils.c"

#define DEVICE_NAME_DEFAULT "/dev/xdma0_c2h_0"
#define OUT_FILE_DEFAULT "/tmp/cvp13_daq.dat"
#define BUF_SIZE_DEFAULT (67108864)
#define READ_SIZE_DEFAULT (1048576)
#define WRITE_SIZE_DEFAULT (1048576)

static volatile int keepRunning = 1;

void intHandler(int dummy) {
    keepRunning = 0;
}

void cleanup(int fpga_fd, int out_fd, char* allocated)
{
  if (fpga_fd >= 0)
    close(fpga_fd);
	if (out_fd >= 0)
		close(out_fd);
	free(allocated);
}

int main(int argc, char *argv[])
{
  char *device = DEVICE_NAME_DEFAULT;
	uint64_t address = 0;
	char *ofname = OUT_FILE_DEFAULT;
  uint64_t buf_size = BUF_SIZE_DEFAULT;
  uint64_t read_size = READ_SIZE_DEFAULT;
  uint64_t write_size = WRITE_SIZE_DEFAULT;

  ssize_t rc = 0;
	size_t out_offset = 0;
  size_t bytes_in_buf = 0;
  size_t bytes_done = 0;
	uint64_t i;
	char *buffer = NULL;
	char *allocated = NULL;
	struct timespec ts_start, ts_last_flush, ts_end_1, ts_end_2;
	int out_fd = -1;
	int fpga_fd;
	long total_time = 0;
  double avg_data_rate = 0.0;
  double inst_data_rate = 0.0;
	float result;
	float avg_time = 0;
	int underflow = 0;
  bool first_read = true;

  signal(SIGINT, intHandler);

  printf("Welcome to CVP13 DAQ\n");

  fpga_fd = open(device, O_RDWR | O_TRUNC);

  if (fpga_fd < 0) {
    fprintf(stderr, "unable to open device %s, %d.\n", device, fpga_fd);
		perror("open device");
    return -EINVAL;
  }

  printf("PCIe DMA device opened\n");

  /* create file to write data to */
	if (ofname) {
		out_fd = open(ofname, O_RDWR | O_CREAT | O_TRUNC | O_SYNC,
				0666);
		if (out_fd < 0) {
      fprintf(stderr, "unable to open output file %s, %d.\n", ofname, out_fd);
			perror("open output file");
      cleanup(fpga_fd, out_fd, allocated);
      return -EINVAL;
    }
	}

  printf("Output file created: %s\n", ofname);

  posix_memalign((void **)&allocated, 4096 /*alignment */ , buf_size + 4096);
	if (!allocated) {
		fprintf(stderr, "OOM %lu.\n", buf_size + 4096);
    cleanup(fpga_fd, out_fd, allocated);
		return -ENOMEM;
	}

  printf("%d byte buffer allocated\n", buf_size);

	buffer = allocated;

  while (keepRunning) {
    rc = read(fpga_fd, buffer + bytes_in_buf, read_size);
    // ignore errors, because they can just come due to device not sending any data for some time
    if (rc >= 0) {
      bytes_in_buf += rc;
      if (first_read) {
        clock_gettime(CLOCK_MONOTONIC, &ts_start);
        first_read = false;
      }
      // printf("Received %d bytes\n", bytes_in_buf);
    }

    if (bytes_in_buf > write_size) {
      rc = write(out_fd, buffer, bytes_in_buf);
      bytes_done += bytes_in_buf;
      clock_gettime(CLOCK_MONOTONIC, &ts_end_1);
      timespec_sub(&ts_end_1, &ts_start);
      clock_gettime(CLOCK_MONOTONIC, &ts_end_2);
      timespec_sub(&ts_end_2, &ts_last_flush);
      // inst_data_rate = ((long)bytes_in_buf / ((long)ts_end_2.tv_nsec / 1000000000)) / 1048576;
      if (ts_end_1.tv_sec > 0) {
        avg_data_rate = (double)((long)bytes_done / ((long)ts_end_1.tv_sec)) / 1048576;
      }
      printf("Flushing to file %ld bytes, total bytes readout is %ld. Avg data_rate is %.2lfMB/s, inst data rate is %.2lfMB/s\n", bytes_in_buf, bytes_done, avg_data_rate, inst_data_rate);
      printf("total time passed: %ld\n", (long) ts_end_1.tv_sec);
      clock_gettime(CLOCK_MONOTONIC, &ts_last_flush);
      // fflush(stdout);
      bytes_in_buf = 0;
    }

    // rc = read_to_buffer(device, fpga_fd, buffer, size, address);
    // if (rc < 0) {
    //   printf("ERROR: read_to_buffer returned %d\n", rc);
    //   break;
    // }
  }

  if (bytes_in_buf > 0) {
    rc = write(out_fd, buffer, bytes_in_buf);
    bytes_done += bytes_in_buf;
  }

  printf("Bytes read: %d\n", bytes_done);
  printf("DONE\n");

  cleanup(fpga_fd, out_fd, allocated);

	return rc;
}
