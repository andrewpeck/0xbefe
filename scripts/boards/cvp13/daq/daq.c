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

#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/types.h>
#include <unistd.h>

#include "dma_utils.c"

#define DEVICE_NAME_DEFAULT "/dev/xdma0_c2h_0"
#define OUT_FILE_DEFAULT "/tmp/cvp13_daq.dat"
#define SIZE_DEFAULT (67108864)

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
  uint64_t size = SIZE_DEFAULT;

  ssize_t rc = 0;
	size_t out_offset = 0;
  size_t bytes_in_buf = 0;
  size_t bytes_done = 0;
	uint64_t i;
	char *buffer = NULL;
	char *allocated = NULL;
	struct timespec ts_start, ts_end;
	int out_fd = -1;
	int fpga_fd;
	long total_time = 0;
	float result;
	float avg_time = 0;
	int underflow = 0;

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

  posix_memalign((void **)&allocated, 4096 /*alignment */ , size + 4096);
	if (!allocated) {
		fprintf(stderr, "OOM %lu.\n", size + 4096);
    cleanup(fpga_fd, out_fd, allocated);
		return -ENOMEM;
	}

  printf("%d byte buffer allocated\n", size);

	buffer = allocated;

  while (keepRunning) {
    rc = read(fpga_fd, buffer, size);
    // ignore errors, because they can just come due to device not sending any data for some time
    if (rc >= 0) {
      bytes_in_buf += rc;
    }

    if (bytes_in_buf > 32*1024*1024) {
      rc = write(out_fd, buffer, size);
      bytes_done += bytes_in_buf;
      bytes_in_buf = 0;
    }

    // rc = read_to_buffer(device, fpga_fd, buffer, size, address);
    // if (rc < 0) {
    //   printf("ERROR: read_to_buffer returned %d\n", rc);
    //   break;
    // }
  }

  printf("Bytes read: %d\n", bytes_done);
  printf("DONE\n");

  cleanup(fpga_fd, out_fd, allocated);

	return rc;
}
