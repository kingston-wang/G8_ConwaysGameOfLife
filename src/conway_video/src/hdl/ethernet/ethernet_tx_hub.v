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

		output reg [31:0] m_axi_awaddr, 
		
		output reg [31:0] m_axi_wdata, 
		
		input wire [1:0]  m_axi_bresp,
		input wire        m_axi_bvalid,
		input wire        m_axi_bready,
		
		output reg [31:0] m_axi_araddr, 
		
		input wire [31:0] m_axi_rdata,
		input wire [1:0]  m_axi_rresp,
		input wire        m_axi_rvalid,
		input wire        m_axi_rready, 
		
		output reg [4:0] current_state,
	
		output reg [10:0] write_length,
		output reg [31:0] read_length,
	
		output reg [10:0] write_counter,
		output reg [10:0] read_counter,

		output reg write_done,
		output reg read_done,
	
		output reg drop_frame
	);

	// Add user logic here
		
	reg [4:0] previous_state;
	//reg [4:0] current_state;
	reg [4:0] next_state;
	
	//reg [10:0] write_length;
	//reg [31:0] read_length;
	
	//reg [10:0] write_counter;
	//reg [10:0] read_counter;
	
	reg [10:0] actual_length;

	reg write_done_reg;
	reg read_done_reg;
	//reg write_done;
	//reg read_done;
	
	reg state_trans;
	//reg drop_frame;
	reg aresetn;
	
	reg [10:0] length_reg;
	reg tx_write_valid_reg;
	
	localparam  ISR_ADDR  = 32'h0,
                IER_ADDR  = 32'h4,
				
				TDFR_ADDR = 32'h8,
				TDFV_ADDR = 32'hC,
				TDFD_ADDR = 32'h10,
				TLR_ADDR  = 32'h14,
				
				RDFR_ADDR = 32'h18,
				RDFO_ADDR = 32'h1C,
				RDFD_ADDR = 32'h20,
				RLR_ADDR  = 32'h24,
				
				TDR_ADDR  = 32'h2C,
				RDR_ADDR  = 32'h30;

    localparam  RESET_READ_ISR_1 = 5'h00,
                RESET_WRITE_ISR  = 5'h01,
				RESET_READ_ISR_2 = 5'h02, 
				RESET_WRITE_IER  = 5'h03, 
				RESET_READ_IER   = 5'h04, 
				RESET_READ_TDFV  = 5'h05, 
				RESET_READ_RDFO  = 5'h06, 
				
				RX_READ_ISR_1    = 5'h07,
                RX_WRITE_ISR     = 5'h08,
				RX_READ_ISR_2    = 5'h09, 
				RX_READ_IER      = 5'h0A, 
				RX_READ_RDFO     = 5'h0B, 
				RX_READ_RLR      = 5'h0C, 
				RX_READ_RDR      = 5'h0D, 
				RX_READ_RDFD     = 5'h0E, 
				
				RX_IDLE          = 5'h0F,
				
                TX_WRITE_TDR     = 5'h17,
				TX_WRITE_TDFD    = 5'h18, 
				TX_READ_TDFV_1   = 5'h19, 
				TX_WRITE_TLR     = 5'h1A, 
				TX_READ_ISR_1    = 5'h1B, 
				TX_WRITE_ISR     = 5'h1C, 
				TX_READ_ISR_2    = 5'h1D, 
				TX_READ_TDFV_2   = 5'h1E;
				
	always@(*)
    begin: state_table
        case (current_state)
			RESET_READ_ISR_1: next_state = (read_done)  ? RESET_WRITE_ISR   : RESET_READ_ISR_1;
			RESET_WRITE_ISR:  next_state = (write_done) ? RESET_READ_ISR_2  : RESET_WRITE_ISR;
			RESET_READ_ISR_2: next_state = (read_done)  ? RESET_WRITE_IER   : RESET_READ_ISR_2;
			RESET_WRITE_IER:  next_state = (write_done) ? RESET_READ_IER    : RESET_WRITE_IER;
			RESET_READ_IER:   next_state = (read_done)  ? RESET_READ_TDFV   : RESET_READ_IER;
			RESET_READ_TDFV:  next_state = (read_done)  ? RESET_READ_RDFO   : RESET_READ_TDFV;
			RESET_READ_RDFO:  next_state = (read_done)  ? RX_IDLE : RESET_READ_RDFO;
			
			RX_READ_ISR_1:    next_state = (read_done)  ? RX_WRITE_ISR      : RX_READ_ISR_1;			
			RX_WRITE_ISR:     next_state = (write_done) ? RX_READ_ISR_2     : RX_WRITE_ISR;
			RX_READ_ISR_2:    next_state = (read_done)  ? RX_READ_IER       : RX_READ_ISR_2;
			RX_READ_IER:      next_state = (read_done)  ? RX_READ_RDFO      : RX_READ_IER;
			RX_READ_RDFO:     next_state = (read_done)  ? RX_READ_RLR       : RX_READ_RDFO;
			RX_READ_RLR:      next_state = (read_done)  ? RX_READ_RDR       : RX_READ_RLR;
			RX_READ_RDR:      next_state = (read_done)  ? RX_READ_RDFD      : RX_READ_RDR;
			RX_READ_RDFD:     next_state = (read_length == 32'd0) ? RX_IDLE : RX_READ_RDFD;
			RX_IDLE: begin
				if (interrupt)
					next_state = RX_READ_ISR_1;
				else if (tx_write_valid)
					next_state = TX_WRITE_TDR;
				else
					next_state = RX_IDLE;
			end
			
			TX_WRITE_TDR:     next_state = (write_done) ? TX_WRITE_TDFD     : TX_WRITE_TDR;
			TX_WRITE_TDFD:    next_state = (write_length == 11'd0) ? TX_READ_TDFV_1 : TX_WRITE_TDFD;
			TX_READ_TDFV_1:   next_state = (read_done)  ? TX_WRITE_TLR      : TX_READ_TDFV_1;
			TX_WRITE_TLR:     next_state = (interrupt)  ? TX_READ_ISR_1     : TX_WRITE_TLR;
			TX_READ_ISR_1:    next_state = (read_done)  ? TX_WRITE_ISR      : TX_READ_ISR_1;
			TX_WRITE_ISR:     next_state = (write_done) ? TX_READ_ISR_2     : TX_WRITE_ISR;
			TX_READ_ISR_2:    next_state = (read_done)  ? TX_READ_TDFV_2    : TX_READ_ISR_2;
			TX_READ_TDFV_2:   next_state = (read_done)  ? RX_IDLE : TX_READ_TDFV_2;
        endcase
    end
	
    always @(*)
    begin: enable_signals
	
		state_trans = (previous_state != current_state);
		
		write_done  = m_axi_bvalid && m_axi_bready;
		read_done   = m_axi_rvalid && m_axi_rready;

		tx_write_ready   = 1'b0;
		
		rx_read_valid    = 1'b0;
		rx_read_last     = 1'b0;
	
		start_single_read  = 1'b0;
		start_single_write = 1'b0;
		
		m_axi_araddr = 32'd0;
		m_axi_awaddr = 32'd0;
		m_axi_wdata  = 32'd0;
	
		case (current_state)
			RESET_READ_ISR_1: begin
				if (~aresetn && m_axi_aresetn) start_single_read = 1'b1;
				m_axi_araddr = ISR_ADDR;
			end
			RESET_WRITE_ISR: begin
				if (state_trans) start_single_write = 1'b1;
				m_axi_awaddr = ISR_ADDR;
				m_axi_wdata  = 32'hFFFF_FFFF;
			end
			RESET_READ_ISR_2: begin
				if (state_trans) start_single_read = 1'b1;
				m_axi_araddr = ISR_ADDR;
			end
			RESET_WRITE_IER: begin
				if (state_trans) start_single_write = 1'b1;
				m_axi_awaddr = IER_ADDR;
				m_axi_wdata  = 32'h0C00_0000;
			end
			RESET_READ_IER: begin
				if (state_trans) start_single_read = 1'b1;
				m_axi_araddr = IER_ADDR;
			end
			RESET_READ_TDFV: begin
				if (state_trans) start_single_read = 1'b1;
				m_axi_araddr = TDFV_ADDR;
			end
			RESET_READ_RDFO: begin
				if (state_trans) start_single_read = 1'b1;
				m_axi_araddr = RDFO_ADDR;
			end
			RX_READ_ISR_1: begin
				if (state_trans) start_single_read = 1'b1;
				m_axi_araddr = ISR_ADDR;
			end
			RX_WRITE_ISR: begin
				if (state_trans) start_single_write = 1'b1;
				m_axi_awaddr = ISR_ADDR;
				m_axi_wdata  = 32'hFFFF_FFFF;
			end
			RX_READ_ISR_2: begin
				if (state_trans) start_single_read = 1'b1;
				m_axi_araddr = ISR_ADDR;
			end
			RX_READ_IER: begin
				if (state_trans) start_single_read = 1'b1;
				m_axi_araddr = IER_ADDR;
			end
			RX_READ_RDFO: begin
				if (state_trans) start_single_read = 1'b1;
				m_axi_araddr = RDFO_ADDR;
			end
			RX_READ_RLR: begin
				if (state_trans) start_single_read = 1'b1;
				m_axi_araddr = RLR_ADDR;
			end
			RX_READ_RDR: begin
				if (state_trans) start_single_read = 1'b1;
				m_axi_araddr = RDR_ADDR;
			end
			RX_READ_RDFD: begin	
				if (state_trans)
					start_single_read = 1'b1;
				else if (read_done_reg && (read_length > 32'd0))
					start_single_read = 1'b1;
				
				m_axi_araddr = RDFD_ADDR;
				
				if ((actual_length >= read_counter) && (read_counter > 11'hC) && ~drop_frame) begin
					rx_read_valid = read_done_reg;
					if (actual_length == read_counter)
						rx_read_last = read_done_reg;
				end
			end
			TX_WRITE_TDR: begin
				if (state_trans) start_single_write = 1'b1;
				m_axi_awaddr = TDR_ADDR;
				m_axi_wdata  = 32'h0000_0000; // Hmm...
			end
			TX_WRITE_TDFD: begin
				if (state_trans || (write_done_reg && write_length > 11'd0)) start_single_write = 1'b1;
				m_axi_awaddr = TDFD_ADDR;
				
				case (write_counter)
					11'h0: m_axi_wdata = 32'h0035_0a00;
					11'h4: m_axi_wdata = {16'h0a00, 2'd0, tx_dst_id, 8'h00};
					11'h8: m_axi_wdata = {2'd0, device_id, 24'h00_0035};
					default: m_axi_wdata = data_in;
				endcase
				
				if (write_counter > 11'hC)
					tx_write_ready = write_done_reg;				
			end
			TX_READ_TDFV_1: begin
				if (state_trans) start_single_read = 1'b1;
				m_axi_araddr = TDFV_ADDR;
			end
			TX_WRITE_TLR: begin
				if (state_trans) start_single_write = 1'b1;
				m_axi_awaddr = TLR_ADDR;				
				m_axi_wdata  = {21'd0, length_reg};
			end
			TX_READ_ISR_1: begin
				if (state_trans) start_single_read = 1'b1;
				m_axi_araddr = ISR_ADDR;
			end
			TX_WRITE_ISR: begin
				if (state_trans) start_single_write = 1'b1;
				m_axi_awaddr = ISR_ADDR;
				m_axi_wdata  = 32'hFFFF_FFFF;
			end
			TX_READ_ISR_2: begin
				if (state_trans) start_single_read = 1'b1;
				m_axi_araddr = ISR_ADDR;
			end
			TX_READ_TDFV_2: begin
				if (state_trans) start_single_read = 1'b1;
				m_axi_araddr = TDFV_ADDR;
			end
		endcase
	end
	
	always @(posedge m_axi_aclk) begin		
		if (read_done) begin
			if (current_state == RX_READ_RDFD) begin
				case (read_counter)
					11'h0: begin
						if (m_axi_rdata != 32'h0035_0a00)
							drop_frame <= 1'b1;
					end
					11'h4: begin
						if (m_axi_rdata[15:0] != {2'd0, device_id, 8'h0})
							drop_frame <= 1'b1;
					end
					11'h8: begin
						if (drop_frame == 1'b0)
							rx_src_id <= m_axi_rdata[29:24];
					end
					11'hC: begin
						if (drop_frame == 1'b0) begin
							data_out <= m_axi_rdata;
							
							actual_length <= {m_axi_rdata[7:0], m_axi_rdata[15:8]};
						end
					end
					default: begin
						if (drop_frame == 1'b0)
							data_out <= m_axi_rdata;
					end
				endcase
			end
		end
		else if (current_state == RX_IDLE) begin
			drop_frame <= 1'b0;
		end
	end
	
	always @(posedge m_axi_aclk) begin		
		if (read_done) begin
			if (current_state == RX_READ_RLR) begin
				if (m_axi_rdata[1:0] == 2'd0)
					read_length <= m_axi_rdata;
				else
					read_length <= {m_axi_rdata[31:2], 2'd0} + 32'd4;
				
				read_counter <= 11'd0;
			end
			else if (current_state == RX_READ_RDFD) begin
				read_length  <= read_length  - 32'd4;
				read_counter <= read_counter + 11'd4;
			end
		end
		
		if (write_done) begin
			if (current_state == TX_WRITE_TDFD) begin
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
        if (~m_axi_aresetn) current_state <= RESET_READ_ISR_1;
        else current_state <= next_state;
        
        previous_state <= current_state;
		
		write_done_reg <= write_done;
		read_done_reg  <= read_done;
		aresetn <= m_axi_aresetn;
		
		tx_write_valid_reg <= tx_write_valid;
    end

	// User logic ends

	endmodule
