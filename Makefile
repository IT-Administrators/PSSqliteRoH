.RECIPEPREFIX = >

PROJECT = src/PSSqliteRoH.Sqlite/PSSqliteRoH.Sqlite.csproj
CONFIGURATION = Release
FRAMEWORK = netstandard2.0
OUTPUT = lib/$(FRAMEWORK)
DOTNET = dotnet

RIDS = win-x64 linux-x64 osx-x64

.PHONY: all clean restore publish merge-native

all: clean restore publish merge-native

restore:
> $(DOTNET) restore $(PROJECT)

publish:
> @for rid in $(RIDS); do \
>   echo "Publishing for $$rid"; \
>   $(DOTNET) publish $(PROJECT) \
>     -c $(CONFIGURATION) \
>     -f $(FRAMEWORK) \
>     -r $$rid \
>     --self-contained false \
>     -o $(OUTPUT)/$$rid; \
> done

merge-native:
> @echo "Merging managed DLLs"
> mkdir -p $(OUTPUT)
> cp $(OUTPUT)/win-x64/PSSqliteRoH.Sqlite.dll $(OUTPUT)/ || true
> cp $(OUTPUT)/win-x64/PSSqliteRoH.Sqlite.pdb $(OUTPUT)/ || true
>
> @echo "Copying native SQLite runtimes"
> cp $(OUTPUT)/win-x64/runtimes/win-x64/native/e_sqlite3.dll $(OUTPUT)/ || true
> cp $(OUTPUT)/linux-x64/runtimes/linux-x64/native/libe_sqlite3.so $(OUTPUT)/ || true
> cp $(OUTPUT)/osx-x64/runtimes/osx-x64/native/libe_sqlite3.dylib $(OUTPUT)/ || true

clean:
> rm -rf $(OUTPUT)
