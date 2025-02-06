import serial
import serial.tools.list_ports
import matplotlib.pyplot as plt
import numpy as np
import time
import csv

# Global variables for number of bins
num_bins = 512  # 16-bit value split into MSB and LSB

# command definitions
command_names = {
    255: "END_COMMAND",
    2: "START_HIST",
    3: "STOP_HIST",
    4: "CLEAR_RESULTS",
    5: "START_UPLOAD",
    6: "SET_BINADDR",
    7: "SET_NUMBINS",
}

command_numbers = {v: k for k, v in command_names.items()}

# Function to list available serial ports
def list_serial_ports():
    ports = serial.tools.list_ports.comports()
    return [port.device for port in ports]

# Function to send a command via UART
def send_command(serial_connection, command_name):
    command_number = command_numbers.get(command_name, None)
    if command_number is None:
        print(f"Unknown command: {command_name}")
        return
    serial_connection.write(bytes([command_number]))
    print(f"Sending command: {command_name}")

# Function to send a byte of data over UART
def send_data_byte(serial_connection, data_byte):
    serial_connection.write(bytes([data_byte]))
    print(f"Sending Byte: {data_byte}")

# Function to wait for clocks (simulated delay)
def wait_clocks_hist(clock_cycles):
    time.sleep(clock_cycles * 0.01)  # Adjust delay as needed

# Function to wait specifically for CMD_END_COMMAND
def wait_for_end_command(serial_connection):
    while True:
        if serial_connection.in_waiting >= 1:
            response = serial_connection.read(1)  # Read a single byte
            if response[0] == command_numbers.get("END_COMMAND"):
                print("Received CMD_END_COMMAND.")
                break

# Function to sample responses
def sample_responses(serial_connection, num_expected=3):
    responses = []
    start_time = time.time()  # Start timing
    while len(responses) < num_expected:
        if serial_connection.in_waiting >= 1:
            response = serial_connection.read(1)  # Read a single byte
            responses.append(response[0])  # Append the byte value
            #print(f"Received response byte: {response[0]}")
    end_time = time.time()  # End timing
    elapsed_time = end_time - start_time
    print(f"Time taken to receive {num_expected} responses: {elapsed_time:.3f} seconds")
    return responses, elapsed_time

# Function to calculate expected transfers
def calculate_expected_transfers():
    # 2 bytes for each bin (address bytes) plus 1 byte for END_COMMAND.
    total_transfers = 1 + (num_bins * 2)
    print(f"Calculated expected transfers: {total_transfers}")
    return total_transfers

# Drive functions for specific commands
def drive_stop_hist(serial_connection):
    send_command(serial_connection, command_names.get(3))
    wait_clocks_hist(50)
    send_command(serial_connection, command_names.get(255))
    wait_for_end_command(serial_connection)

def drive_start_hist(serial_connection):
    send_command(serial_connection, command_names.get(2))
    wait_clocks_hist(50)
    send_command(serial_connection, command_names.get(255))
    wait_for_end_command(serial_connection)

def drive_start_data_upload(serial_connection):
    expected_transfers = calculate_expected_transfers()
    wait_clocks_hist(10)
    send_command(serial_connection, command_names.get(5))
    send_command(serial_connection, command_names.get(255))
    responses, elapsed_time = sample_responses(serial_connection, num_expected=expected_transfers)
    #wait_for_end_command(serial_connection)
    return responses, elapsed_time

def drive_clear_results(serial_connection):
    send_command(serial_connection, command_names.get(4))
    wait_clocks_hist(50)
    send_command(serial_connection, command_names.get(255))
    wait_for_end_command(serial_connection)

def drive_set_num_bins(serial_connection, num_bins_byte_lsb, num_bins_byte_msb):
    global num_bins
    num_bins = (num_bins_byte_msb << 8) | num_bins_byte_lsb
    send_command(serial_connection, command_names.get(7))
    wait_clocks_hist(50)
    send_data_byte(serial_connection, num_bins_byte_lsb)
    wait_clocks_hist(50)
    send_data_byte(serial_connection, num_bins_byte_msb)
    wait_clocks_hist(50)
    send_command(serial_connection, command_names.get(255))
    wait_for_end_command(serial_connection)

