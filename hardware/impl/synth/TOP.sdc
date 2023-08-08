set period_clk $PERIOD_CLK
set period_sck $PERIOD_SCK
set DESIGN     $DESIGN_NAME

create_clock -period $period_clk -add -name clock_clk -waveform [list 0 [expr $period_clk*0.5]] [get_pins u_ITF/u_CLK/u_CLKREL_SysClk/clk_out]
create_clock -period $period_sck -add -name clock_sck -waveform [list 0 [expr $period_sck*0.5]] [get_pins u_ITF/u_CLK/u_CLKREL_OffClk/clk_out]

set clock_list [concat clock_clk clock_sck]

set_clock_uncertainty -setup 0.2    [get_pins u_ITF/u_CLK/u_CLKREL_SysClk/clk_out]
set_clock_uncertainty -hold  0.1    [get_pins u_ITF/u_CLK/u_CLKREL_SysClk/clk_out]

set_clock_uncertainty -setup 0.2    [get_pins u_ITF/u_CLK/u_CLKREL_OffClk/clk_out]
set_clock_uncertainty -hold  0.1    [get_pins u_ITF/u_CLK/u_CLKREL_OffClk/clk_out]

set_false_path -from [get_clocks clock_clk] -to [get_clocks clock_sck]
set_false_path -from [get_clocks clock_sck] -to [get_clocks clock_clk]

set_false_path -from [list \
    [get_ports I_BypAsysnFIFO_PAD]\
    [get_ports I_BypOE_PAD       ]\
    [get_ports I_SysRst_n_PAD    ]\
    [get_ports I_SwClk_PAD       ]\
    [get_ports I_SysClk_PAD      ]\
    [get_ports I_OffClk_PAD      ]\
    [get_ports I_BypPLL_PAD      ]\
    [get_ports I_FBDIV_PAD       ]\
    [get_ports I_MonSel_PAD      ]\
]

set_false_path -to [list \
    [get_ports O_PLLLock_PAD     ]\
    [get_ports O_MonDat_PAD      ]\
]
    # [get_ports O_SysClk_PAD      ]\
    # [get_ports O_OffClk_PAD      ]\

# Margin Fixed 7ns
set_input_delay  -clock clock_clk -clock_rise -add_delay [expr $period_clk - 7] [filter_collection [all_inputs] "full_name !~I_OffOE_PAD && full_name !~I_MonSel_PAD"]
# Margin Fixed 7ns
set_output_delay -clock clock_clk -clock_rise -add_delay [expr $period_clk - 7] [filter_collection [all_outputs] "full_name !~O_MonDat_PAD"]

# Margin Fixsed 7ns
set_input_delay  -clock clock_sck -clock_rise -add_delay [expr $period_sck - 7] [filter_collection [all_inputs] "full_name !~I_OffOE_PAD && full_name !~I_MonSel_PAD"]
# Margin Fixed 7ns
set_output_delay -clock clock_sck -clock_rise -add_delay [expr $period_sck - 7] [filter_collection [all_outputs] "full_name !~O_MonDat_PAD"]

# Margin Fixed 7ns (report_timing < 2ns)
set_max_delay 7 -from [get_ports I_OffOE_PAD] -to [get_ports IO_Dat_PAD*]
set_max_delay 7 -from [get_ports I_MonSel_PAD] -to [get_ports O_MonDat_PAD*]

set_input_transition -min 0.05 [all_inputs]
set_input_transition -max 0.2  [all_inputs]

set_load -pin_load -max 1 [all_outputs]

set_max_transition 0.5 ${DESIGN}
set_max_fanout 32 ${DESIGN}

