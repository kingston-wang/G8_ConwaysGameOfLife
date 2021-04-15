`timescale 1 ns / 1 ps

	module ethernet_tx_hub #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line
	)
	(
		// Users to add ports here
		
		input wire [31:0] data_in, 
		output reg [31:0] data_out, 

		input wire [10:0] length, 
		
		output reg rx_read_valid,
		output reg rx_read_last,
		
		input wire tx_write_valid,
		output reg tx_write_ready,
		
		output reg start_single_write, 
		output reg start_single_read, 
		
		output reg [5:0] rx_src_id,	
		input wire [5:0] tx_dst_id,
		input wire [5:0] device_id,
		
		input wire interrupt, 
		
		// User ports ends
		// Do not modify the ports beyond this line


		// Ports of AXI Master Bus Interface M_AXI
		input wire        m_axi_aclk,
		input wire        m_axi_aresetn,

		output reg [12:0] m_axi_awaddr, 
		
		output reg [31:0] m_axi_wdata, 
		
		input wire [1:0]  m_axi_bresp,
		input wire        m_axi_bvalid,
		input wire        m_axi_bready,
		
		output reg [12:0] m_axi_araddr, 
		
		input wire [31:0] m_axi_rdata,
		input wire [1:0]  m_axi_rresp,
		input wire        m_axi_rvalid,
		input wire        m_axi_rready, 

		
		output reg [3:0] current_state,

		output reg [10:0] write_length,
		output reg [10:0] read_length,
	
		output reg [10:0] write_counter,
		output reg [12:0] read_counter, 
		
		output reg write_done,
		output reg read_done,
		
		output reg drop_frame
	);

	// Add user logic here
		
	reg [3:0] previous_state;
	//reg [3:0] current_state;
	reg [3:0] next_state;
	
	//reg [10:0] write_length;
	//reg [10:0] read_length;
	
	//reg [10:0] write_counter;
	//reg [12:0] read_counter;
	
	reg write_done_reg;
	reg read_done_reg;
	//reg write_done;
	//reg read_done;
	
	reg state_trans;
	//reg drop_frame;
	reg aresetn;
	
	reg [10:0] length_reg;
	reg tx_write_valid_reg;

	localparam  GIE_ADDR        = 13'h07F8,
	
                TX_LENGTH_ADDR  = 13'h07F4,
				TX_CONTROL_ADDR = 13'h07FC,
				
				RX_CONTROL_ADDR = 13'h17FC, 
				
				RX_FRAME_ADDR   = 13'h1000;

    localparam  RESET_PROGRAM_ADDR_1 = 4'h0,
                RESET_PROGRAM_ADDR_2 = 4'h1,
				
				RESET_WRITE_TX_CTRL  = 4'h2,
				RESET_POLL_TX_CTRL   = 4'h3,
				
				RESET_WRITE_RX_CTRL  = 4'h4,
                RESET_WRITE_GIE      = 4'h5,
				
                RX_READ_DATA         = 4'h6,
				RX_WRITE_CTRL        = 4'h7,
				
				RX_POLL              = 4'h8,
				RX_IDLE              = 4'h9,
				
                TX_WRITE_DATA        = 4'hA,
				TX_WRITE_LENGTH      = 4'hB, 
				TX_WRITE_CTRL        = 4'hC;

	always@(*)
    begin: state_table
        case (current_state)
			RESET_PROGRAM_ADDR_1: next_state = (write_done) ? RESET_PROGRAM_ADDR_2 : RESET_PROGRAM_ADDR_1;
			RESET_PROGRAM_ADDR_2: next_state = (write_done) ? RESET_WRITE_TX_CTRL  : RESET_PROGRAM_ADDR_2;
			RESET_WRITE_TX_CTRL:  next_state = (write_done) ? RESET_POLL_TX_CTRL  : RESET_WRITE_TX_CTRL;

			RESET_POLL_TX_CTRL:   next_state = (read_done && ~m_axi_rdata[1] && ~m_axi_rdata[0]) ? 
													RESET_WRITE_RX_CTRL : RESET_POLL_TX_CTRL;
		
			RESET_WRITE_RX_CTRL:  next_state = (write_done) ? RESET_WRITE_GIE : RESET_WRITE_RX_CTRL;
			RESET_WRITE_GIE:      next_state = (write_done) ? RX_POLL : RESET_WRITE_GIE;
			
			RX_READ_DATA:         next_state = ((read_length == 11'd0) || drop_frame) ? RX_WRITE_CTRL : RX_READ_DATA;
			RX_WRITE_CTRL:        next_state = (write_done) ? RX_POLL : RX_WRITE_CTRL;
			
			RX_POLL: begin
				if (read_done) begin
					if (m_axi_rdata[0])
						next_state = RX_READ_DATA;
					else
						next_state = RX_IDLE;
				end
				else
					next_state = RX_POLL;
			end
			RX_IDLE: begin
				if (tx_write_valid)
					next_state = TX_WRITE_DATA;
				else
					next_state = RX_POLL;
			end
			
			TX_WRITE_DATA:        next_state = (write_length == 11'd0) ? TX_WRITE_LENGTH : TX_WRITE_DATA;
			TX_WRITE_LENGTH:      next_state = (write_done) ? TX_WRITE_CTRL : TX_WRITE_LENGTH;
			TX_WRITE_CTRL:        next_state = (write_done) ? RX_POLL : TX_WRITE_CTRL;
        endcase
    end
	
    always @(*)
    begin: enable_signals
	
		state_trans = (previous_state != current_state);
		
		write_done  = m_axi_bvalid && m_axi_bready;
		read_done   = m_axi_rvalid && m_axi_rready;
		
		tx_write_ready = 1'b0;
		
		rx_read_valid  = 1'b0;
		rx_read_last   = 1'b0;
	
		start_single_read  = 1'b0;
		start_single_write = 1'b0;
		
		m_axi_araddr = 13'd0;
		m_axi_awaddr = 13'd0;
		m_axi_wdata  = 32'd0;
	
		case (current_state)
			RESET_PROGRAM_ADDR_1: begin
				if (~aresetn && m_axi_aresetn) start_single_write = 1'b1;
				m_axi_awaddr = 13'h0000;
				m_axi_wdata  = 32'h0035_0a00;
			end
			RESET_PROGRAM_ADDR_2: begin
				if (state_trans) start_single_write = 1'b1;
				m_axi_awaddr = 13'h0004;
				m_axi_wdata  = {16'h0, 2'd0, device_id, 8'h0};
			end
			RESET_WRITE_TX_CTRL: begin
				if (state_trans) start_single_write = 1'b1;
				m_axi_awaddr = TX_CONTROL_ADDR;
				m_axi_wdata  = 32'h0000_000B;
			end
			RESET_POLL_TX_CTRL: begin
				if (state_trans || (read_done_reg && ~read_done)) start_single_read = 1'b1;
				m_axi_araddr = TX_CONTROL_ADDR;
			end
			RESET_WRITE_RX_CTRL: begin
				if (state_trans) start_single_write = 1'b1;
				m_axi_awaddr = RX_CONTROL_ADDR;
				m_axi_wdata  = 32'h0000_0008;
			end
			RESET_WRITE_GIE: begin
				if (state_trans) start_single_write = 1'b1;
				m_axi_awaddr = GIE_ADDR;
				m_axi_wdata  = 32'h8000_0000;
			end
			RX_POLL: begin
				if (state_trans) start_single_read = 1'b1;
				m_axi_araddr = RX_CONTROL_ADDR;
			end
			RX_READ_DATA: begin
				if (state_trans)
					start_single_read = 1'b1;
				else if (read_done_reg && (read_length > 11'd0) && ~drop_frame)
					start_single_read = 1'b1;
				
				m_axi_araddr = {19'd0, read_counter};
				
				if (read_counter > 13'h100C) begin
					rx_read_valid = read_done_reg;
					if (read_length == 11'd0)
						rx_read_last = read_done_reg;
				end
			end
			RX_WRITE_CTRL: begin
				if (state_trans) start_single_write = 1'b1;
				m_axi_awaddr = RX_CONTROL_ADDR;
				m_axi_wdata  = 32'h0000_0008;
			end
			TX_WRITE_DATA: begin
				if (state_trans || (write_done_reg && write_length > 11'd0)) start_single_write = 1'b1;
				m_axi_awaddr = {21'd0, write_counter};
				
				case (write_counter)
					11'h000: m_axi_wdata = 32'h0035_0a00;
					11'h004: m_axi_wdata = {16'h0a00, 2'd0, tx_dst_id, 8'h00};
					11'h008: m_axi_wdata = {2'd0, device_id, 24'h00_0035};
					default: m_axi_wdata = data_in;
				endcase
				
				if (write_counter > 11'h00C)
					tx_write_ready = write_done_reg;
			end
			TX_WRITE_LENGTH: begin
				if (state_trans) start_single_write = 1'b1;
				m_axi_awaddr = TX_LENGTH_ADDR;
				m_axi_wdata  = {21'd0, length_reg}; // Hmm...
			end
			TX_WRITE_CTRL: begin
				if (state_trans) start_single_write = 1'b1;
				m_axi_awaddr = TX_CONTROL_ADDR;
				m_axi_wdata  = 32'h0000_0009;
			end
		endcase
	end
	
	always @(posedge m_axi_aclk) begin
		if (read_done) begin
			if (current_state == RX_READ_DATA) begin				
				case (read_counter)
					13'h1000: begin
						if (m_axi_rdata != 32'h0035_0a00)
							drop_frame <= 1'b1;
					end
					13'h1004: begin
						if (m_axi_rdata[15:0] != {2'd0, device_id, 8'h0})
							drop_frame <= 1'b1;
					end
					13'h1008: rx_src_id <= m_axi_rdata[29:24];
					default:  data_out  <= m_axi_rdata;
				endcase
				
				case (read_counter)
					13'h100C: read_length <= {m_axi_rdata[2:0], m_axi_rdata[15:8]} - 11'd16;
					default:  read_length <= read_length - 11'd4;
				endcase
			end
		end
		else if (current_state == RX_POLL) begin
			read_length <= 11'd16;				
			drop_frame  <= 1'b0;
		end
	end
	
	always @(posedge m_axi_aclk) begin
		if (read_done) begin
			if (current_state == RX_READ_DATA) begin
				read_counter <= read_counter + 13'd4;
			end
		end
		else if (current_state == RX_POLL) begin
			read_counter <= RX_FRAME_ADDR;
		end
	
		if (write_done) begin
			if (current_state == TX_WRITE_DATA) begin
				write_length  <= write_length  - 11'd4;
				write_counter <= write_counter + 11'd4;
			end
		end
		else if (~tx_write_valid_reg && tx_write_valid) begin
			length_reg    <= length;
			write_length  <= length;
			write_counter <= 11'd0;
		end
	end
    
    always @(posedge m_axi_aclk)
    begin: state_FFs
        if (~m_axi_aresetn) current_state <= RESET_PROGRAM_ADDR_1;
        else current_state <= next_state;
        
        previous_state <= current_state;
		
		write_done_reg <= write_done;
		read_done_reg  <= read_done;
		aresetn <= m_axi_aresetn;
		
		tx_write_valid_reg <= tx_write_valid;
    end

	// User logic ends

	endmodule