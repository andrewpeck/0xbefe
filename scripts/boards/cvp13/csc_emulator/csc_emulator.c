/*
 * This file is part of the QDMA userspace application
 * to enable the user to execute the QDMA functionality
 *
 * Copyright (c) 2018-2020,  Xilinx, Inc.
 * All rights reserved.
 *
 * This source code is licensed under BSD-style license (found in the
 * LICENSE file in the root directory of this source tree)
 */

#define _DEFAULT_SOURCE
#define _XOPEN_SOURCE 500
#include <assert.h>
#include <fcntl.h>
#include <getopt.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <time.h>

#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/types.h>
#include <unistd.h>

#include "rwreg.h"

#include "dma_xfer_utils.c"

#define SIZE_DEFAULT (32)
#define COUNT_DEFAULT (1)
#define MAX_LINKS (16)
#define DEFAULT_DEV_PREFIX "/dev/qdma05000"
#define DEFAULT_LINK_BUF_SIZE (1024*1024*1024) // 1GB
#define DEFAULT_MAX_EVENTS (100 * 1000000) // 100M
#define DEFAULT_CHUNK_SIZE (4096)
#define DEFAULT_TTC_CHUNK_SIZE (128)

static struct option const long_opts[] = {
	{"raw file", required_argument, NULL, 'f'},
	{"device prefix", required_argument, NULL, 'd'},
	{"size", required_argument, NULL, 's'},
	{"daq latency", required_argument, NULL, 'l'},
	{"buffer size to allocate for each link in MB (default 1GB)", required_argument, NULL, 'b'},
	{"number of events to allocate event info and ttc buffers for (default 100M)", required_argument, NULL, 'e'},
	{"number of times to repeat sending the raw file (0 means only send it once)", required_argument, NULL, 'r'},
	{"minimum size of the PCIe packets in 64bit words to the link FIFOs", required_argument, NULL, 'c'},
	{"minimum size of the PCIe packets in 64bit words to the link FIFOs", required_argument, NULL, 't'},
	{"print the provided num words from the raw file", required_argument, NULL, 'p'},
	{"start the raw file print at the first non-empty event", no_argument, NULL, 'n'},
	{"dry run -- don't access hardware (this can be run on a computer with no CVP13)", no_argument, NULL, 'z'},
	{"test run -- send a few fake events to the CVP13", no_argument, NULL, 'y'},
	{"help", no_argument, NULL, 'h'},
	{"verbose", no_argument, NULL, 'v'},
	{0, 0, 0, 0}
};

struct Reg {
	uint32_t addr;
	uint32_t mask;
	uint32_t shift;
	uint32_t gen_addr_step;
};

// hard coding the reg addresses, and masks for now
static struct Reg const REG_RESET = {0x00240000, 0xffffffff, 0, 0};
static struct Reg const REG_DAQ_LATENCY = {0x00240004, 0x000000ff, 0, 0};
static struct Reg const REG_NUM_LINKS = {0x00248000, 0x000000ff, 0, 0};
static struct Reg const REG_AXI_WIDTH = {0x00248000, 0x0003ff00, 8, 0};
static struct Reg const REG_TTC_FIFO_DEPTH = {0x00248004, 0x0000ffff, 0, 0};
static struct Reg const REG_LINK_WIDTH = {0x00248040, 0x000000ff, 0, 0x40};
static struct Reg const REG_LINK_FIFO_DEPTH = {0x00248040, 0xffffff00, 8, 0x40};
static struct Reg const REG_LINK_FIFO_EVT_CNT = {0x00244040, 0xffffffff, 0, 0x40};
static struct Reg const REG_LINK_FIFO_STATUS = {0x00244044, 0xffffffff, 0, 0x40};
static struct Reg const REG_TTC_FIFO_STATUS = {0x00244000, 0xffffffff, 0, 0x40};

struct Config {
	int num_links;
	uint32_t max_links;
	int crate_ids[MAX_LINKS];
	int dmb_ids[MAX_LINKS];
	uint32_t axi_width_words;
	uint32_t ttc_fifo_depth;
	uint32_t link_widths[MAX_LINKS];
	uint32_t fifo_depths[MAX_LINKS];
	uint32_t daq_latency;
	uint32_t target_link_fifo_fill;
	uint32_t target_ttc_fifo_fill;
	uint64_t chunk_size;
	uint64_t ttc_chunk_size;
	int dry_run;
	int test_run;
	long unsigned buffer_size;
	long unsigned max_events;
	char* dev_prefix;
	char* ttc_dev_name;
	int ttc_dev_fd;
	char* link_dev_names[MAX_LINKS];
	int link_dev_fds[MAX_LINKS];
};

struct Event {
	uint64_t* start_ptr;
	size_t size;
};

struct LinkStatus {
	uint32_t event_cnt;
	uint32_t word_err;
	uint32_t full;
	uint32_t data_cnt;
	uint32_t had_ovf;
	uint32_t had_unf;
};

struct TTCStatus {
	uint32_t full;
	uint32_t data_cnt;
	uint32_t had_ovf;
	uint32_t had_unf;
	uint32_t first_resync_done;
};

static void usage(const char *name)
{
	int i = 0;

	fprintf(stdout, "%s\n\n", name);
	fprintf(stdout, "usage: %s [OPTIONS] <LINK0_CRATE_ID> <LINK0_DMB_ID> [LINK1_CRATE_ID LINK1_DMB_ID....]\n\n", name);
	fprintf(stdout, 
		"Write via SGDMA, optionally read input from a file.\n\n");

	fprintf(stdout,
		"  -%c (--%s) size of a single transfer in bytes, default %d,\n",
		long_opts[i].val, long_opts[i].name, SIZE_DEFAULT);
	i++;
	fprintf(stdout, "  -%c (--%s) filename to read the data from.\n",
		long_opts[i].val, long_opts[i].name);
	i++;
	fprintf(stdout, "  -%c (--%s) print usage help and exit\n",
		long_opts[i].val, long_opts[i].name);
	i++;
	fprintf(stdout, "  -%c (--%s) verbose output\n",
		long_opts[i].val, long_opts[i].name);
}

static uint32_t read_reg_gen(const struct Reg reg, const uint32_t gen_idx) {
	uint32_t val = (uint32_t) getReg(reg.addr + reg.gen_addr_step * gen_idx);
	val = (val & reg.mask) >> reg.shift;
	return val;
}

