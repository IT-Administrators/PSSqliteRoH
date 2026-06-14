PROJECT = src/PSSqliteRoH.Sqlite/PSSqliteRoH.Sqlite.csproj
CONFIGURATION = Release
OUTPUT = lib/netstandard2.0
DOTNET = dotnet
NUGET_PACKAGES ?= $(HOME)/.nuget/packages
UNAME_S := $(shell uname -s)

ifeq ($(UNAME_S),Linux)
RUNTIME_OS = linux-x64
endif
ifeq ($(UNAME_S),Darwin)
RUNTIME_OS = osx-x64
endif
ifeq ($(UNAME_S),Windows_NT)
RUNTIME_OS = win-x64
endif

E_SQLITE3_SO := $(shell find "$(NUGET_PACKAGES)" -path '*/sqlitepclraw.lib.e_sqlite3/*/runtimes/$(RUNTIME_OS)/native/libe_sqlite3.so' -o -path '*/sourcegear.sqlite3/*/runtimes/$(RUNTIME_OS)/native/libe_sqlite3.so' 2>/dev/null | sort | tail -n 1)
E_SQLITE3_DYLIB := $(shell find "$(NUGET_PACKAGES)" -path '*/sqlitepclraw.lib.e_sqlite3/*/runtimes/$(RUNTIME_OS)/native/libe_sqlite3.dylib' -o -path '*/sourcegear.sqlite3/*/runtimes/$(RUNTIME_OS)/native/libe_sqlite3.dylib' 2>/dev/null | sort | tail -n 1)
E_SQLITE3_DLL := $(shell find "$(NUGET_PACKAGES)" -path '*/sqlitepclraw.lib.e_sqlite3/*/runtimes/$(RUNTIME_OS)/native/e_sqlite3.dll' -o -path '*/sourcegear.sqlite3/*/runtimes/$(RUNTIME_OS)/native/e_sqlite3.dll' 2>/dev/null | sort | tail -n 1)

.PHONY: all build restore clean install copy-native
all: build

build: restore $(OUTPUT)/PSSqliteRoH.Sqlite.dll

restore:
	$(DOTNET) restore $(PROJECT)

$(OUTPUT)/PSSqliteRoH.Sqlite.dll: $(PROJECT)
	mkdir -p $(OUTPUT)
	$(DOTNET) publish $(PROJECT) -c $(CONFIGURATION) -f netstandard2.0 -o $(OUTPUT)
	@echo "Staging runtime and native files into $(OUTPUT)"
	$(MAKE) copy-native

copy-native:
	@echo "Copying native SQLite runtime assets when available"
	@if [ -n "$(E_SQLITE3_SO)" ]; then cp -u "$(E_SQLITE3_SO)" "$(OUTPUT)/libe_sqlite3.so"; fi
	@if [ -n "$(E_SQLITE3_DYLIB)" ]; then cp -u "$(E_SQLITE3_DYLIB)" "$(OUTPUT)/libe_sqlite3.dylib"; fi
	@if [ -n "$(E_SQLITE3_DLL)" ]; then cp -u "$(E_SQLITE3_DLL)" "$(OUTPUT)/e_sqlite3.dll"; fi

clean:
	rm -rf $(OUTPUT)

install: all
