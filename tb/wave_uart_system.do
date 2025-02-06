onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider -height 31 {TB SIGNALS}
add wave -noupdate /hist_system_tb/clk
add wave -noupdate /hist_system_tb/reset
add wave -noupdate /hist_system_tb/pulse_out
add wave -noupdate /hist_system_tb/clk_fastest
add wave -noupdate /hist_system_tb/clk_slowest
add wave -noupdate /hist_system_tb/done
add wave -noupdate /hist_system_tb/i
add wave -noupdate /hist_system_tb/pulse_index
add wave -noupdate /hist_system_tb/pulse_start_time
add wave -noupdate /hist_system_tb/pulse_end_time
add wave -noupdate /hist_system_tb/prev_pulse_out
add wave -noupdate /hist_system_tb/UART_TX_TO_PC
add wave -noupdate /hist_system_tb/uart_tx_active
add wave -noupdate /hist_system_tb/uart_tx_done
add wave -noupdate /hist_system_tb/uart_rx_done
add wave -noupdate /hist_system_tb/UART_RX_FROM_PC
add wave -noupdate /hist_system_tb/UART_TX_TO_CTRL
add wave -noupdate /hist_system_tb/uart_tx_byte
add wave -noupdate /hist_system_tb/uart_rx_byte
add wave -noupdate /hist_system_tb/uart_start_tx
add wave -noupdate /hist_system_tb/rx_done_count
add wave -noupdate /hist_system_tb/file_handle
add wave -noupdate /hist_system_tb/pulse_values_file
add wave -noupdate -divider -height 31 {UART CONTROLLER}
add wave -noupdate /hist_system_tb/SYS_MOD/SYS/ctrl_blk/clk
add wave -noupdate /hist_system_tb/SYS_MOD/SYS/ctrl_blk/reset
add wave -noupdate /hist_system_tb/SYS_MOD/SYS/ctrl_blk/bram_reset_done
add wave -noupdate /hist_system_tb/SYS_MOD/SYS/ctrl_blk/UART_RX_FROM_PC
add wave -noupdate /hist_system_tb/SYS_MOD/SYS/ctrl_blk/UART_TX_TO_PC
add wave -noupdate -radix unsigned /hist_system_tb/SYS_MOD/SYS/ctrl_blk/histogram_bin_data
add wave -noupdate /hist_system_tb/SYS_MOD/SYS/ctrl_blk/start_sig_to_hist
add wave -noupdate /hist_system_tb/SYS_MOD/SYS/ctrl_blk/stop_sig_to_hist
add wave -noupdate /hist_system_tb/SYS_MOD/SYS/ctrl_blk/clear_sig_to_hist
add wave -noupdate -radix unsigned /hist_system_tb/SYS_MOD/SYS/ctrl_blk/address_to_hist
add wave -noupdate /hist_system_tb/SYS_MOD/SYS/ctrl_blk/uart_rx_done
add wave -noupdate /hist_system_tb/SYS_MOD/SYS/ctrl_blk/uart_tx_done
add wave -noupdate /hist_system_tb/SYS_MOD/SYS/ctrl_blk/uart_tx_active
add wave -noupdate -radix binary /hist_system_tb/SYS_MOD/SYS/ctrl_blk/uart_rx_byte
add wave -noupdate /hist_system_tb/SYS_MOD/SYS/ctrl_blk/uart_start_tx
add wave -noupdate -radix unsigned /hist_system_tb/SYS_MOD/SYS/ctrl_blk/uart_tx_byte
add wave -noupdate -radix unsigned /hist_system_tb/SYS_MOD/SYS/ctrl_blk/uart_ctrl_state
add wave -noupdate -radix unsigned /hist_system_tb/SYS_MOD/SYS/ctrl_blk/from_state_to_end_cmd
add wave -noupdate /hist_system_tb/SYS_MOD/SYS/ctrl_blk/uart_tx_state
add wave -noupdate -radix unsigned /hist_system_tb/SYS_MOD/SYS/ctrl_blk/data_to_transfer
add wave -noupdate /hist_system_tb/SYS_MOD/SYS/ctrl_blk/wait_cmd_state_attained
add wave -noupdate -radix unsigned /hist_system_tb/SYS_MOD/SYS/ctrl_blk/no_of_bins_to_read
add wave -noupdate -radix unsigned /hist_system_tb/SYS_MOD/SYS/ctrl_blk/current_bin_num
add wave -noupdate -radix unsigned /hist_system_tb/SYS_MOD/SYS/ctrl_blk/no_of_bins_to_read_minus_one
add wave -noupdate -radix unsigned /hist_system_tb/SYS_MOD/SYS/ctrl_blk/base_address_to_hist
add wave -noupdate /hist_system_tb/SYS_MOD/SYS/ctrl_blk/byte_counter
add wave -noupdate /hist_system_tb/SYS_MOD/SYS/ctrl_blk/byte_counter_start_value
add wave -noupdate /hist_system_tb/SYS_MOD/SYS/ctrl_blk/expected_final_byte_count_val
add wave -noupdate -radix unsigned /hist_system_tb/SYS_MOD/SYS/ctrl_blk/byte_setting_lsb
add wave -noupdate -divider -height 31 {PULSE GENERATOR}
add wave -noupdate /hist_system_tb/SYS_MOD/pwm_module/clk
add wave -noupdate /hist_system_tb/SYS_MOD/pwm_module/reset
add wave -noupdate /hist_system_tb/SYS_MOD/pwm_module/start
add wave -noupdate /hist_system_tb/SYS_MOD/pwm_module/stop
add wave -noupdate /hist_system_tb/SYS_MOD/pwm_module/pulse_out
add wave -noupdate /hist_system_tb/SYS_MOD/pwm_module/done_out
add wave -noupdate /hist_system_tb/SYS_MOD/pwm_module/w_LFSR_Data
add wave -noupdate /hist_system_tb/SYS_MOD/pwm_module/w_LFSR_Enable
add wave -noupdate /hist_system_tb/SYS_MOD/pwm_module/w_LFSR_Done
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {9380190000 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 170
configure wave -valuecolwidth 110
configure wave -justifyvalue left
configure wave -signalnamewidth 1
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ps
update
WaveRestoreZoom {0 ps} {10986118500 ps}
