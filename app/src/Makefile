# Builds ../controllerhf.so and ../<name>.dtbo on the board: make -C src

INSTALL_DIR ?= /opt/redpitaya

NAME := $(shell . ../conf_get.sh && conf_get ../design.info name)
ifeq ($(NAME),)
$(error No name in ../design.info)
endif

# -isystem: silences rp_sdk's own warnings.
CXXFLAGS = -std=c++17 -O2 -DNDEBUG -Wall -Wextra -fPIC \
           -isystem $(INSTALL_DIR)/rp_sdk -isystem $(INSTALL_DIR)/rp_sdk/libjson
# The whole rp_sdk archive: it provides the WebSocket entry points nginx looks up.
LDFLAGS = -shared -L$(INSTALL_DIR)/rp_sdk -L$(INSTALL_DIR)/lib -Wl,-rpath,$(INSTALL_DIR)/lib \
          -Wl,--whole-archive -lrp_sdk -Wl,--no-whole-archive -lcryptopp

OBJECTS = $(patsubst %.cpp,%.o,$(wildcard *.cpp))

all: ../controllerhf.so ../$(NAME).dtbo

../controllerhf.so: $(OBJECTS)
	$(CXX) $(OBJECTS) -o $@ $(LDFLAGS)

%.o: %.cpp $(wildcard *.hpp)
	$(CXX) $(CXXFLAGS) -c $< -o $@

../$(NAME).dtbo: ../$(NAME).dtso
	@command -v dtc > /dev/null || { echo "dtc not found on the board" >&2; exit 1; }
	dtc -@ -I dts -O dtb -o $@ $<

clean:
	rm -f *.o ../controllerhf.so ../$(NAME).dtbo

.PHONY: all clean
