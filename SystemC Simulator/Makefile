SRCS := ./src/*.cpp
OBJS := $(subst .cpp,.o,$(SRCS))
INCLUDE := ./include
CXXFLAGS += -w

make snn:
	g++ -I. -I$(SYSTEMC)/include -I$(INCLUDE) -g -w -L. -L$(SYSTEMC)/lib-linux64 -lsystemc -o snn-tlm $(SRCS)	

tlm:
	g++ -I$(INCLUDE) -o neuron_repl neuron_replicator/neuron_repl.cpp
	./neuron_repl

parse_fc1:
	g++ -I$(INCLUDE) snntorch_parser/sntorch_parsing_fc1.cpp -pthread -o input_parse_fc1

parse_fc2:
	g++ -I$(INCLUDE) snntorch_parser/sntorch_parsing_fc2.cpp -pthread -o input_parse_fc2

parse_fc3:
	g++ -I$(INCLUDE) snntorch_parser/sntorch_parsing_fc3.cpp -o input_parse_fc3

def:
	g++ -I$(INCLUDE) -o def_mod neuron_replicator/def_mod.cpp


clean:
	rm snn-tlm
	rm -R input/*
