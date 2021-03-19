derive_pll_clocks
derive_clock_uncertainty

create_generated_clock -source [get_pins {emu|pll|pll_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] \
                       -name CLK_i0 -divide_by 2 -duty_cycle 50 [get_nets {emu|zxnext_top|CLK_i0}]

create_generated_clock -source [get_pins {emu|pll|pll_inst|altera_pll_i|general[0].gpll~PLL_OUTPUT_COUNTER|divclk}] \
                       -name CLK_CPU -divide_by 1 -duty_cycle 50 [get_nets {emu|zxnext_top|CLK_CPU}]

set clk_sys {*|pll|pll_inst|altera_pll_i|*[0].*|divclk}
set clk_56m {*|pll|pll_inst|altera_pll_i|*[1].*|divclk} 
set clk_14m {*|pll|pll_inst|altera_pll_i|*[2].*|divclk} 
set clk_7m  {*|pll|pll_inst|altera_pll_i|*[3].*|divclk} 
set clk_mem {*|pll|pll_inst|altera_pll_i|*[4].*|divclk} 

set_multicycle_path -from [get_clocks $clk_sys] -to [get_clocks $clk_7m] -start -setup 2
set_multicycle_path -from [get_clocks $clk_sys] -to [get_clocks $clk_7m] -start -hold 1 
set_multicycle_path -from [get_clocks $clk_56m] -to [get_clocks CLK_CPU] -start -setup 2
set_multicycle_path -from [get_clocks $clk_56m] -to [get_clocks CLK_CPU] -start -hold 1 
set_multicycle_path -from [get_clocks $clk_mem] -to [get_clocks CLK_CPU] -start -setup 2
set_multicycle_path -from [get_clocks $clk_mem] -to [get_clocks CLK_CPU] -start -hold 1 
set_multicycle_path -from [get_clocks CLK_CPU]  -to [get_clocks $clk_mem] -setup 2
set_multicycle_path -from [get_clocks CLK_CPU]  -to [get_clocks $clk_mem] -hold 1 
