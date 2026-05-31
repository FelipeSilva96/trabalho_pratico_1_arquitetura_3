#!/bin/bash

# ==============================================================================
# Script de Automação de Build e Simulação (Verilator) - TP1 Cache Controller
# ==============================================================================

# Definição de cores para facilitar a leitura no terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Sem Cor

echo -e "${BLUE}==========================================================${NC}"
echo -e "${BLUE}      Iniciando fluxo de simulação - Verilator            ${NC}"
echo -e "${BLUE}==========================================================${NC}\n"

# ------------------------------------------------------------------------------
# Passo 1: Limpeza do ambiente
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[1/4] Limpando builds anteriores...${NC}"
rm -rf obj_dir/
rm -f sim/wave.vcd
echo -e "${GREEN}Limpeza concluída.${NC}\n"

# ------------------------------------------------------------------------------
# Passo 2: Compilação SystemVerilog -> C++ com Verilator
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[2/4] Transpilando SystemVerilog com Verilator...${NC}"

# A flag --trace garante suporte a waveforms (.vcd)
# A ordem dos arquivos importa: cache_def.sv (package) deve vir primeiro.
if ! verilator -Wall --trace --timing --cc \
    -Isrc \
    src/cache_def.sv \
    src/dm_cache_data.sv \
    src/dm_cache_tag.sv \
    src/dm_cache_fsm.sv \
    src/main_memory.sv \
    tb/tb_dm_cache.sv \
    --exe sim/sim_cache.cpp \
    --top-module tb_dm_cache; then
    
    echo -e "${RED}❌ ERRO: Falha na etapa do Verilator.${NC}"
    echo -e "${RED}Verifique a sintaxe dos seus arquivos .sv e resolva os erros acima.${NC}"
    exit 1
fi
echo -e "${GREEN}✔ Transpilação concluída com sucesso!${NC}\n"

# ------------------------------------------------------------------------------
# Passo 3: Compilação do C++ (Geração do Executável)
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[3/4] Compilando o executável de simulação (Make)...${NC}"

# O -j$(nproc) utiliza todos os núcleos do seu processador para compilar mais rápido
if ! make -j$(nproc) -C obj_dir -f Vtb_dm_cache.mk Vtb_dm_cache; then
    echo -e "${RED}❌ ERRO: Falha ao compilar o código C++.${NC}"
    echo -e "${RED}Verifique o seu arquivo sim/sim_cache.cpp e as dependências.${NC}"
    exit 1
fi
echo -e "${GREEN}✔ Executável gerado com sucesso (obj_dir/Vtb_dm_cache)!${NC}\n"

# ------------------------------------------------------------------------------
# Passo 4: Execução do Testbench
# ------------------------------------------------------------------------------
echo -e "${YELLOW}[4/4] Executando o Testbench...${NC}"

if ! ./obj_dir/Vtb_dm_cache; then
    echo -e "${RED}❌ ERRO: A simulação falhou durante a execução.${NC}"
    echo -e "${RED}Verifique possíveis loops infinitos na sua FSM ou falhas de segmentação no C++.${NC}"
    exit 1
fi
echo -e "${GREEN}✔ Simulação executada sem erros estruturais!${NC}\n"

# ------------------------------------------------------------------------------
# Conclusão e Próximos Passos
# ------------------------------------------------------------------------------
echo -e "${BLUE}==========================================================${NC}"
echo -e "${GREEN}                      SUCESSO!                            ${NC}"
echo -e "${BLUE}==========================================================${NC}"
echo -e "Se você implementou a lógica de dump (.vcd) no seu testbench,"
echo -e "abra os resultados no GTKWave com o comando:"
echo -e "${YELLOW}gtkwave sim/wave.vcd${NC}"
echo -e "${BLUE}==========================================================${NC}"