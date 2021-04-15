`timescale 1 ns / 1 ps

	module ethernet_adapter #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line
	)
	(
		// Users to add ports here
		
		input wire [5:0]  vio_data_in, 	
		output reg [31:0] vio_data_out, 
		
		input wire        vio_data_en, 
		input wire [3:0]  vio_data_sel, 

		input wire [9:0]  local_cell_states, 
		output reg [9:0]  remote_cell_states,
		
		output reg [31:0] data_in, 
		input wire [31:0] data_out, 
		
		input wire step_flag, 
		output reg push_done, 

		input wire rx_read_valid,
		input wire rx_read_last,

		output reg tx_write_valid,
		input wire tx_write_ready, 
		
		input wire [5:0] rx_src_id, 
		output reg [5:0] tx_dst_id, 
		output reg [5:0] device_id, 
				
		output reg [10:0] length,
		
		output reg [3:0] current_state,
		output reg [7:0] tx_list,
		
		output reg [7:0] ack_pending,

	    output reg resp_pending,
		
		output reg resp_accepted,
		
		output reg [7:0] ack_num, 
		output reg [7:0] seq_num, 

		
		// User ports ends
		// Do not modify the ports beyond this line
		
		input wire m_axi_aclk,
		input wire m_axi_aresetn
	);

	// Add user logic here
		
	reg [9:0] local_cell_states_reg;
	reg [9:0] local_cell_states_reg2;
		
	reg [3:0] previous_state;
	//reg [3:0] current_state;
	reg [3:0] next_state;
	
	reg [10:0] write_counter;
	reg [10:0] read_counter;

	//reg [7:0] ack_pending;

	//reg resp_pending;
	
	reg aresetn;
	
	reg step_flag_reg;
	reg push_done_reg;
	
	reg [31:0] stopwatch;
	
	reg [31:0] timer_1;
	reg [31:0] timer_2;
	reg [31:0] timer_3;
	reg [31:0] timer_4;
	reg [31:0] timer_5;
	reg [31:0] timer_6;
	reg [31:0] timer_7;
	reg [31:0] timer_8;
	
	reg [7:0] timeout;
	
	reg [5:0] neighbour_1;
	reg [5:0] neighbour_2;
	reg [5:0] neighbour_3;
	reg [5:0] neighbour_4;
	reg [5:0] neighbour_5;
	reg [5:0] neighbour_6;
	reg [5:0] neighbour_7;
	reg [5:0] neighbour_8;
	
	reg [5:0] ack_id;
	//reg [7:0] ack_num;
	
	//reg [7:0] tx_list;
	
	//reg [7:0] seq_num;
	
	//reg resp_accepted;
	
	// temporary
	always @(posedge m_axi_aclk) begin
		if (~m_axi_aresetn) begin
			local_cell_states_reg2 <= 10'd0;
			local_cell_states_reg  <= 10'd0;
		end
		else if (~step_flag_reg && step_flag) begin
			local_cell_states_reg2 <= local_cell_states_reg;
			local_cell_states_reg  <= local_cell_states;
		end
	end
	
    localparam  TX_IDLE = 4'h0,
				TX_ACK  = 4'h1,
				TX_PULL = 4'h2;
				
	always@(*)
    begin: state_table
        case (current_state)
			TX_ACK:  next_state = (tx_write_ready && (write_counter == length)) ? TX_IDLE : TX_ACK;
			TX_PULL: next_state = (tx_write_ready) ? TX_IDLE : TX_PULL;
			
			default: begin
				if (resp_pending)
					next_state = TX_ACK;
				else if (|tx_list || |timeout)
					next_state = TX_PULL;
				else
					next_state = TX_IDLE;
			end
        endcase
    end
	
    always @(*)
    begin: enable_signals
	
		tx_write_valid = (current_state != TX_IDLE);
		
		if (current_state == TX_ACK) begin
		
			// temporary
			case (write_counter)
				11'h10: data_in = {ack_num, 8'h1, length[7:0], 5'h00, length[10:8]};
				
				// temporary: 
				11'h14: begin
					if ((ack_num - 8'h2) == seq_num) 
						data_in = {22'h123456, local_cell_states_reg2[9:0]};
					else
						data_in = {22'h123456, local_cell_states_reg[9:0]};
				end
				
				// TODO: for debugging only
				default: data_in = 32'h1234_5678;
			endcase
		end
		else if (current_state == TX_PULL)
			data_in = {seq_num, 8'h0, length[7:0], 5'h00, length[10:8]};
		else
			data_in = 32'h1234_5678;

		case (current_state)
			TX_PULL: begin
				length = 11'h10;
				
				if (tx_list[0] || timeout[0])
					tx_dst_id = neighbour_1;
				else if (tx_list[1] || timeout[1])
					tx_dst_id = neighbour_2;
				else if (tx_list[2] || timeout[2])
					tx_dst_id = neighbour_3;
				else if (tx_list[3] || timeout[3])
					tx_dst_id = neighbour_4;
				else if (tx_list[4] || timeout[4])
					tx_dst_id = neighbour_5;
				else if (tx_list[5] || timeout[5])
					tx_dst_id = neighbour_6;
				else if (tx_list[6] || timeout[6])
					tx_dst_id = neighbour_7;
				else if (tx_list[7] || timeout[7])
					tx_dst_id = neighbour_8;			
			end
			TX_ACK: begin
				length = 11'h14;
				tx_dst_id = ack_id;
			end
			default: begin
				length = 11'h0;
				tx_dst_id = 6'h0;
			end
		endcase
	end	
    
    always @(posedge m_axi_aclk)
    begin: state_FFs
        if (~m_axi_aresetn) current_state <= TX_IDLE;
        else current_state <= next_state;
        
        previous_state <= current_state;
		aresetn <= m_axi_aresetn;
		
		if (~m_axi_aresetn)
			seq_num <= 8'd0;
		else if (~push_done_reg && push_done)
			seq_num <= seq_num + 8'd1;
		else if (~step_flag_reg && step_flag)
			seq_num <= seq_num + 8'd1;
    end

	always @(posedge m_axi_aclk) begin
		if (~m_axi_aresetn || rx_read_last)
			read_counter <= 11'd0;
        else if (rx_read_valid)
			read_counter <= read_counter + 11'd4;
			
		if (~m_axi_aresetn || (current_state == TX_IDLE))
			write_counter <= 11'h10;
		else if (tx_write_ready)
			write_counter <= write_counter + 11'd4;

		if (~m_axi_aresetn) begin
			resp_accepted <= 1'b0;
			ack_id  <= 6'h0;
			ack_num <= 8'h0;
			remote_cell_states <= 10'd0;
		end
		else if (rx_read_valid) begin
			case (read_counter)
				11'h000: begin
					if (data_out[23:16] == 8'h1) begin
						if (data_out[31:24] == seq_num)
							resp_accepted <= 1'b1;
						else
							resp_accepted <= 1'b0;
					end
					else begin
						if (data_out[31:24] <= seq_num) begin
							ack_id  <= rx_src_id;
							ack_num <= data_out[31:24];
						end
					end
				end
				11'h004: begin
					
					// temporary: network byte order
					if (resp_accepted)
						remote_cell_states[9:0] <= data_out[9:0];
				end
			endcase
		end
		
		if (~m_axi_aresetn || (rx_read_valid && (read_counter == 11'h000) && (data_out[23:16] == 8'h1) && (rx_src_id == neighbour_1) && (data_out[31:24] == seq_num)))
			ack_pending[0] <= 1'b0;
		else if ((current_state == TX_PULL) && (next_state == TX_IDLE) && (tx_dst_id == neighbour_1))
			ack_pending[0] <= 1'b1;
			
		ack_pending[7:1] <= 7'b0;
			
		/*
		if (~m_axi_aresetn || (rx_read_valid && (data_out[23:16] == 8'h0) && (rx_src_id == neighbour_2)))
			ack_pending[1] <= 1'b0;
		else if ((current_state == TX_PULL_2) && (next_state == TX_IDLE))
			ack_pending[1] <= 1'b1;
			
		if (~m_axi_aresetn || (rx_read_valid && (data_out[23:16] == 8'h0) && (rx_src_id == neighbour_3)))
			ack_pending[2] <= 1'b0;
		else if ((current_state == TX_PULL_3) && (next_state == TX_IDLE))
			ack_pending[2] <= 1'b1;
			
		if (~m_axi_aresetn || (rx_read_valid && (data_out[23:16] == 8'h0) && (rx_src_id == neighbour_4)))
			ack_pending[3] <= 1'b0;
		else if ((current_state == TX_PULL_4) && (next_state == TX_IDLE))
			ack_pending[3] <= 1'b1;
			
		if (~m_axi_aresetn || (rx_read_valid && (data_out[23:16] == 8'h0) && (rx_src_id == neighbour_5)))
			ack_pending[4] <= 1'b0;
		else if ((current_state == TX_PULL_5) && (next_state == TX_IDLE))
			ack_pending[4] <= 1'b1;
			
		if (~m_axi_aresetn || (rx_read_valid && (data_out[23:16] == 8'h0) && (rx_src_id == neighbour_6)))
			ack_pending[5] <= 1'b0;
		else if ((current_state == TX_PULL_6) && (next_state == TX_IDLE))
			ack_pending[5] <= 1'b1;
			
		if (~m_axi_aresetn || (rx_read_valid && (data_out[23:16] == 8'h0) && (rx_src_id == neighbour_7)))
			ack_pending[6] <= 1'b0;
		else if ((current_state == TX_PULL_7) && (next_state == TX_IDLE))
			ack_pending[6] <= 1'b1;
			
		if (~m_axi_aresetn || (rx_read_valid && (data_out[23:16] == 8'h0) && (rx_src_id == neighbour_8)))
			ack_pending[7] <= 1'b0;
		else if ((current_state == TX_PULL_8) && (next_state == TX_IDLE))
			ack_pending[7] <= 1'b1;
		*/
		
		
		// temporary
		if (~m_axi_aresetn || ((current_state == TX_ACK) && (next_state == TX_IDLE)))
			resp_pending <= 1'b0;
		else if (rx_read_valid && (read_counter == 11'h000) && (data_out[23:16] == 8'h0) && (data_out[31:24] <= seq_num)) 
			resp_pending <= 1'b1;
			
		step_flag_reg <= step_flag;
		push_done_reg <= push_done;
		
		if (~m_axi_aresetn || (~step_flag_reg && step_flag))
			push_done <= 1'b0;
		else if (~(|ack_pending) && ~(|tx_list)) // WRONG
			push_done <= 1'b1;
			
		// backup remote_cell_stetes
			
		if (~m_axi_aresetn)
			tx_list <= 8'h0;
		else if (~step_flag_reg && step_flag)
			tx_list <= 8'h1;
		else if ((current_state == TX_PULL) && (next_state == TX_IDLE)) begin			
			if (tx_dst_id == neighbour_1) tx_list[0] <= 1'b0;
			if (tx_dst_id == neighbour_2) tx_list[1] <= 1'b0;
			if (tx_dst_id == neighbour_3) tx_list[2] <= 1'b0;
			if (tx_dst_id == neighbour_4) tx_list[3] <= 1'b0;
			if (tx_dst_id == neighbour_5) tx_list[4] <= 1'b0;
			if (tx_dst_id == neighbour_6) tx_list[5] <= 1'b0;
			if (tx_dst_id == neighbour_7) tx_list[6] <= 1'b0;
			if (tx_dst_id == neighbour_8) tx_list[7] <= 1'b0;
		end
	
		if (~m_axi_aresetn || ~ack_pending[0] || ((current_state == TX_PULL) && (next_state == TX_IDLE) && (tx_dst_id == neighbour_1)))
			timer_1 <= 32'd0;
		else if (timeout[0])
			timer_1 <= timer_1;
		else
			timer_1 <= timer_1 + 32'd1;
			
		/*
		if (~m_axi_aresetn || ~ack_pending[1] || (timeout[1] && (current_state == TX_IDLE) && (next_state == TX_PULL_2)))
			timer_2 <= 32'd0;
		else if (timeout[1])
			timer_2 <= timer_2;
		else
			timer_2 <= timer_2 + 32'd1;
			
		if (~m_axi_aresetn || ~ack_pending[2] || (timeout[2] && (current_state == TX_IDLE) && (next_state == TX_PULL_3)))
			timer_3 <= 32'd0;
		else if (timeout[2])
			timer_3 <= timer_3;
		else
			timer_3 <= timer_3 + 32'd1;
			
		if (~m_axi_aresetn || ~ack_pending[3] || (timeout[3] && (current_state == TX_IDLE) && (next_state == TX_PULL_4)))
			timer_4 <= 32'd0;
		else if (timeout[3])
			timer_4 <= timer_4;
		else
			timer_4 <= timer_4 + 32'd1;
			
		if (~m_axi_aresetn || ~ack_pending[4] || (timeout[4] && (current_state == TX_IDLE) && (next_state == TX_PULL_5)))
			timer_5 <= 32'd0;
		else if (timeout[4])
			timer_5 <= timer_5;
		else
			timer_5 <= timer_5 + 32'd1;
			
		if (~m_axi_aresetn || ~ack_pending[5] || (timeout[5] && (current_state == TX_IDLE) && (next_state == TX_PULL_6)))
			timer_6 <= 32'd0;
		else if (timeout[5])
			timer_6 <= timer_6;
		else
			timer_6 <= timer_6 + 32'd1;
			
		if (~m_axi_aresetn || ~ack_pending[6] || (timeout[6] && (current_state == TX_IDLE) && (next_state == TX_PULL_7)))
			timer_7 <= 32'd0;
		else if (timeout[6])
			timer_7 <= timer_7;
		else
			timer_7 <= timer_7 + 32'd1;
			
		if (~m_axi_aresetn || ~ack_pending[7] || (timeout[7] && (current_state == TX_IDLE) && (next_state == TX_PULL_8)))
			timer_8 <= 32'd0;
		else if (timeout[7])
			timer_8 <= timer_8;
		else
			timer_8 <= timer_8 + 32'd1;
		*/
			
		// temporary
		if ((timer_1 != 32'd0) && ~ack_pending[0]) begin
			stopwatch <= timer_1;
		end
	end
	
	always @(*) begin
		timeout[0] = (timer_1 == 32'h0002_0000); // TODO: adjust timeout
		timeout[1] = 0; //(timer_2 == 32'h0002_0000);
		timeout[2] = 0; //(timer_3 == 32'h0002_0000);
		timeout[3] = 0; //(timer_4 == 32'h0002_0000);
		timeout[4] = 0; //(timer_5 == 32'h0002_0000);
		timeout[5] = 0; //(timer_6 == 32'h0002_0000);
		timeout[6] = 0; //(timer_7 == 32'h0002_0000);
		timeout[7] = 0; //(timer_8 == 32'h0002_0000);
	end
	
	always @(posedge m_axi_aclk) begin
		if (vio_data_en) begin
			case (vio_data_sel)
				4'h0: device_id   <= vio_data_in;
				4'h1: neighbour_1 <= vio_data_in;
				4'h2: neighbour_2 <= vio_data_in;
				4'h3: neighbour_3 <= vio_data_in;
				4'h4: neighbour_4 <= vio_data_in;
				4'h5: neighbour_5 <= vio_data_in;
				4'h6: neighbour_6 <= vio_data_in;
				4'h7: neighbour_7 <= vio_data_in;
				4'h8: neighbour_8 <= vio_data_in;
			endcase
		end
	end
	
	always @(*) begin
		case (vio_data_sel)
			4'h0: vio_data_out = current_state;
			4'h1: vio_data_out = next_state;
			4'h2: vio_data_out = read_counter;
			4'h3: vio_data_out = write_counter;
			4'h4: vio_data_out = stopwatch;
			4'h5: vio_data_out = remote_cell_states;
		endcase
	end

	// User logic ends

	endmodule
