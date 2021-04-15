# G8_ConwaysGameOfLife

Conway’s Game of Life Hardware Accelerator

Repository structure
  G8_ConwaysGameOfLife

	README.bd

	src - Vivado project files

		conway_ddr - the project targeting Nexys DDR boards

			bd - block diagrams
				block_main.bd - block diagram

			hdl - Verilog files
				conway - RTL for Game of Life logic
					Conway_v6_S00_AXI.v - module definition for conway

				ethernet - RTL for ethernet modules
					ethernet_adapter.v - module definition for ethernet_wrapper
					ethernet_tx_hub.v - module definition for ethernet_rx_tx
					m_axi_interface.v - AXI master interface for ethernet_rx_tx

			sdk - files for the MicroBlaze
				test_uart.c - C code for controlling the progression of the game

		conway_video - the project targeting Nexys Video boards (same structure as conway_ddr, but with different block_main.bd and ethernet_tx_hub.v)

	pc - files for the PC
		conway_vis.py - Python code for UART connection and visualization on PC

	doc - reports and presentations
		final_report.pdf - this report

Authors: 
- Noah Poplove
- Zhe (Ryan) Yin
- Kingston (Ting Ray) Wang
