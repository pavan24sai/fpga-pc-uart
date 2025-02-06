# UART Interface for FPGA <-> PC Communication

## Project Description
This project establishes a reliable UART-based communication channel between an FPGA and a PC. The FPGA executes real-time histogram computation on the widths of pulses generated by a Linear Feedback Shift Register (LFSR)-based pseudo-random pulse generator. The implementation is successfully deployed on an Altera DE-0 Nano (Cyclone IV) FPGA board.

## Implementation
![System Overview](./results/hist_uart_system.png?raw=true "System Overview")
The figure above illustrates the architecture of the system. Below is a description of the key modules:

### Pulse Generator
A pseudo-random pulse generator based on an LFSR, responsible for generating digital pulse sequences.

### Pulse Width Calculator (PWC)
Measures the widths of incoming digital pulses (in clock cycles) and transmits this data to the histogram computation module.

### Histogram Compute
Constructs a histogram by counting occurrences of various pulse widths. The computed histogram data is stored in on-chip memory (BRAM).

### UART Controller
Speaks \& Listens UART. Handles UART communication by decoding commands received from a Python application running on the PC and sending back the requested responses. The UART handshake protocol that is designed for this application is documented in [uart_handshake_spec](./doc/uart_handshake_spec.pdf) along with the necessary timing diagrams.

## Results
### Expected and Acquired Data
The following figures illustrate the expected pulse behavior and histogram, as well as the actual histogram acquired from the FPGA via UART.
#### Expected Pulse Behavior and Histogram
![Actual Pulses and Expected Histogram Contents](./results/Pulses_and_Expected_Histogram.png?raw=true "Actual Pulses and Expected Histogram Contents")

#### Acquired Histogram Data
![Actual Histogram Contents](./results/Histogram_Plot_Python.png?raw=true "Actual Histogram Contents")

### Simulation and Validation
The testbench file ([hist_system_tb.v](./tb/hist_system_tb.v)) includes a mechanism for logging the actual pulses and expected pulse width data during ModelSim simulation. This logged data serves as the golden reference for verifying FPGA-acquired data.

The UART log while running the python application ([uart_pc_script.py](./pc_uart_scripts/uart_pc_script.v)) on the PC is as follows:
```
Available serial ports:
0: COM8
1: COM11

Select the serial port index: 0
Connected to COM8.

Sending command: START_HIST
Sending command: END_COMMAND
Received END_COMMAND.

Sending command: STOP_HIST
Sending command: END_COMMAND
Received END_COMMAND.

Sending command: SET_NUMBINS
Sending Byte: 0
Sending Byte: 2
Sending command: END_COMMAND
Received END_COMMAND.

Sending command: SET_BINADDR
Sending Byte: 0
Sending Byte: 0
Received END_COMMAND.

Calculated expected transfers: 1025

Sending command: START_UPLOAD
Sending command: END_COMMAND

Time taken to receive 1025 responses: 0.090 seconds
Histogram data saved to histogram_data.csv
Histogram data saved to histogram_raw_data.csv

Time taken to receive responses from requested bins: 0.090 seconds
```
The overall time taken to transfer a total of 1K bytes of valid data is 0.9 seconds.

## References
[^1] [How a Linear Feedback Shift Register works inside of an FPGA](https://nandland.com/lfsr-linear-feedback-shift-register/)
[^2] [UART, Serial Port, RS-232 Interface](https://nandland.com/uart-serial-port-module/)