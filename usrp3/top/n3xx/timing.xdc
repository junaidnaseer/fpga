#
# Copyright 2017 Ettus Research LLC
#


#*******************************************************************************
## Primary clock definitions

# Motherboard clocking
create_clock -name ref_clk             -period 100.000 -waveform {0.000 50.000}   [get_ports FPGA_REFCLK_P]
create_clock -name MGT156MHZ_CLK1      -period 6.400   -waveform {0.000 3.200}    [get_ports MGT156MHZ_CLK1_P]


# 125 MHz DB A & B Clocks
set SampleClockPeriod 8.00
create_clock -name DbaFpgaClk          -period $SampleClockPeriod  [get_ports DBA_FPGA_CLK_p]
create_clock -name DbbFpgaClk          -period $SampleClockPeriod  [get_ports DBB_FPGA_CLK_p]
create_clock -name USRPIO_A_MGTCLK     -period $SampleClockPeriod  [get_ports {USRPIO_A_MGTCLK_P}]
create_clock -name USRPIO_B_MGTCLK     -period $SampleClockPeriod  [get_ports {USRPIO_B_MGTCLK_P}]

# The Radio Clocks coming from the DBs are synchronized together (at the ADCs) to a
# typical value of less than 100ps. To give ourselves and Vivado some margin, we claim
# here that the DB-B Radio Clock can arrive 500ps before or after the DB-A clock at
# the FPGA (note that the trace lengths of the Radio Clocks coming from the DBs to the
# FPGA are about 0.5" different, thereby incurring ~80ps of additional skew at the FPGA).
# There is one spot in the FPGA where we cross domains between the DB-A and
# DB-B clock, so we must ensure that Vivado can analyze that path safely.
set FpgaClkBEarly -0.5
set FpgaClkBLate   0.5
set_clock_latency  -source -early $FpgaClkBEarly [get_clocks DbbFpgaClk]
set_clock_latency  -source -late  $FpgaClkBLate  [get_clocks DbbFpgaClk]

# Virtual clocks for constraining I/O (used below)
create_clock -name AsyncInClk  -period 50.00
create_clock -name AsyncOutClk -period 50.00
create_clock -name DbaFpgaClkV -period $SampleClockPeriod
create_clock -name DbbFpgaClkV -period $SampleClockPeriod

# The set_clock_latency constraints set on DbbFpgaClk are problematic when used with
# I/O timing, since the analyzer gives us a double-hit on the latency. One workaround
# (used here) is to simply swap the early and late times for the virtual clock so that
# it cancels out the source latency during analysis. I tested this by setting the
# early and late numbers to zero and then their actual value, running timing reports
# on each. The slack report matches for both cases, showing that the reversed early/late
# numbers on the virtual clock zero out the latency effects on the actual clock.
#
# Note this is not a problem for the DbaFpgaClk, since no latency is added. So only apply
# it to DbbFpgaClkV.
set_clock_latency  -source -early $FpgaClkBLate  [get_clocks DbbFpgaClkV]
set_clock_latency  -source -late  $FpgaClkBEarly [get_clocks DbbFpgaClkV]


# 125 MHz clock : RJ45
create_clock -period 8.000 -name ENET0_CLK125 -waveform {0.000 4.000} [get_ports ENET0_CLK125]
# 100 MHz sys clock for ddr mig
create_clock -period 10.000 -name sys_clk -waveform {0.000 5.000} [get_ports sys_clk_p]



#*******************************************************************************
## Aliases for auto-generated clocks

create_generated_clock -name radio_clk       [get_pins {dba_core/RadioClockingx/RadioClkMmcm/CLKOUT0}]
create_generated_clock -name radio_clk_2x    [get_pins {dba_core/RadioClockingx/RadioClkMmcm/CLKOUT1}]
create_generated_clock -name radio_clk_b     [get_pins {dbb_core/RadioClockingx/RadioClkMmcm/CLKOUT0}]
create_generated_clock -name radio_clk_b_2x  [get_pins {dbb_core/RadioClockingx/RadioClkMmcm/CLKOUT1}]

# TDC Measurement Clock
create_generated_clock -name meas_clk [get_pins {MeasClkMmcmx/inst/mmcm_adv_inst/CLKOUT0}]



#*******************************************************************************
## Asynchronous clock groups

# Having trouble renaming these clocks from the PS, so here's a very cheap and wrong(?)
# way to rename them.
set clk100       [get_clocks clk_fpga_0]
set clk40        [get_clocks clk_fpga_1]
set meas_clk_ref [get_clocks clk_fpga_2]
set bus_clk      [get_clocks clk_fpga_3]

# All the clocks from the PS are async to everything else except clocks generated
# from themselves.
set_clock_groups -asynchronous -group [get_clocks $clk100       -include_generated_clocks]
set_clock_groups -asynchronous -group [get_clocks $clk40        -include_generated_clocks]
set_clock_groups -asynchronous -group [get_clocks $bus_clk      -include_generated_clocks]
set_clock_groups -asynchronous -group [get_clocks $meas_clk_ref -include_generated_clocks]

# MGT reference clocks are also async to everything.
set_clock_groups -asynchronous -group [get_clocks USRPIO_A_MGTCLK -include_generated_clocks]
set_clock_groups -asynchronous -group [get_clocks USRPIO_B_MGTCLK -include_generated_clocks]

# radio_clk and radio_clk_b are related to one another after synchronization.
# However, we do need to declare that these clocks (both a and b) are async to the remainder
# of the design.
set_clock_groups -asynchronous -group [get_clocks {Db*FpgaClk*} -include_generated_clocks]



#*******************************************************************************
## PPS Input Timing