def drive_set_address(serial_connection, bin_address_byte_lsb, bin_address_byte_msb):
    send_command(serial_connection, command_names.get(6))
    wait_clocks_hist(50)
    send_data_byte(serial_connection, bin_address_byte_lsb)
    wait_clocks_hist(50)
    send_data_byte(serial_connection, bin_address_byte_msb)
    wait_clocks_hist(50)
    send_command(serial_connection, command_names.get(255))
    wait_for_end_command(serial_connection)

# Function to initialize UART connection
def initialize_uart(port, baud_rate=115200, timeout=1):
    try:
        ser = serial.Serial(port=port, baudrate=baud_rate, timeout=timeout)
        print(f"Connected to {port}.")
        return ser
    except serial.SerialException as e:
        print(f"Error: {e}")
        return None

# Function to display and select a serial port
def select_serial_port():
    print("Available serial ports:")
    ports = list_serial_ports()
    for i, port in enumerate(ports):
        print(f"{i}: {port}")

    if not ports:
        print("No serial ports available.")
        return None

    port_index = int(input("Select the serial port index: "))
    return ports[port_index]

# function to plot the histograms
def plot_histograms(all_hist_data):
    rows = 1

    fig, ax = plt.subplots(figsize=(6, 3))  # Single plot case
    ax.bar(range(512), all_hist_data[0], label=f'', width=1.0, align='center')
    ax.set_title(f'Histogram Data')
    ax.set_xlabel('Bins')
    ax.set_ylabel('Counts')
    ax.set_xticks(range(0, 512, 50))  # Set discrete x-ticks
    ax.legend()
    
    plt.tight_layout()
    plt.show()

def save_hist_data_to_csv(all_hist_data, filename="histogram_data.csv"):
    with open(filename, mode='w', newline='') as file:
        writer = csv.writer(file)
        for row in zip(*all_hist_data):  # Transpose data for correct formatting
            writer.writerow(row)
    print(f"Histogram data saved to {filename}")

def collect_hist_data(serial_connection):
    all_hist_data = []
    all_hist_raw_data = []
    all_elapsed_time = 0
    wait_clocks_hist(10)
    hist_data, elapsed_time = drive_start_data_upload(serial_connection)  # Retrieve histogram data
    all_hist_raw_data.append(hist_data)
        
    # Ignore last (END_COMMAND) bytes
    hist_data = hist_data[0:-1]
        
    # Merge LSB and MSB bytes into 16-bit values
    merged_hist_data = [(hist_data[i] | (hist_data[i+1] << 8)) for i in range(0, len(hist_data), 2)]
    all_elapsed_time += elapsed_time
    all_hist_data.append(merged_hist_data)
    wait_clocks_hist(500)
    save_hist_data_to_csv(all_hist_data)
    save_hist_data_to_csv(all_hist_raw_data, "histogram_raw_data.csv")
    print(f"Time taken to receive responses from requested bins: {all_elapsed_time:.3f} seconds")
    return all_hist_data

# Main function to test UART commands
def main():
    # Select port
    selected_port = select_serial_port()
    if not selected_port:
        return

    # Initialize UART
    ser = initialize_uart(selected_port)
    if not ser:
        return

    try:
        # Example test sequence
        drive_start_hist(ser)
        wait_clocks_hist(3000)
        drive_stop_hist(ser)
        drive_set_num_bins(ser, 0, 2)
        drive_set_address(ser, 0, 0)
        wait_clocks_hist(10)

        # Collect histogram data
        all_hist_data = collect_hist_data(ser)
        
        # Plot histograms
        plot_histograms(all_hist_data)
    finally:
        ser.close()
        print("Serial connection closed.")

if __name__ == "__main__":
    main()