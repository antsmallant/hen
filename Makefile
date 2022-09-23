PLAT ?= none
PLATS = linux freebsd macosx
CC ?= gcc
TARGETS = skynet
CSERVICE = henlogger
SRC_PATH = src
SKYNET_PATH = $(SRC_PATH)/3rd/skynet
CSERVICE_PATH ?= $(SRC_PATH)/cservice
CSERVICE_SRC_PATH ?= $(SRC_PATH)/service-src
SHARED := -fPIC -shared

.PHONY : none $(PLATS) $(TARGETS) clean

#ifneq ($(PLAT), none)
.PHONY : default
default :
	$(MAKE) $(PLAT)
#endif

none :
	@echo "Please do 'make PLATFORM' where PLATFORM is one of these:"
	@echo "   $(PLATS)"

# PLAT
linux : PLAT = linux
macosx : PLAT = macosx
freebsd : PLAT = freebsd

macosx : SHARED := -fPIC -dynamiclib -Wl,-undefined,dynamic_lookup
linux macosx freebsd : $(TARGETS)
macosx : MT_CFLAGS := -DNOT_MT_GENERATE_CODE_IN_HEADER

linux freebsd macosx :
	$(MAKE) all PLAT=$@ SHARED="$(SHARED)" MT_CFLAGS="$(MT_CFLAGS)"

all : \
	$(foreach v, $(TARGETS), $(v)) \
	$(foreach v, $(CSERVICE), $(CSERVICE_PATH)/$(v).so)

skynet :
#	chmod +x -R $(SKYNET_PATH)/3rd/jemalloc 
	$(MAKE) -C $(SKYNET_PATH) $(PLAT) CC=$(CC)

$(CSERVICE_PATH) :
	mkdir $(CSERVICE_PATH)

define CSERVICE_TEMP
  $$(CSERVICE_PATH)/$(1).so : $(CSERVICE_SRC_PATH)/service_$(1).c | $$(CSERVICE_PATH)
	$$(CC) $$(CFLAGS) $$(SHARED) $$< -o $$@ -I$(SKYNET_PATH)/skynet-src
endef

$(foreach v, $(CSERVICE), $(eval $(call CSERVICE_TEMP,$(v))))

clean :
	rm -rf $(CSERVICE_PATH)/*.so 
	rm -rf $(CSERVICE_SRC_PATH)/*.o
	$(MAKE) -C $(SKYNET_PATH) cleanall
