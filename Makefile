PLAT ?= none
PLATS = linux freebsd macosx
CC ?= gcc
TARGETS = skynet lua-cjson
CSERVICE = henlogger 
SRC_PATH = src
THIRD_PATH = $(SRC_PATH)/3rd
SKYNET_PATH = $(THIRD_PATH)/skynet
LUACJSON_PATH = $(THIRD_PATH)/lua-cjson
THIRD_PATH_LUACLIB = $(THIRD_PATH)/luaclib
CSERVICE_PATH ?= $(SRC_PATH)/cservice
CSERVICE_SRC_PATH ?= $(SRC_PATH)/cservice-src
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
	$(MAKE) -C $(SKYNET_PATH) $(PLAT) CC=$(CC) TLS_MODULE=ltls


$(THIRD_PATH_LUACLIB):
	mkdir -p $(THIRD_PATH_LUACLIB)

lua-cjson: | $(THIRD_PATH_LUACLIB)
	sed -i 's/^LUA_INCLUDE_DIR =   $$(PREFIX)\/include/LUA_INCLUDE_DIR =   ..\/skynet\/3rd\/lua/g' $(LUACJSON_PATH)/Makefile
	$(MAKE) -C $(LUACJSON_PATH) && cp -f $(LUACJSON_PATH)/cjson.so $(THIRD_PATH_LUACLIB)/
	cd $(LUACJSON_PATH) && git restore Makefile
	


$(CSERVICE_PATH) :
	mkdir $(CSERVICE_PATH)

define CSERVICE_TEMP
  $$(CSERVICE_PATH)/$(1).so : $(CSERVICE_SRC_PATH)/service_$(1).c | $$(CSERVICE_PATH)
	$$(CC) $$(CFLAGS) $$(SHARED) $$< -o $$@ -I$(SKYNET_PATH)/skynet-src
endef

$(foreach v, $(CSERVICE), $(eval $(call CSERVICE_TEMP,$(v))))

clean :
	rm -rf $(THIRD_PATH_LUACLIB)
	rm -rf $(CSERVICE_PATH)/*.so 
	rm -rf $(CSERVICE_SRC_PATH)/*.o
	$(MAKE) -C $(SKYNET_PATH) cleanall
	$(MAKE) -C $(LUACJSON_PATH) clean
