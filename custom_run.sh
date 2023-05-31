#3
./def_mod 1 1 1 15; \
rm -R input/*
make parse_fc1 &&  make parse_fc2 && make parse_fc3; \
./input_parse_fc1 1 1 1 1 &
./input_parse_fc2 1 1 1 1 &
./input_parse_fc3 1 1 1 1 &
make snn &
wait
./snn-tlm

