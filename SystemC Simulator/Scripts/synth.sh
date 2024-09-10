# Iterating for NEURAL_1 values 4 and 8 with fixed NEURAL_2 = 4
foreach value {4 16 32 64} {
  #set LAYER_SIZE 500
  #set NEURAL_UNIT_SIZE $value
  set NEURAL_SIZE $value

  # Open the include file for writing
  set file [open "C:/Users/Ilkin/vivado_projects/hw_design_params.svh" w]

  # Write the `define statements
  #puts $file "`define LAYER_SIZE $LAYER_SIZE"
  #puts $file "`define NEURAL_UNIT_SIZE $NEURAL_UNIT_SIZE"
  puts $file "`define NEURAL_SIZE $NEURAL_SIZE"

  close $file

  reset_run synth_1

  launch_runs synth_1 -jobs 16
  wait_on_run synth_1

  open_run synth_1 -name synth_1
  wait_on_run synth_1
  
  set power_report_file "C:/Users/jlopezramos/vivadoProjects/reports/${NEURAL_SIZE}_synth_pwr.txt"
  set power_report_file "C:/Users/jlopezramos/vivadoProjects/reports/${LAYER_SIZE}_${NEURAL_UNIT_SIZE}_synth_pwr.txt"
  set utilization_report_file "C:/Users/jlopezramos/vivadoProjects/reports/${LAYER_SIZE}_${NEURAL_UNIT_SIZE}_synth_area.txt"
  set utilization_report_file "C:/Users/jlopezramos/Desktop/vivadoProjects/reports/synth_area.txt"
  set utilization_report_hier_file "C:/Users/jlopezramos/Desktop/vivadoProjects/reports/synth_hier_area.txt"
  
  report_power -file $power_report_file
  report_utilization -file $utilization_report_file  
  report_utilization -hierarchical -file $utilization_report_hier_file  
  
}