static uint32_t read_reg(const struct Reg reg) {
	return read_reg_gen(reg, 0);
}

static int write_reg(const struct Reg reg, const uint32_t value) {
	uint32_t val = 0;
	if (reg.mask != 0xffffffff) {
		val = read_reg(reg);
		val &= ~reg.mask;
	}
	val |= (value << reg.shift) & reg.mask;
	int ret = putReg(reg.addr, val);
	if (ret != 0) {
		printf("Error while writing register to address %ux and mask %ux", reg.addr, reg.mask);
	}
	return ret;
}

static void read_fw_config(struct Config* config) {
	if (!config->dry_run) {
		config->axi_width_words = read_reg(REG_AXI_WIDTH) / 64;
		config->max_links = read_reg(REG_NUM_LINKS);
		config->ttc_fifo_depth = read_reg(REG_TTC_FIFO_DEPTH);
		for (int i=0; i < config->max_links; i++) {
			config->link_widths[i] = read_reg_gen(REG_LINK_WIDTH, i);
			config->fifo_depths[i] = read_reg_gen(REG_LINK_FIFO_DEPTH, i);
		}
	} else {
		config->axi_width_words = 1;
		config->max_links = 4;
		config->ttc_fifo_depth = 512;
		for (int i=0; i < config->max_links; i++) {
			config->link_widths[i] = 16;
			config->fifo_depths[i] = 4096;
		}
	}
}

// returns 1 if the link reports a problem
static int read_link_status(int link_idx, struct LinkStatus* status, int read_evt_cnt) {
	if (read_evt_cnt) {
		status->event_cnt = read_reg_gen(REG_LINK_FIFO_EVT_CNT, link_idx);
	} else {
		status->event_cnt = 0;
	}
	uint32_t st = read_reg_gen(REG_LINK_FIFO_STATUS, link_idx);
	status->word_err = st & 1;
	status->full = (st >> 4) & 1;
	status->had_ovf = (st >> 5) & 1;
	status->had_unf = (st >> 6) & 1;
	status->data_cnt = st >> 16;

	if (st & 0xff)
		return 1;
	else
		return 0;
}

// returns 1 if TTC is reporting a problem
static int read_ttc_status(struct TTCStatus* status) {
	uint32_t st = read_reg(REG_TTC_FIFO_STATUS);
	status->full = st & 1;
	status->had_ovf = (st >> 1) & 1;
	status->had_unf = (st >> 2) & 1;
	status->first_resync_done = (st >> 3) & 1;
	status->data_cnt = st >> 16;

	if (st & 0x7)
		return 1;
	else
		return 0;
}

static void print_link_status(const int link_idx, const struct LinkStatus status) {
	printf("Link %d status: event cnt %u, fifo data cnt %u, word error %u, full %u, had overflow %u, had underflow %u\n",
			link_idx, status.event_cnt, status.data_cnt, status.word_err, status.full, status.had_ovf, status.had_unf);
}

static void print_ttc_status(const struct TTCStatus status) {
	printf("TTC status: fifo data cnt %u, first resync done %u, full %u, had overflow %u, had underflow %u\n",
			status.data_cnt, status.first_resync_done, status.full, status.had_ovf, status.had_unf);
}

static uint64_t* read_file_to_mem(const char* fname, long *num_words) {
	FILE* f;
	uint64_t* buf;
	long num_bytes;

	f = fopen(fname, "r");
	if (f == NULL) {
		printf("ERROR: could not open file %s\n", fname);
		return NULL;
	}
	// get number of bytes in the file
	fseek(f, 0L, SEEK_END);
	num_bytes = ftell(f);
	fseek(f, 0L, SEEK_SET);

	// check if it's 64bit aligned
	if (num_bytes % 8 != 0) {
		printf("ERROR: the file size is not a multiple of 64bits");
		return NULL;
	}

	*num_words = (long) num_bytes / 8;

	// allocate the memory
	printf("Allocating %ldMB of memory and copying the raw file contents there\n", num_bytes/1024/1024);
	// TODO: consider using posix_memalign instead of malloc
//	buf = (uint64_t*) malloc(num_bytes + sizeof(uint64_t));
	posix_memalign((void **)&buf, 4096 /*alignment */ , num_bytes + 4096);

	if (buf == NULL) {
		printf("ERROR: could not allocate memory for %ld bytes\n", num_bytes);
		return NULL;
	}

	fread(buf, sizeof(uint64_t), *num_words, f);

	return buf;
}

static int init_hw(struct Config *config) {
	// maybe create and start the queues here in the future
	// for now just wrote a shell script to do that with the dma-ctl tool
	if (!config->dry_run) {
		write_reg(REG_RESET, 1);
		usleep(50000);
//		write_reg(REG_DAQ_LATENCY, config->daq_latency);
	}

	//open the queue device files
	config->ttc_dev_name = malloc(strlen((config->dev_prefix) + 7) * sizeof(char));
	sprintf(config->ttc_dev_name, "%s%s%d", config->dev_prefix, "-ST-", 0);
	if (!config->dry_run) {
		config->ttc_dev_fd = open(config->ttc_dev_name, O_RDWR);
	} else {
		config->ttc_dev_fd = 99999;
	}
	if (config->ttc_dev_fd < 0) {
		printf("ERROR: cannot open device %s", config->ttc_dev_name);
		return -1;
	}

	for (int i=0; i < config->num_links; i++) {
		config->link_dev_names[i] = malloc(strlen((config->dev_prefix) + 7) * sizeof(char));
		sprintf(config->link_dev_names[i], "%s%s%d", config->dev_prefix, "-ST-", i + 1);
		if (!config->dry_run) {
			config->link_dev_fds[i] = open(config->link_dev_names[i], O_RDWR);
			if (config->link_dev_fds[i] < 0) {
				printf("ERROR: cannot open device %s", config->link_dev_names[i]);
				return -1;
			}
		} else {
			config->link_dev_fds[i] = 99999;
		}
	}
}

static int close_hw(struct Config *config) {
	close(config->ttc_dev_fd);
	for (int i=0; i < config->num_links; i++) {
		close(config->link_dev_fds[i]);
	}
	return 0;
}

