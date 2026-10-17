REMODEL := remodel
OUTPUT  ?= MeuJogo.rbxl
SCRIPT  := save_place.lua

.PHONY: build clean install-remodel

build: $(OUTPUT)

$(OUTPUT): $(SCRIPT)
	OUTPUT=$(OUTPUT) $(REMODEL) run $(SCRIPT)
	@echo ">>> $(OUTPUT) gerado com sucesso!"

clean:
	rm -f $(OUTPUT)

install-remodel:
	@echo "Baixando Remodel..."
	curl -Lo remodel.zip https://github.com/rojo-rbx/remodel/releases/latest/download/remodel-linux-x86_64.zip
	unzip -o remodel.zip -d /usr/local/bin
	rm -f remodel.zip
	@echo "Remodel instalado!"
