#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include "platform.h"
#include "xil_types.h"
#include "xil_printf.h"
#include "xuartLite.h"
#include "xil_exception.h"

#define COMMAND_SIZE 2
#define DATA_SIZE 10
#define DATA_WIDTH 3


volatile unsigned int* conway_base = (unsigned int*) XPAR_CONWAY_0_S00_AXI_BASEADDR;

void send_uart(XUartLite*, u8*,int);
int rec_uart(XUartLite*, u8*,int);

void print_bin(int);
void print_hex(int);
void print_hex3(int,int,int);
void print_hex5(int,int,int,int,int);

void run_step();
void write_row(int, int);
void write_edge(int);
void print_edge();
void print_grid();
void print_grid_hex();

int main()
{
	init_platform();
	u8 *data;
	u8 command=0;
	u32 status;
	XUartLite_Config *config;
	XUartLite uart;
	data = malloc(sizeof(u8)*DATA_SIZE);
	int recCount=0;

	// initialize uart connection
	config = XUartLite_LookupConfig(XPAR_AXI_UARTLITE_0_DEVICE_ID);
	status = XUartLite_CfgInitialize(&uart, config, XPAR_UARTLITE_0_BASEADDR);
	if (status != XST_SUCCESS){
		xil_printf("\n\rUART initialization failed\n\r");
		return 0;
	}
	xil_printf("\n\rUART initialization passed\n\r");

	// initialize grid with reset
	*(conway_base+0) = 0x00000000;

	while (1) {
		recCount = rec_uart(&uart,data,DATA_SIZE);
		//xil_printf("0recCount: %d\n\r",recCount);
		if (recCount == DATA_SIZE){
			for (int r = 0; r < DATA_SIZE-1; r++){
				//xil_printf("%c ",data[r]);
				write_row(r,data[r]-48);
			}
			print_grid();
			break;
		}
	}
	while (1){
		recCount = rec_uart(&uart,data,COMMAND_SIZE);
		if (recCount == COMMAND_SIZE){
			//xil_printf("1recCount: %d\n\r",recCount);
			run_step();
			print_grid();
		}
	}

	while (1) {

		if (command == 0){ // wait for command
			recCount = rec_uart(&uart,data,DATA_SIZE);
			if (recCount > 0){
				xil_printf("0recCount: %d\n\r",recCount);
				command = data[0]-48;
				xil_printf("\nFLAG 0->%d\n",command);
			}

		} else if (command == 1){ //step
			xil_printf("\nFLAG 0->%d\n",command);
			run_step();
			print_grid();
			xil_printf("done");
			command = 0;
		} else if (command == 2){ //write row
			for (int r = 0; r < DATA_SIZE-1; r++){
				write_row(r,data[r+1]-48);
			}
			print_grid();
			xil_printf("done");
			command = 0;

		}
		else{
			command = 0;
		}
	}



	xil_printf("\n%d\n",XUartLite_SelfTest(&uart));

	// initialize data
	for (int i = 0; i < DATA_SIZE; i++)
		data[i] = '0' + i;

	// main loop

	while (1) {
		if (recCount > 0){
			xil_printf("recCount: %d\n\r",recCount);
			for (int i = 0; i < DATA_SIZE; i++){
				xil_printf("%c ",data[i]);
				//data[i] = data[i] + 1;
			}
			send_uart(&uart,data,DATA_SIZE);
			for (int i = 0; i < DATA_SIZE; i++){
				//xil_printf("%d ",data[i]);
			}
		}
		//xil_printf("\n\r\n\rdone\n\r\n\r");
	}

	cleanup_platform();
	return 0;

}

void send_uart(XUartLite* uart,u8* data, int data_size){
	u8 sendCount=0;
	while (sendCount < data_size){
		sendCount += XUartLite_Send(uart, (u8*)&data[sendCount],1);
	}
	sleep(1);
	if (sendCount != data_size){
		return; // TODO: verify data was all sent
	}
	return;
}

int rec_uart(XUartLite* uart,u8* data,int data_size){
	int recCount=0;
	while (recCount < data_size){
		recCount += XUartLite_Recv(uart, (u8*)&data[recCount],1);
	}
	return recCount;
}

void print_grid(){
	int N = 10;
	for (int i = 0; i < N; i ++){
		*(conway_base+0) = 0x04 + 256*i;
		int a= *(conway_base+4);
		print_bin(a);
	}
	xil_printf("\n");
}

void print_grid_hex(){
	int N = 10;
	for (int i = 0; i < N; i ++){
		*(conway_base+0) = 0x04 + 256*i;
		int a= *(conway_base+4);
		print_hex(a);
	}
	xil_printf("\n");
}

void print_edge(){
	int a = *(conway_base+6);
	print_bin(a);
}

void write_row(int row, int val){
	int addr = 1 + 256*row;
	*(conway_base+0) = addr;
	*(conway_base+1) = val;
	*(conway_base+0) = addr;
}

void write_edge(int val){
	*(conway_base+0) = 0x00000005;
	*(conway_base+1) = val;
	*(conway_base+0) = 0x00000005;
}

void run_step(){
	*(conway_base+0) = 0x00000002;
}

void print_hex(int n){
	xil_printf("%08x\n",n);
}

void print_hex3(int a,int b, int c){
	xil_printf("\n%08x\n%08x\n%08x\n",a,b,c);
}

void print_bin(int n){
	int N = 10;
	int k;
	for (int i = N-1; i >=0; i--){
		k = n >> i;
		if (k & 1) xil_printf("1");
		else xil_printf("0");
	}
	xil_printf("\n");
}