# The external PPS is synchronous to the external reference clock, which is expected to
# be at 10 MHz. Given [setup, hold] of [5ns, 5ns] at the inputs to the N310, we have an
# adequate data valid window at the FPGA.
set_input_delay -clock ref_clk -min  5.492 [get_ports REF_1PPS_IN]
set_input_delay -clock ref_clk -max 98.674 [get_ports REF_1PPS_IN]



#*******************************************************************************
## MB Async Ins/Outs

set AsyncMbInputs [get_ports {SFP_*_LOS aUnusedPinForTdc*}]

set_input_delay -clock [get_clocks AsyncInClk] 0.000 $AsyncMbInputs
set_max_delay -from $AsyncMbInputs 50.000
set_min_delay -from $AsyncMbInputs 0.000


set AsyncMbOutputs [get_ports {*LED* SFP_*TXDISABLE aUnusedPinForTdc* \
                               FPGA_TEST[*]}]

set_output_delay -clock [get_clocks AsyncOutClk] 0.000 $AsyncMbOutputs
set_max_delay -to $AsyncMbOutputs 50.000
set_min_delay -to $AsyncMbOutputs 0.000



#*******************************************************************************
## DB Timing
#
# SPI ports, DSA controls, ATR bits, Mykonos GPIO, Mykonos Interrupt

# One of the PL_SPI_ADDR lines is used instead for the LMK SYNC strobe. This line is
# driven asynchronously.
set_output_delay -clock [get_clocks AsyncOutClk] 0.000 [get_ports DB*_CPLD_PL_SPI_ADDR[2]]
set_max_delay -to [get_ports DB*_CPLD_PL_SPI_ADDR[2]] 50.000
set_min_delay -to [get_ports DB*_CPLD_PL_SPI_ADDR[2]] 0.000

# The ATR bits are driven from the DB-A radio clock. Although they are received async in
# the CPLD, they should be tightly constrained in the FPGA to avoid any race conditions.
# The best way to do this is a skew constraint across all the bits.
# First, define one of the outputs as a clock (even though it isn't a clock).
## THIS CONSTRAINT IS CURRENTLY UNUSED SINCE THE ATR BITS ARE DRIVEN CONSTANT '1' ##
# maxSkew will most likely have to be tweaked

# create_generated_clock -name AtrBusClk \
  # -source [get_pins [all_fanin -flat -only_cells -startpoints_only [get_ports DBA_ATR_RX_1]]/C] \
  # -divide_by 2 [get_ports DBA_ATR_RX_1]
# set maxSkew 1.00
# set maxDelay [expr {$maxSkew / 2}]
# # Then add the output delay on each of the ports.
# set_output_delay                        -clock [get_clocks AtrBusClk] -max -$maxDelay [get_ports DB*_ATR_*X_*]
# set_output_delay -add_delay -clock_fall -clock [get_clocks AtrBusClk] -max -$maxDelay [get_ports DB*_ATR_*X_*]
# set_output_delay                        -clock [get_clocks AtrBusClk] -min  $maxDelay [get_ports DB*_ATR_*X_*]
# set_output_delay -add_delay -clock_fall -clock [get_clocks AtrBusClk] -min  $maxDelay [get_ports DB*_ATR_*X_*]
# # Finally, make both the setup and hold checks use the same launching and latching edges.
# set_multicycle_path -setup -to [get_clocks AtrBusClk] -start 0
# set_multicycle_path -hold  -to [get_clocks AtrBusClk] -1


# Mykonos GPIO is driven from the DB-A radio clock. It is received asynchronously inside
# the chip, but should be (fairly) tightly controlled coming from the FPGA.
## NEED CONSTRAINT HERE ##

# Mykonos Interrupt is received asynchronously, and driven directly to the PS.
set_input_delay -clock [get_clocks AsyncInClk] 0.000 [get_ports DB*_MYK_INTRQ]
set_max_delay -from [get_ports DB*_MYK_INTRQ] 50.000
set_min_delay -from [get_ports DB*_MYK_INTRQ] 0.000



#*******************************************************************************
## SYSREF/SYNC JESD Timing
#
# SYNC is async, SYSREF is tightly timed.

# The SYNC output for both DBs is governed by the JESD cores, which are solely driven by
# DB-A clock... but it is an asynchronous signal so we use the AsyncOutClk.
set_output_delay -clock [get_clocks AsyncOutClk] 0.000 [get_ports DB*_MYK_SYNC_IN_n]
set_max_delay -to [get_ports DB*_MYK_SYNC_IN_n] 50.000
set_min_delay -to [get_ports DB*_MYK_SYNC_IN_n] 0.000

# The SYNC input for both DBs is received by the DB-A clock inside the JESD cores... but
# again, it is asynchronous and therefore uses the AsyncInClk.
set_input_delay -clock [get_clocks AsyncInClk] 0.000 [get_ports DB*_MYK_SYNC_OUT_n]
set_max_delay -from [get_ports DB*_MYK_SYNC_OUT_n] 50.000
set_min_delay -from [get_ports DB*_MYK_SYNC_OUT_n] 0.000

# SYSREF is driven by the LMK directly to the FPGA. Timing analysis was performed once
# for the worst-case numbers across both DBs to produce one set of numbers for both DBs.
# Since we easily meet setup and hold in Vivado, then this is an acceptable approach.
# SYSREF is captured by the local clock from each DB, so we have two sets of constraints.
set_input_delay -clock DbaFpgaClkV -min -0.906 [get_ports DBA_FPGA_SYSREF_*]
set_input_delay -clock DbaFpgaClkV -max  0.646 [get_ports DBA_FPGA_SYSREF_*]

set_input_delay -clock DbbFpgaClkV -min -0.906 [get_ports DBB_FPGA_SYSREF_*]
set_input_delay -clock DbbFpgaClkV -max  0.646 [get_ports DBB_FPGA_SYSREF_*]