static uint64_t next_orbit(uint64_t last_orbit, uint64_t last_bx, uint64_t next_bx) {
	if (next_bx > last_bx + 1) { // note current firmware cannot handle consecutive L1As
		return last_orbit;
	} else {
		return last_orbit + 1;
	}
//	return last_orbit + 1;
//	return last_orbit;
}

static void print_event(int link_idx, long unsigned event_idx, long unsigned word_idx, struct Event* event) {
	long unsigned num_words = event->size / 8;
	printf("==== Link %d, event %lu, word %lu ====\n", link_idx, event_idx, word_idx);
	printf("Event size is %lu Bytes / %lu words\n", event->size, num_words);
	for (int word=0; word < num_words; word++) {
		printf("%d: %016lx\n", word, event->start_ptr[word]);
	}
}

static int process_data(const struct Config config, uint64_t* data, const long num_words, int num_repetitions, struct Event** link_data, long unsigned* num_events, long unsigned* total_link_words, struct Event* ttc_data, long unsigned* total_ttc_words, uint64_t (*orbit_func)(uint64_t, uint64_t, uint64_t)) {

	// initialize crate_id + dmb_id to file descriptor and link ID maps
	int ttc_fd = config.ttc_dev_fd;
	int dmb_fds[0xff+1][0xf+1];
	int dmb_link_ids[0xff+1][0xf+1];

	memset(dmb_fds, -1, sizeof(dmb_fds));
	memset(dmb_link_ids, -1, sizeof(dmb_fds));
	for (int i=0; i < config.num_links; i++) {
		dmb_fds[config.crate_ids[i]][config.dmb_ids[i]] = config.link_dev_fds[i];
		dmb_link_ids[config.crate_ids[i]][config.dmb_ids[i]] = i;
	}

	////////////////////////////////////////
	int num_repeated = num_repetitions;
	long unsigned word = 0;
	long unsigned words_sent = 0;
	long unsigned event_cnt = 0;
	long unsigned num_extra_words = 0;

	uint64_t fed_header1;
	uint64_t fed_header2;
	uint64_t fed_header3;

	uint64_t fed_l1id;
	uint64_t fed_bx;
	uint64_t fed_id;
	uint64_t fifo_full_mask;
	uint64_t fed_num_dmbs;
	uint64_t orbit = 0;
	uint64_t last_orbit = 0;
	uint64_t last_bx = 0;

	uint64_t dmb_header1;
	uint64_t dmb_header2;

	uint64_t dmb_l1id;
	uint64_t crate_id;
	uint64_t dmb_id;
	long unsigned dmb_size;
	long unsigned axi_extra_words;

	int link_id;

	long unsigned dmb_start_word = 0;
	long unsigned dmb_end_word = 0;

	uint64_t link_empty[config.num_links];

	uint64_t* link_data_ptr[config.num_links];
	for (int link=0; link < config.num_links; link++) {
		link_data_ptr[link] = link_data[link][0].start_ptr;
		total_link_words[link] = 0;
	}
	uint64_t* ttc_data_ptr = ttc_data[0].start_ptr;
	*total_ttc_words = 0;

	struct timespec ts_start, ts_end;
	clock_gettime(CLOCK_MONOTONIC, &ts_start);

	// add a TTC resync before everything else
	ttc_data_ptr[0] = ((uint64_t) 1) << 49;
	ttc_data[0].start_ptr = ttc_data_ptr;
	ttc_data[0].size = 1;
	ttc_data_ptr++;
	(*total_ttc_words)++;

	while (word < num_words) {
		while ((word + 1 < num_words) && (data[word+1] >> 16 != 0x800000018000)) {
			printf("WARNING: extra words before the expected FED header at word %lu.. skipping.. 0x%016lx", word, data[word]);
			num_extra_words++;
			word++;
		}

		fed_header1 = data[word++];
		fed_header2 = data[word++];
		fed_header3 = data[word++];

//		uint64_t fed_header_marker = (fed_header2 >> 16) & 0xffffffffffff;
//
//		if (fed_header_marker != 0x800000018000) { // this is a moot point since I'm skipping them now
//			printf("ERROR: bad FED header marker in event %lu, 64bit word index in the file %lu. It should be 0x800000018000, but got 0x%lx", event_cnt, word - 2, fed_header_marker);
//			return -1;
//		}

		fed_l1id = (fed_header1 >> 32) & 0xffffff;
		fed_bx = (fed_header1 >> 20) & 0xfff;
		fed_id = (fed_header1 >> 8) & 0xfff;
		fifo_full_mask = fed_header2 & 0xffff;
		fed_num_dmbs = fed_header3 & 0xf;
		// unfortunately we don't have orbit information in the CSC data... so we just use a supplied function to generate it based on the last orbit and bx
		orbit = (*orbit_func)(last_orbit, last_bx, fed_bx);
		last_orbit = orbit;
		last_bx = fed_bx;

		memset(link_empty, 1, sizeof(link_empty));

		while (data[word] != 0x8000ffff80008000) {
			// DMB header
			if ((data[word] & 0xf000f000f000f000) == 0x9000900090009000) {
				dmb_start_word = word;
				dmb_header1 = data[word++];
				dmb_header2 = data[word++];

				if ((dmb_header2 & 0xf000f000f000f000) != 0xa000a000a000a000) {
					printf("ERROR: bad DMB header2 at word %lu -- the top nibble of each 16bit words should be set to DDU code A, but got 0x%016lx\n", word - 1, dmb_header2);
					return -1;
				}

				dmb_l1id = ((dmb_header1 >> 4) & 0xfff000) | (dmb_header1 & 0xfff);

				if (dmb_l1id != fed_l1id) {
					printf("ERROR: DMB L1ID doesn't match the FED L1ID in event %lu word %lu. FED L1ID = %lu, DMB L1ID = %lu\n", event_cnt, word, fed_l1id, dmb_l1id);
					return -1;
				}
//			}
//
//			// DMB header not found where it was supposed to
//			else if (dmb_start_word == 0) {
//				printf("WARNING: extra words before the expected DMB header at word %lu.. skipping.. 0x%016lx\n", word, data[word]);
//				num_extra_words++;
//				word++;

			// DMB trailer
			} else if ((data[word] & 0xf000f000f000f000) == 0xf000f000f000f000) {
				if (dmb_start_word == 0) {
					printf("ERROR: found DMB trailer but there was no matching DMB header. Event %lu, word %lu.\n", event_cnt, word);
					return -1;
				}

				crate_id = (dmb_header2 >> 20) & 0xff;
				dmb_id = (dmb_header2 >> 16) & 0xf;

				if (dmb_fds[crate_id][dmb_id] != -1) {
					// Send the data
					link_id = dmb_link_ids[crate_id][dmb_id];
					link_empty[link_id] = 0;
					words_sent += (word - dmb_start_word) + 2;
					if (verbose) {
						printf(">>>>> Writing event %lu from Crate ID %lu DMB ID %lu to link %d\n", event_cnt, crate_id, dmb_id, link_id);
					}

			        // link word must be inserted before the data of each event with the following information:
			        //     * [63:56] -- constant 0xbc
			        //     * [55]    -- if this bit is set, it means that this event is empty (note to self: could just use [11:0] = 0 for this condition, so this bit is not really necessary)
			        //     * [54:52] -- number of extra 64bit words to skip at the end (given that AXI bus side can be up to 8x wider, there may be "null" data at the end)
			        //     * [51:24] -- Orbit number
			        //     * [23:12] -- BX number
			        //     * [11:0]  -- number of 64bit words in this event
					// note that the data for each event should be aligned with the AXI bus width, so insert extra words at the end as needed
					dmb_size = word + 2 - dmb_start_word;
					if (dmb_size > 0xfff) {
						printf("ERROR: DMB block size is more than 4096 words, so the DMB word count doesn't fit into 12 bits required by the firmware.. Crate ID %lu DMB ID %lu, start word position %lu", crate_id, dmb_id, dmb_start_word);
						return -1;
					}
					axi_extra_words = dmb_size % config.axi_width_words;
					link_data_ptr[link_id][0] = (((uint64_t) 0xbc) << 56) | (((uint64_t) 0) << 55) | ((axi_extra_words & 0x7) << 52) | ((orbit & 0xfffffff) << 24) | ((fed_bx & 0xfff) << 12) | (dmb_size & 0xfff);
					memcpy(((void*) link_data_ptr[link_id]) + sizeof(uint64_t), ((void*) data) + dmb_start_word * sizeof(uint64_t), dmb_size * sizeof(uint64_t));
					link_data[link_id][event_cnt].start_ptr = link_data_ptr[link_id];
					link_data[link_id][event_cnt].size = (dmb_size + 1 + axi_extra_words) * sizeof(uint64_t);
//					if (dmb_size > 10 && event_cnt <= 255) {
//						printf("---------------------------------------\n");
//						printf("Assigning size = %lu to link id %d, event id %lu\n", (dmb_size + 1 + axi_extra_words) * sizeof(uint64_t), link_id, event_cnt);
//						printf("pointer value: %lu\n", link_data_ptr[link_id] - link_data[link_id][0].start_ptr);
//						printf("Reading it back = %lu\n", link_data[link_id][event_cnt].size);
//						printf("---------------------------------------\n");
//					}
					link_data_ptr[link_id] += dmb_size + 1;
					while (axi_extra_words > 0) {
						link_data_ptr[link_id][0] = 0;
						link_data_ptr[link_id]++;
						axi_extra_words--;
					}

				} else if (verbose) {
					printf("Event %lu skipping data from Crate ID %lu DMB %lu because it's not associated to any link\n", event_cnt, crate_id, dmb_id);
				}

				word += 2;
				dmb_start_word = 0;
			// DMB data
			} else {
				word++;
			}

		}

		// DMB packet did not close before the FED trailer was found
		if (dmb_start_word != 0) {
			printf("ERROR: DMB packet did not close before the FED trailer was found at word %lu\n", word);
			return -1;
		}

		// send empty events
		for (int link=0; link < config.num_links; link++) {
			if (link_empty[link]) {
				// send empty here
				if (verbose) {
					printf("Writing EMPTY event %lu to link %d\n", event_cnt, link);
				}
				dmb_size = 1;
				axi_extra_words = dmb_size % config.axi_width_words;
				link_data_ptr[link][0] = (((uint64_t) 0xbc) << 56) | (((uint64_t) 1) << 55) | ((axi_extra_words & 0x7) << 52) | ((orbit & 0xfffffff) << 24) | ((fed_bx & 0xfff) << 12) | (dmb_size & 0xfff);
				link_data_ptr[link][1] = 0x8000800080008000 | (fed_l1id & 0xfff) | ((fed_l1id & 0xfff000) << 4) | ((((uint64_t)fed_bx) & 0xfff) << 48);
				link_data[link][event_cnt].start_ptr = link_data_ptr[link];
				link_data[link][event_cnt].size = (dmb_size + 1 + axi_extra_words) * sizeof(uint64_t);
				link_data_ptr[link] += dmb_size + 1;
				while (axi_extra_words > 0) {
					link_data_ptr[link][0] = 0;
					link_data_ptr[link]++;
					axi_extra_words--;
				}
			}
		}

		// Send the TTC info
	    //     * [49]    -- Insert resync (if this bit is set, a resync will be inserted at the given Orbit/BX)
	    //     * [48]    -- Insert L1A (if this bit is set, an L1A will be inserted at the given Orbit/BX)
	    //     * [47:20] -- Orbit number (only used for L1A/resync insertion, or for inserting empty events if "insert empty" feature is implemented)
	    //     * [19:8]  -- BX number (only used for L1A/resync insertion, or for inserting empty events if "insert empty" feature is implemented)

		ttc_data_ptr[0] = (((uint64_t) 1) << 48) | ((orbit & 0xfffffff) << 20) | ((fed_bx & 0xfff) << 8);
		ttc_data[event_cnt + 1].start_ptr = ttc_data_ptr;
		ttc_data[event_cnt + 1].size = 1;
		ttc_data_ptr++;
		(*total_ttc_words)++;

		word += 3;

		if (verbose) {
			printf("End of event %lu, we are at word %lu\n", event_cnt, word);
		}

		event_cnt++;

		if (word >= num_words && num_repetitions > 0) {
			word = 0;
			num_repetitions--;
		}
	}

	*num_events = event_cnt;
	for (int link=0; link < config.num_links; link++) {
		total_link_words[link] = link_data_ptr[link] - link_data[link][0].start_ptr;
	}

	clock_gettime(CLOCK_MONOTONIC, &ts_end);
	timespec_sub(&ts_end, &ts_start);
	double total_time = (ts_end.tv_sec + ((double)ts_end.tv_nsec/NSEC_DIV));
	long unsigned total_words = word * (num_repeated + 1);
	double throughput = ((double)(total_words * 8)) / 1024.0 / 1024.0 / total_time;
	printf("\n===========================\n");
	printf("Processed %lu events and %lu words\n", event_cnt, total_words);
	printf("Total DMB words sent to links: %lu\n", words_sent);
	printf("Took %.3fs, throughput: %.3fMB/s\n\n", total_time, throughput);

	printf("size of event %lu on link %d: %lu\n", (long unsigned)0, 0, link_data[0][0].size);

//	// print a few events from the link buffers for debugging
//	for (int link=0; link < config.num_links; link++) {
//		for (int event=255; event < 260; event++) {
//			print_event(link, event, link_data[link][event].start_ptr - link_data[link][0].start_ptr, &link_data[link][event]);
//		}
//	}

}

