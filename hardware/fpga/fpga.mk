#DEFINES

#ddr controller address width
DEFINE+=$(defmacro)DDR_ADDR_W=$(FPGA_DDR_ADDR_W)

include $(ROOT_DIR)/hardware/hardware.mk

#SOURCES
VSRC+=./verilog/top_system.v

#RULES

all: sw build load run

run:
ifeq ($(BOARD_SERVER),)
	if [ $(FPGA_NORUN) == 0 ]; then make -C $(CONSOLE_DIR) run; fi
else
	ssh $(BOARD_USER)@$(BOARD_SERVER) 'if [ ! -d $(REMOTE_ROOT_DIR) ]; then mkdir -p $(REMOTE_ROOT_DIR); fi'
	rsync -avz --exclude .git $(ROOT_DIR) $(BOARD_USER)@$(BOARD_SERVER):$(REMOTE_ROOT_DIR) 
	ssh $(BOARD_USER)@$(BOARD_SERVER) 'cd $(REMOTE_ROOT_DIR)/hardware/fpga/$(BOARD); make run INIT_MEM=$(INIT_MEM) TEST_LOG="$(TEST_LOG)"'
endif


load:
ifeq ($(BOARD_SERVER),)
	if [ $(FPGA_NORUN) == 0 -a ! -f load.log ]; then ./prog.sh > load.log; fi
else
	ssh $(BOARD_USER)@$(BOARD_SERVER) 'if [ ! -d $(REMOTE_ROOT_DIR) ]; then mkdir -p $(REMOTE_ROOT_DIR); fi'
	rsync -avz --exclude .git $(ROOT_DIR) $(BOARD_USER)@$(BOARD_SERVER):$(REMOTE_ROOT_DIR) 
	ssh $(BOARD_USER)@$(BOARD_SERVER) 'cd $(REMOTE_ROOT_DIR)/hardware/fpga/$(BOARD); make load FPGA_NORUN=$(FPGA_NORUN)'
endif


build: $(FPGA_OBJ)


$(FPGA_OBJ): $(wildcard *.sdc) $(VSRC) $(VHDR) firmware.hex boot.hex
ifeq ($(FPGA_SERVER),)
	if [ $(FPGA_NORUN) == 0 ]; then ./build.sh "$(INCLUDE)" "$(DEFINE)" "$(VSRC)"; fi
else
	ssh $(FPGA_USER)@$(FPGA_SERVER) 'if [ ! -d $(REMOTE_ROOT_DIR) ]; then mkdir -p $(REMOTE_ROOT_DIR); fi'
	rsync -avz --exclude .git $(ROOT_DIR) $(FPGA_USER)@$(FPGA_SERVER):$(REMOTE_ROOT_DIR)
	ssh $(FPGA_USER)@$(FPGA_SERVER) 'cd $(REMOTE_ROOT_DIR)/hardware/fpga/$(BOARD); make build INIT_MEM=$(INIT_MEM) USE_DDR=$(USE_DDR) RUN_EXTMEM=$(RUN_EXTMEM) BOARD=$(BOARD)'
	if [ $(FPGA_NORUN) == 0 ]; then scp $(FPGA_USER)@$(FPGA_SERVER):$(REMOTE_ROOT_DIR)/$(BOARD_DIR)/$(FPGA_OBJ) $(BOARD_DIR);
endif


fpga-clean: hw-clean
ifneq ($(FPGA_SERVER),)
	rsync -avz --exclude .git $(ROOT_DIR) $(FPGA_USER)@$(FPGA_SERVER):$(REMOTE_ROOT_DIR)
	ssh $(FPGA_USER)@$(FPGA_SERVER) 'cd $(REMOTE_ROOT_DIR)/hardware/fpga/$(BOARD); make board-clean CLEANIP=$(CLEANIP)'
endif
ifneq ($(BOARD_SERVER),)
	rsync -avz --exclude .git $(ROOT_DIR) $(BOARD_USER)@$(BOARD_SERVER):$(REMOTE_ROOT_DIR)
	ssh $(BOARD_USER)@$(BOARD_SERVER) 'cd $(REMOTE_ROOT_DIR)/hardware/fpga/$(BOARD); make board-clean'
endif

log-clean:
	@rm -f $(CONSOLE_DIR)/test.log
ifneq ($(BOARD_SERVER),)
	rsync -avz --exclude .git $(ROOT_DIR) $(BOARD_USER)@$(BOARD_SERVER):$(REMOTE_ROOT_DIR)
	ssh $(BOARD_USER)@$(BOARD_SERVER) 'cd $(REMOTE_ROOT_DIR)/hardware/fpga/$(BOARD); rm -f $(CONSOLE_DIR)/test.log'
endif


.PRECIOUS: $(FPGA_OBJ)

.PHONY: all run load build fpga-clean log-clean
