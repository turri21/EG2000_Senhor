#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#define TAPE_HEADER "Colour Genie - Virtual Tape File"
static int cas_size;
static int level;

static int cgenie_handle_cas(const uint8_t *casdata, FILE *out)
{
	int data_pos, sample_count;

	data_pos = 0;
	sample_count = 0;
	level = 0;

	// Check for presence of optional header
	if (!memcmp(casdata, TAPE_HEADER, sizeof(TAPE_HEADER) - 1))
	{
	fprintf(stderr,"found tape header\n");
		// Search for 0x00 or end of file
		while (data_pos < cas_size && casdata[data_pos])
			data_pos++;
	fprintf(stderr,"found tape header\n");

		// If we're at the end of the file it's not a valid .cas file
		if (data_pos == cas_size)
			return -1;

		// Skip the 0x00 byte
		data_pos++;
	}

	// If we're at the end of the file it's not a valid .cas file
	if (data_pos == cas_size)
		return -1;

	// Check for beginning of tape file marker (possibly skipping the 0xaa header)
	if (casdata[data_pos] != 0x66 && casdata[data_pos + 0xff] != 0x66)
		return -1;

	// Create header, if not present in the file
	if (casdata[data_pos] == 0x66)
		for (int i = 0; i < 256; i++)
			fwrite(&casdata[data_pos],1,1,out);
			//sample_count += cgenie_output_byte(buffer, sample_count, 0xaa);

	// Start outputting data
	while (data_pos < cas_size)
	{
		//sample_count += cgenie_output_byte(buffer, sample_count, casdata[data_pos]);
		fwrite(&casdata[data_pos],1,1,out);
		data_pos++;
	}
	//sample_count += cgenie_output_byte(buffer, sample_count, 0x00);
	char data=0x00;
	fwrite(&data,1,1,out);

	return sample_count;
}

int main(int argc, char *argv[])
{
	if (argc<3)
	{
		fprintf(stderr,"usage %s <cas> <output>\n",argv[0]);
		exit(-1);
	}

	FILE *inFile = fopen(argv[1],"rb");
	FILE *outFile = fopen(argv[2],"wb");
	char casdata[1024*32];
	int res=fread(casdata,1,32*1024,inFile);
	cas_size=res;
	fprintf(stderr,"res = %d\n",res);
	fclose(inFile);
	cgenie_handle_cas(casdata,outFile);
	fclose(outFile);

	
}