static uint64_t send_to_device(char* dev_name, int dev_fd, uint64_t** data_ptr, const uint64_t words, uint64_t* words_left) {
	uint64_t words_to_send = words;
	if (words_to_send > *words_left) {
		words_to_send = *words_left;
	}
	uint64_t bytes = words_to_send * 8;

	ssize_t ret = write_from_buffer(dev_name, dev_fd, (char*) *data_ptr, bytes, 0);

	if (ret != bytes) {
		printf("ERROR while writing to device %s, returned %lu while expecting %lu\n", dev_name, ret, bytes);
		return -1;
	}

	*words_left -= words_to_send;
	*data_ptr += words_to_send;

	return words_to_send;
}

static int send_to_board(const struct Config config, struct Event** link_data, const long unsigned num_events, long unsigned* total_link_words, struct Event* ttc_data, const long unsigned total_ttc_words) {

	uint64_t link_words_left[config.num_links];
	uint64_t* link_data_ptr[config.num_links];
	for (int link=0; link < config.num_links; link++) {
		link_data_ptr[link] = link_data[link][0].start_ptr;
		link_words_left[link] = total_link_words[link];
	}
	uint64_t ttc_words_left = total_ttc_words;
	uint64_t* ttc_data_ptr = ttc_data[0].start_ptr;

	const uint32_t link_refill_data_cnt = config.target_link_fifo_fill - config.chunk_size;
	const uint32_t ttc_refill_data_cnt = config.target_ttc_fifo_fill - config.ttc_chunk_size;

	struct timespec ts_start, ts_end;
	clock_gettime(CLOCK_MONOTONIC, &ts_start);

	int link = 0;

	// fill the FIFOs up to the target before we get going (start with the link data, and then do TTC)
	for (link=0; link < config.num_links; link++) {
		uint64_t ret = send_to_device(config.link_dev_names[link], config.link_dev_fds[link], &(link_data_ptr[link]), config.target_link_fifo_fill, &(link_words_left[link]));
		if (ret < 0) {
			return ret;
		}
	}
	uint64_t ret = send_to_device(config.ttc_dev_name, config.ttc_dev_fd, &ttc_data_ptr, config.target_ttc_fifo_fill, &ttc_words_left);
	if (ret < 0) {
		return ret;
	}

//	//////////// debug ////////////
//	// for debugging: check if any of the ttc words don't have the L1A bit set or orbit / bx going backwards
//	uint64_t last_orbit = 0;
//	uint64_t last_bx = 0;
//	uint64_t orbit;
//	uint64_t bx;
//	for (int i=0; i < config.target_ttc_fifo_fill; i++) {
//		orbit = (ttc_data[0].start_ptr[i] >> 20) & 0xfffffff;
//		bx = (ttc_data[0].start_ptr[i] >> 8) & 0xfff;
//		if (((orbit < last_orbit) || ((orbit == last_orbit) && (bx <= last_bx))) && (i > 0)) {
//			printf("ERROR: orbit / bx is going backwards in word %d. Last orbit = %lu, orbit = %lu, last bx = %lu, bx = %lu!\n", i, last_orbit, orbit, last_bx, bx);
//			return -1;
//		}
//		last_orbit = orbit;
//		last_bx = bx;
//		if (!(ttc_data[0].start_ptr[i] & 0x0001000000000000) && (i > 0)) {
//			printf("ERROR: L1A bit is not set in word %d!!!\n", i);
//			return -1;
//		}
//	}
//	for (int i=0; i < 2500; i++) {
//		printf("TTC word %d: 0x%016lx, masked for L1A: 0x%016lx, orbit 0x%016lx, bx 0x%016lx\n", i, ttc_data[0].start_ptr[i], ttc_data[0].start_ptr[i] & 0x0001000000000000, (ttc_data[0].start_ptr[i] >> 20) & 0xfffffff, (ttc_data[0].start_ptr[i] >> 8) & 0xfff);
//	}
//	//////////// end debug ////////////


	struct LinkStatus link_status[config.num_links];
	struct TTCStatus ttc_status;
	int prob = 0;
	int done = 0;
	uint64_t send_num_chunks = 1;
	while (!done) {
		done = 1;
		for (link=0; link < config.num_links; link++) {
			if (link_words_left[link] == 0) {
				continue;
			}
			prob = read_link_status(link, &link_status[link], 0);
			if (prob) {
				printf("ERROR: problem reported by link %d:\n", link);
				print_link_status(link, link_status[link]);
				printf("Total words sent for this link: %lu out of %lu, left %lu\n", total_link_words[link] - link_words_left[link], total_link_words[link], link_words_left[link]);
				return -1;
			}
			if (link_status[link].data_cnt < link_refill_data_cnt) {
				send_num_chunks = (config.target_link_fifo_fill - link_status[link].data_cnt) / config.chunk_size;
//				if (send_num_chunks == 0) {
//					printf("ERROR: num chunks to send set to 0, data cnt is %u, refill rate is %u, diff is %u\n", link_status[link].data_cnt, config.target_link_fifo_fill, link_refill_data_cnt - link_status[link].data_cnt);
//					return -1;
//				} else if (send_num_chunks > 1) {
//					printf("INFO: sending %lu chunks, link words left = %lu\n", send_num_chunks, link_words_left[link]);
//				}
				uint64_t ret = send_to_device(config.link_dev_names[link], config.link_dev_fds[link], &(link_data_ptr[link]), config.chunk_size * send_num_chunks, &(link_words_left[link]));
				if (ret < 0) {
					return ret;
				}
				if (link_status[link].data_cnt == 0) {
					printf("WARNING: oops, data count on link %d FIFO is ZERO -- most likely underflow has occured", link);
				}
//				printf("REFILLING LINK %d WITH %lu WORDS, BECAUSE IT HAS %u WORDS LEFT\n", link, config.chunk_size, link_status[link].data_cnt);
			} else {
//				printf("LINK %d STILL HAS %u WORDS\n", link, link_status[link].data_cnt);
			}

			if (link_words_left[link] > 0) {
				done = 0;
			}
		}
		prob = read_ttc_status(&ttc_status);
		if (prob) {
			printf("ERROR: problem reported by the TTC module:\n");
			print_ttc_status(ttc_status);
			printf("Total words sent to TTC: %lu out of %lu, left %lu\n", total_ttc_words - ttc_words_left, total_ttc_words, ttc_words_left);
			return -1;
		}
		if (ttc_status.data_cnt < ttc_refill_data_cnt) {
			uint64_t ret = send_to_device(config.ttc_dev_name, config.ttc_dev_fd, &ttc_data_ptr, config.ttc_chunk_size, &ttc_words_left);
//			printf("REFILLING TTC FIFO WITH %lu WORDS, BECAUSE IT HAS %u WORDS\n", config.ttc_chunk_size, ttc_status.data_cnt);
			if (ret < 0) {
				return ret;
			}
			if (ttc_status.data_cnt == 0) {
				printf("WARNING: oops, data count on the TTC FIFO is ZERO -- most likely underflow has occured");
			}
		} else {
//			printf("TTC STILL HAS %u WORDS\n", ttc_status.data_cnt);
		}
		if (ttc_words_left > 0) {
			done = 0;
		}
	}

	clock_gettime(CLOCK_MONOTONIC, &ts_end);
	timespec_sub(&ts_end, &ts_start);
	double total_time = (ts_end.tv_sec + ((double)ts_end.tv_nsec/NSEC_DIV));
	uint64_t total_words_sent = 0;
	for (link=0; link < config.num_links; link++) {
		total_words_sent += total_link_words[link];
	}
	total_words_sent += total_ttc_words;
	double throughput = ((double)(total_words_sent * 8)) / 1024.0 / 1024.0 / total_time;

	printf("\n===========================\n");
	printf("Total words sent: %lu\n", total_words_sent);
	printf("Took %.3fs, throughput: %.3fMB/s\n\n", total_time, throughput);

	return 0;
}

