#pragma once
#include <iostream>
#include <fstream>
#include "verilated_heavy.h"
#include "sim_console.h"

#define kVDNUM 10
#define kBLKSZ 512

struct SimBlockDevice {
public:

	IData* sd_lba[kVDNUM];
	SData* sd_rd;
	SData* sd_wr;
	SData* sd_ack;
	SData* sd_buff_addr;
	CData* sd_buff_dout;
	CData* sd_buff_din[kVDNUM];
	CData* sd_buff_wr;
	SData* img_mounted;
	CData* img_readonly;
	QData* img_size;

	int bytecnt;
	long int disk_size[kVDNUM];
	bool reading;
	bool writing;
	int ack_delay;
	int current_disk;
	bool mountQueue[kVDNUM];
	std::fstream disk[kVDNUM];

	void BeforeEval(int cycles);
	void AfterEval(void);
	void MountDisk( std::string file, int index);

	SimBlockDevice(DebugConsole c);
	~SimBlockDevice();

};
