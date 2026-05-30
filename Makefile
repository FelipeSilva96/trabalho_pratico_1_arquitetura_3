#Variáveis
#-------------------------------------------------
VERILATOR = verilator
VFLAGS = --cc --build -Wall --timing

SRC_FILES = $(wildcard src/*.sv)
TB_FILES = $(wildcard tb/*.sv)
SIM_FILES = $(wildcard sim/*.cpp)
#-------------------------------------------------

# Execuções
#-------------------------------------------------
all: run
#-------------------------------------------------
run: obj_dir/Vtb_dm_cache
	./obj_dir/Vtb_dm_cache
#-------------------------------------------------
obj_dir/Vtb_dm_cache: $(SRC_FILES) $(TB_FILES) $(SIM_FILES) obj_dir/Vdm_cache_tag
	$(VERILATOR) $(VFLAGS) --exe --top-module tb_dm_cache sim/sim_cache.cpp src/*.sv tb/tb_dm_cache.sv
#-------------------------------------------------
obj_dir/Vdm_cache_data: obj_dir/Vcache_def src/dm_cache_data.sv
	$(VERILATOR) $(VFLAGS) --top-module dm_cache_data src/cache_def.sv src/dm_cache_data.sv

obj_dir/Vdm_cache_fsm: obj_dir/Vcache_def src/dm_cache_fsm.sv
	$(VERILATOR) $(VFLAGS) --top-module dm_cache_fsm src/cache_def.sv src/dm_cache_fsm.sv

obj_dir/Vdm_cache_tag: obj_dir/Vcache_def src/dm_cache_tag.sv
	$(VERILATOR) $(VFLAGS) --top-module dm_cache_tag src/cache_def.sv src/dm_cache_tag.sv
#-------------------------------------------------
obj_dir/Vcache_def: src/cache_def.sv
	$(VERILATOR) $(VFLAGS) src/cache_def.sv
#-------------------------------------------------
