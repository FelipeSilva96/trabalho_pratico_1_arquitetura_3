# Documentação Base: Controlador de Cache (Fase 1 e Datapath)

## 1. Introdução e Parâmetros Arquiteturais (SDD)

O presente projeto consiste na implementação de um controlador de cache em SystemVerilog, desenvolvido com base na Seção 5.12 do livro Computer Organization and Design.O modelo adota uma abordagem de Desenvolvimento Guiado por Especificação (SDD) para estruturar as interfaces antes da implementação lógica.

As características arquiteturais da cache foram definidas da seguinte forma:

| Parâmetro | Especificação Adotada |
| :--- | :--- |
| **Mapeamento** | Direto (Direct-mapped)  |
| **Capacidade Total** | 16 KiB  |
| **Número de Linhas** | 1024 linhas  |
| **Tamanho do Bloco** | 128 bits (4 palavras de 32 bits)  |
| **Política de Escrita** | Write-back  |
| **Política de Alocação** | Write-allocate  |
| **Política de Substituição** | Não se aplica, pois o mapeamento direto substitui sumariamente a linha pelo índice  |

---

## 2. Especificação de Interfaces e Estruturas de Dados

Todas as definições globais do projeto foram centralizadas no pacote `cache_def.sv`. Este arquivo garante a padronização da comunicação entre os módulos.

* **Limites de Endereçamento:** O pacote define os limites precisos de bits para a separação do endereço da CPU em campos de TAG, INDEX e OFFSET.
* **Estrutura da Tag:** Criou-se a estrutura compactada `cache_tag_type`, que armazena a tag em si, juntamente com os bits de estado valid e dirty.
* **Estrutura de Dados:** A linha de dados foi estruturada como `cache_data_type`, comportando integralmente os 128 bits do bloco.
* **Interfaces de Comunicação:** Foram mapeadas as portas entre a CPU e a Cache (`cpu_req_type` e `cpu_result_type`), bem como entre a Cache e a Memória Principal (`mem_req_type` e `mem_data_type`).

---

## 3. Implementação do Datapath (RTL)

O armazenamento interno da cache foi projetado de forma modular, separando os dados dos metadados em duas memórias SRAM simuladas distintas:

* **Memória de Dados (`dm_cache_data.sv`):** Implementada com 1024 linhas, onde cada posição comporta um bloco inteiro de 128 bits. A lógica opera com leitura combinacional contínua e escrita sincronizada na borda de subida do clock.
* **Memória de Tags (`dm_cache_tag.sv`):** Instancia um vetor de 1024 posições exclusivamente para os metadados. Apresenta comportamento semelhante à memória de dados, atualizando a estrutura completa (valid, dirty e tag) simultaneamente quando uma escrita é requisitada na borda do clock.

---

## 4. Ambiente de Simulação e Repositório

O ambiente de desenvolvimento e simulação já foi configurado e devidamente documentado no arquivo `README.md`. O repositório contém:

* Explicação clara da arquitetura e dos quatro estados da máquina de controle (FSM).
* Instruções detalhadas para compilação e extração de waveforms no GTKWave utilizando o Icarus Verilog.
* Suporte e comandos documentados para execução em ambientes Linux e Windows via WSL.