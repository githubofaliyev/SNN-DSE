#2
./def_mod 1 1 1 15; \
rm -R input/*
make parse_fc1 &&  make parse_fc2 && make parse_fc3; \
./input_parse_fc1 1 1 1 1 &
./input_parse_fc2 1 1 1 1 &
./input_parse_fc3 1 1 1 1 &
make snn &
wait
./snn-tlm

#2
./def_mod 2 1 1 15; \
rm -R input/*
make parse_fc1 &&  make parse_fc2 && make parse_fc3; \
./input_parse_fc1 1 1 1 1 &
./input_parse_fc2 1 1 1 1 &
./input_parse_fc3 1 1 1 1 &
make snn &
wait
./snn-tlm

#2
./def_mod 1 2 1 15; \
rm -R input/*
make parse_fc1 &&  make parse_fc2 && make parse_fc3; \
./input_parse_fc1 1 1 1 1 &
./input_parse_fc2 1 1 1 1 &
./input_parse_fc3 1 1 1 1 &
make snn &
wait
./snn-tlm

#2
./def_mod 64 16 8 15; \
rm -R input/*
make parse_fc1 &&  make parse_fc2 && make parse_fc3; \
./input_parse_fc1 1 1 1 1 &
./input_parse_fc2 1 1 1 1 &
./input_parse_fc3 1 1 1 1 &
make snn &
wait
./snn-tlm

#2
./def_mod 16 8 8 15; \
rm -R input/*
make parse_fc1 &&  make parse_fc2 && make parse_fc3; \
./input_parse_fc1 1 1 1 1 &
./input_parse_fc2 1 1 1 1 &
./input_parse_fc3 1 1 1 1 &
make snn &
wait
./snn-tlm