int main(int argc, char *argv[])
{
	int ret;
	int cmd_opt;
	uint64_t size = SIZE_DEFAULT;
	char *infname = NULL;
	uint32_t daq_latency = 20;
	struct Config config;
	uint64_t* data;
	long num_words;
	long print_raw_num_words = 0;
	int print_non_empty = 0;
	int num_repetitions = 0;
	struct timespec ts_start, ts_end;

	config.dev_prefix = DEFAULT_DEV_PREFIX;
	config.buffer_size = DEFAULT_LINK_BUF_SIZE;
	config.max_events = DEFAULT_MAX_EVENTS;
	config.dry_run = 0;
	config.test_run = 0;
	config.chunk_size = DEFAULT_CHUNK_SIZE;
	config.ttc_chunk_size = DEFAULT_TTC_CHUNK_SIZE;

	while ((cmd_opt =
		getopt_long(argc, argv, "evhzyt:f:l:s:d:p:r:c:", long_opts,
			    NULL)) != -1) {
		switch (cmd_opt) {
		case 0:
			/* long option */
			fprintf(stdout, "long option given: %lu", getopt_integer(optarg));
			break;
		case 's':
			/* size in bytes */
			size = getopt_integer(optarg);
			break;
		case 'f':
			infname = strdup(optarg);
			break;
		case 'l':
			daq_latency = getopt_integer(optarg);
			break;
		case 'p':
			print_raw_num_words = getopt_integer(optarg);
			break;
		case 'n':
			print_non_empty = 1;
			break;
		case 'd':
			config.dev_prefix = strdup(optarg);
			break;
		case 'r':
			num_repetitions = getopt_integer(optarg);
			break;
		case 'c':
			config.chunk_size = (uint64_t) getopt_integer(optarg);
			break;
		case 't':
			config.ttc_chunk_size = (uint64_t) getopt_integer(optarg);
			break;
		case 'b':
			config.buffer_size = ((long unsigned) getopt_integer(optarg)) * 1024 * 1024;
			break;
		case 'e':
			config.max_events = ((long unsigned) getopt_integer(optarg));
			break;
		case 'z':
			config.dry_run = 1;
			break;
		case 'y':
			config.test_run = 1;
			break;
		case 'v':
			verbose = 1;
			break;
		case 'h':
		default:
			usage(argv[0]);
			exit(0);
			break;
		}
	}

	if ((infname == NULL) && !config.test_run) {
		printf("ERROR: no input file was provided\n");
		return -1;
	}

	config.num_links = 0;
	int optidx = 0;
	for (int i = optind; i < argc; i++) {
		if (config.num_links >= MAX_LINKS) {
			printf ("A maximum of %d links is supported, but more DMB IDs were given, truncating at %d\n", MAX_LINKS, MAX_LINKS);
			break;
		}
		if (optidx % 2 == 0) {
			config.crate_ids[config.num_links] = atoi(argv[i]);
		} else {
			config.dmb_ids[config.num_links] = atoi(argv[i]);
			config.num_links++;
		}
		optidx++;
	}

	if (verbose && !config.test_run) {
		printf("fname %s, size 0x%lx\n", infname, size);
		for (int i = 0; i < config.num_links; i++) {
			printf("LINK %d: Crate %d DMB %d\n", i, config.crate_ids[i], config.dmb_ids[i]);
		}
	}

	if (config.num_links == 0) {
		printf("ERROR: no link crate IDs and DMB IDs were provided, exiting..\n");
		return -1;
	}

	if (!config.dry_run) {
		rwreg_init("auto", 0);
	}

	read_fw_config(&config);

	if (config.num_links > config.max_links) {
		printf("ERROR: the number of links provided is more than the firmware can support. Max links supported by the firmware is %u\n", config.max_links);
		return -1;
	}

	ret = init_hw(&config);
	if (ret < 0) {
		return ret;
	}

	config.target_link_fifo_fill = (config.fifo_depths[0] / 4) * 3;
	config.target_ttc_fifo_fill = (config.ttc_fifo_depth / 4) * 3;

	if (config.target_link_fifo_fill % config.axi_width_words != 0) {
		printf("ERROR target link fifo fill rate %u is not divisible by axi width which is %u words", config.target_link_fifo_fill, config.axi_width_words);
		return -1;
	}
	if (config.target_ttc_fifo_fill % config.axi_width_words != 0) {
		printf("ERROR target TTC fifo fill rate %u is not divisible by axi width which is %u words", config.target_ttc_fifo_fill, config.axi_width_words);
		return -1;
	}
	if (config.target_link_fifo_fill % config.axi_width_words != 0) {
		printf("ERROR target link fifo fill rate %u is not divisible by axi width which is %u words", config.target_link_fifo_fill, config.axi_width_words);
		return -1;
	}

	printf("Firmware configuration:\n");
	printf("AXI width: %u\n", config.axi_width_words * 64);
	printf("TTC FIFO depth: %u, set target fill rate %u words\n", config.ttc_fifo_depth, config.target_ttc_fifo_fill);
	printf("TTC queue device: %s\n", config.ttc_dev_name);
	printf("Max links: %u\n", config.max_links);
	for (int i=0; i < config.max_links; i++) {
		uint32_t fill = (config.fifo_depths[i] / 4) * 3;
		if (config.target_link_fifo_fill > fill) {
			printf("ERROR: target link fill rate setting problem, check code.\n");
			return -1;
		}
		printf("    link %d: crate id %d, dmb id %d, width %u, fifo depth %u, set target fill rate %u words, queue device %s\n", i, config.crate_ids[i], config.dmb_ids[i], config.link_widths[i], config.fifo_depths[i], config.target_link_fifo_fill, config.link_dev_names[i]);
	}

	printf("\n\n");

	// test run
	if (config.test_run) {

		// test register access performance

		// reading link status, including event number
		const int REG_ACCESS_ITER = 100000;
		printf("Testing link status read performance...\n");
		struct LinkStatus link_status[config.num_links];
		clock_gettime(CLOCK_MONOTONIC, &ts_start);
		for (int i=0; i < REG_ACCESS_ITER; i++) {
			for (int link=0; link < config.num_links; link++) {
				read_link_status(link, &link_status[link], 1);
			}
		}
		clock_gettime(CLOCK_MONOTONIC, &ts_end);
		timespec_sub(&ts_end, &ts_start);
		long unsigned ns_per_status_read = (ts_end.tv_sec * NSEC_DIV + ts_end.tv_nsec) / (REG_ACCESS_ITER * config.num_links);
		printf("Took %lds and %luns to read status including event cnt of %d links %d times, average status read time: %luns\n\n", ts_end.tv_sec, ts_end.tv_nsec, config.num_links, REG_ACCESS_ITER, ns_per_status_read);

		// only reading the link status reg
		clock_gettime(CLOCK_MONOTONIC, &ts_start);
		uint32_t tmp;
		for (int i=0; i < REG_ACCESS_ITER; i++) {
			for (int link=0; link < config.num_links; link++) {
				read_link_status(link, &link_status[link], 0);
//				tmp = read_reg_gen(REG_LINK_FIFO_STATUS, 0) >> 16;
			}
		}
		clock_gettime(CLOCK_MONOTONIC, &ts_end);
		timespec_sub(&ts_end, &ts_start);
		ns_per_status_read = (ts_end.tv_sec * NSEC_DIV + ts_end.tv_nsec) / (REG_ACCESS_ITER * config.num_links);
		printf("Took %lds and %luns to read only status reg of %d links %d times, average status read time: %luns\n\n", ts_end.tv_sec, ts_end.tv_nsec, config.num_links, REG_ACCESS_ITER, ns_per_status_read);

		// send some events

		uint64_t* link_data;
		posix_memalign((void **) &link_data, 4096 /*alignment */ , 100*1024*1024 + 4096);
		uint64_t* link_write_ptr = link_data;
		uint64_t* link_read_ptr = link_data;

		uint64_t* ttc_data;
		posix_memalign((void **) &ttc_data, 4096 /*alignment */ , 10*1024*1024 + 4096);
		uint64_t* ttc_write_ptr = ttc_data;
		uint64_t* ttc_read_ptr = ttc_data;

		long unsigned dmb_size = 1;
		long unsigned axi_extra_words = dmb_size % config.axi_width_words;
		uint64_t orbit = 100;
		uint64_t fed_bx = 200;
		uint64_t fed_l1id = 1;
		int evt = 0;

		// TTC resync
		ttc_write_ptr[0] = ((uint64_t) 1) << 49;
		ttc_write_ptr++;

		for (evt=0; evt < 8000; evt++) {
			orbit += 1;
//			if (evt % 2 == 0) {
//				orbit++;
//			} else {
//				fed_bx++;
//			}
			fed_l1id++;
			link_write_ptr[0] = (((uint64_t) 0xbc) << 56) | (((uint64_t) 1) << 55) | ((axi_extra_words & 0x7) << 52) | ((orbit & 0xfffffff) << 24) | ((fed_bx & 0xfff) << 12) | (dmb_size & 0xfff);
			link_write_ptr[1] = 0x8000800080008000 | (fed_l1id & 0xfff) | ((fed_l1id & 0xfff000) << 4) | ((((uint64_t)fed_bx) & 0xfff) << 48);
			link_write_ptr += dmb_size + 1;
			while (axi_extra_words > 0) {
				link_write_ptr[0] = 0;
				link_write_ptr++;
				axi_extra_words--;
			}

			ttc_write_ptr[0] = (((uint64_t) 1) << 48) | ((orbit & 0xfffffff) << 20) | ((fed_bx & 0xfff) << 8);
			ttc_write_ptr++;
		}

		uint64_t link_words_left = link_write_ptr - link_read_ptr;
		uint64_t ttc_words_left = ttc_write_ptr - ttc_read_ptr;

		printf("Link words left: %lu\n", link_words_left);
		printf("TTC words left: %lu\n", ttc_words_left);

		clock_gettime(CLOCK_MONOTONIC, &ts_start);

//		printf("Sending:\n");
//		for (long i=0; i < 100; i++) {
//			printf("%ld: %016lx\n", i, link_data[i]);
//		}

		uint64_t link_words_sent = send_to_device(config.link_dev_names[0], config.link_dev_fds[0], &link_read_ptr, evt * 2 + 4000, &link_words_left);
		uint64_t ttc_words_sent = send_to_device(config.ttc_dev_name, config.ttc_dev_fd, &ttc_read_ptr, evt + 4000, &ttc_words_left);

		uint32_t data_cnt = 1;
		int num_reg_reads = 0;
		while (data_cnt > 0) {
			data_cnt = read_reg_gen(REG_LINK_FIFO_STATUS, 0) >> 16;
			num_reg_reads++;
		}

		clock_gettime(CLOCK_MONOTONIC, &ts_end);
		timespec_sub(&ts_end, &ts_start);
		double total_time = (ts_end.tv_sec + ((double)ts_end.tv_nsec/NSEC_DIV));
		printf("Took %.3fs (%lds and %luns) and %d status register reads to drain the FIFO\n\n", total_time, ts_end.tv_sec, ts_end.tv_nsec, num_reg_reads);

		printf("Link words sent: %lu\n", link_words_sent);
		printf("TTC words sent: %lu\n", ttc_words_sent);

		free(link_data);
		free(ttc_data);

		printf("Test data sent\n");

//		usleep(100000);

		for (int link=0; link < config.num_links; link++) {
			struct LinkStatus status;
			read_link_status(link, &status, 1);
			print_link_status(link, status);
		}
		struct TTCStatus status;
		read_ttc_status(&status);
		print_ttc_status(status);

		printf("DONE\n");

		return 0;
	}

	data = read_file_to_mem(infname, &num_words);
	if (data == NULL) {
		return -1;
	}

	if (print_raw_num_words > 0) {
		printf("sneak peak into the beginning of the file:\n");
	}
	long w = 0;
	if (print_non_empty) {
		while (w < num_words) {
			if ((data[w] >> 16 == 0x800000018000) && (data[w+1] & 0xf > 0)) {
				w--;
				break;
			}
			w++;
		}
	}
	for (long i=w; i < print_raw_num_words + w; i++) {
		printf("%ld: %016lx\n", i, data[i]);
	}

	// allocate the link data memory
	printf("Allocating memory for link data\n");
	long unsigned num_events = 0;
	long unsigned total_link_words[config.num_links];
	long unsigned total_ttc_words;
	struct Event* link_data[config.num_links];
	struct Event* ttc_data;

	for (int link=0; link < config.num_links; link++) {
		link_data[link] = (struct Event*) malloc(sizeof(struct Event) * config.max_events);
		posix_memalign((void **) &link_data[link][0].start_ptr, 4096 /*alignment */ , config.buffer_size + 4096);
		if (link_data[link][0].start_ptr == NULL) {
			printf("ERROR while allocating a buffer for link %d\n", link);
			goto clean;
		}
		printf("Allocated %luMB for link %d at address 0x%016lx\n", (config.buffer_size + 4096) / 1024 /1024, link, (uint64_t)link_data[link][0].start_ptr);
	}
	ttc_data = (struct Event*) malloc(sizeof(struct Event) * config.max_events);
	posix_memalign((void **) &ttc_data[0].start_ptr, 4096 /*alignment */ , config.max_events * sizeof(uint64_t) + 4096);
	if (ttc_data[0].start_ptr == NULL) {
		printf("ERROR while allocating a buffer for TTC data\n");
		goto clean;
	}
	printf("Allocated %luMB for TTC data at address 0x%016lx\n", (config.max_events * sizeof(uint64_t) + 4096) / 1024 /1024, (uint64_t)ttc_data[0].start_ptr);


	ret = process_data(config, data, num_words, num_repetitions, link_data, &num_events, total_link_words, ttc_data, &total_ttc_words, next_orbit);

	if (ret < 0) {
		printf("Exiting due to an error in file processing");
		goto clean;
	}
	printf("==== Processing DONE ====\n");
	printf("Number of events: %lu\n", num_events);
	for (int link=0; link < config.num_links; link++) {
		printf("Link %d buffer has %lu words\n", link, total_link_words[link]);
	}
	if ((ttc_data[num_events].start_ptr - ttc_data[0].start_ptr != num_events) || (total_ttc_words != num_events + 1)) {
		printf("ERROR: the first and last event TTC data pointers are not event_num apart from each other, or total_ttc_words is not equal to num_events + 1! Num events is %lu, total_ttc_words is %lu, last event pointer is 0x%016lx\n", num_events, total_ttc_words, (uint64_t)ttc_data[num_events - 1].start_ptr);
		goto clean;
	}
	printf("TTC buffer has %lu words\n", total_ttc_words);

	printf("==== Sending data to the device ====\n");
	send_to_board(config, link_data, num_events, total_link_words, ttc_data, total_ttc_words);

	printf("========================================================\n");
	printf("ALL DONE!\n");

clean:

	printf("\nCleaning up the memory and exiting...\n");
	// CLEANUP
	if (!config.test_run) {
		for (int link=0; link < config.num_links; link++) {
			if (link_data[link] != NULL && link_data[link][0].start_ptr != NULL) {
				printf("    - Freeing link buffer for link %d at address 0x%016lx\n", link, (uint64_t)link_data[link][0].start_ptr);
				free(link_data[link][0].start_ptr);
				printf("    - Freeing link metadata memory for link %d\n", link);
				free(link_data[link]);
			}
		}
		printf("    - Freeing TTC data buffer at address 0x%016lx\n", (uint64_t)ttc_data[0].start_ptr);
		free(ttc_data[0].start_ptr);
		printf("    - Freeing TTC metadata memory\n");
		free(ttc_data);

		printf("    - Freeing the raw data buffer\n");
		free(data);
	}

	if (!config.dry_run) {
		printf("    - Closing hardware resources\n");
		close_hw(&config);
		rwreg_close();
	}

	printf("    - All clear, have a good one!\n");
	return 0;

}
