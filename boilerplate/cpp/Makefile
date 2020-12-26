# Source  --------------------------------------------------------------
TARGET      := main
SRCDIR      := src
INCLUDEDIR  := include

# All CXX files grouped by sub-namespace
APP_CXXFILES := $(shell find $(SRCDIR)/app -type f -name '*.cpp')
CXXFILES     := $(APP_CXXFILES)

# All Header files grouped by sub-namespace
APP_HEADERS   := $(shell find $(INCLUDEDIR)/app -type f -name '*.h')
HEADERS       := $(APP_HEADERS)

# Compiler -------------------------------------------------------------
CXX := g++
LINKER := g++

CFLAGS      := -W -Wall -I -pthread -g
INCLUDE := -I$(INCLUDEDIR)/ -Ilib/
LIBS := 

CXXFLAGS := -g -Wall -O3 -fmessage-length=0 $(INCLUDE)
LDFLAGS := 

# Platform -------------------------------------------------------------
ifeq ($(shell sw_vers 2>/dev/null | grep Mac | awk '{ print $$2}'),Mac)
	PLATFORM := OSX
else
	PLATFORM := _POSIX
	LDFLAGS += -lpthread -ldl
endif

# Libs -----------------------------------------------------------------

# Rules ----------------------------------------------------------------
CXXOBJS     := $(CXXFILES:.cpp=.o)

%.o : %.cpp
	$(CXX) -c $< -o $@ $(CXXFLAGS)

$(TARGET): $(CXXOBJS) $(HEADERS) $(LIBS)
	$(LINKER) -o $(TARGET) $(CXXOBJS) $(LIBS) $(LDFLAGS) 

lint:
	$(foreach myfile,$(SERVER_HEADERS),python cpplint.py --filter=-whitespace $(myfile);)
	$(foreach myfile,$(SERVER_CXXFILES),python cpplint.py --filter=-whitespace $(myfile);)

clean:
	rm -f $(TARGET) $(CXXOBJS)

.DEFAULT_GOAL := $(TARGET)


