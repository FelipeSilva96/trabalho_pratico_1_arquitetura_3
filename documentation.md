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

# 4. Unidade de Controle da Cache (FSM)

Esta seção documenta detalhadamente o comportamento, os estados e a lógica de transição da Máquina de Estados Finitos (FSM) implementada no arquivo `dm_cache_fsm.sv`. O design foi modelado com rigor técnico seguindo as diretrizes da Seção 5.12 do livro *Computer Organization and Design* (Patterson & Hennessy), adaptado para uma arquitetura síncrona em SystemVerilog.

---

## 4.1. Arquitetura da Máquina de Estados

A Unidade de Controle foi projetada utilizando a metodologia clássica de **dois blocos**:
1. **Bloco Sequencial (`always_ff`):** Responsável estritamente pela atualização síncrona do estado atual (`rstate <= vstate`) na borda de subida do sinal de clock (`posedge clk`) ou pela reinicialização assíncrona/síncrona por meio do sinal de `rst`.
2. **Bloco Combinacional (`always_comb`):** Centraliza toda a lógica de transição de próximos estados e a decodificação dos sinais de controle para o *Datapath* (SRAMs de dados e tags) e para as interfaces externas (CPU e Memória Principal).

A FSM é composta por **quatro estados fundamentais**, descritos a seguir:

```
        +-------+       Pedido Válido da CPU
------> | IDLE  | ----------------------------+
        +-------+                             |
            ^                                 v
            |                         +--------------+
      Fim da|                         | COMPARE_TAG  |
    Operação|                         +--------------+
            |                           /          \
            |                Miss + Dirty          Miss + Clean
            |                    /                  \
            |                   v                    v
            |           +------------+        +------------+
            |           | WRITE_BACK | ------>|  ALLOCATE  |
            |           +------------+        +------------+
            |                                        |
            +----------------------------------------+ Memória Principal Ready
```

---

## 4.2. Descrição Detalhada dos Estados

### A. IDLE (`2'b00`)
* **Propósito:** Estado de repouso e espera ativa.
* **Comportamento:** O controlador monitora continuamente o sinal `cpu_req.valid`. Enquanto nenhum pedido legítimo for emitido pela CPU, a máquina permanece em `IDLE`.
* **Transição:** Ao detectar `cpu_req.valid == 1'b1`, a FSM transiciona imediatamente para o estado `COMPARE_TAG` no próximo ciclo de clock.

### B. COMPARE_TAG (`2'b01`)
* **Propósito:** Avaliar a ocorrência de *Hit* ou *Miss* e despachar acessos rápidos.
* **Comportamento:** Realiza a comparação da Tag extraída do endereço da CPU (`cpu_req.addr[31:14]`) com a Tag armazenada na linha correspondente da memória de metadados (`tag_read.tag`).
* **Cenários de Transição:**
  1. **Cache Hit (`tag_read.valid && tag_read.tag == req_tag`):**
     * **Leitura:** A FSM extrai a palavra de 32 bits correspondente utilizando o *offset* (`cpu_req.addr[3:2]`), disponibiliza em `cpu_res.data`, assinala `cpu_res.ready = 1'b1` e retorna para `IDLE`.
     * **Escrita:** A FSM ativa a escrita no datapath (`data_req.we = 1'b1` e `tag_req.we = 1'b1`), atualiza apenas a palavra correspondente dentro do bloco de 128 bits, seta o bit de modificação (`tag_write.dirty = 1'b1`), afirma `cpu_res.ready = 1'b1` e retorna para `IDLE`.
  2. **Cache Miss (Invalidez ou Tags Diferentes):**
     * Se o bloco residente for válido e estiver modificado (`tag_read.valid && tag_read.dirty`), a FSM desvia para `WRITE_BACK` para salvar os dados na memória antes de sobrescrevê-los.
     * Se o bloco estiver limpo (`dirty == 1'b0`) ou for inválido (`valid == 1'b0`), a FSM pula diretamente para `ALLOCATE`.

### C. WRITE_BACK (`2'b11`)
* **Propósito:** Despejar o bloco modificado (*dirty*) da cache para a Memória Principal.
* **Comportamento:** Afirma as saídas de requisição de memória externa (`mem_req.valid = 1'b1` e `mem_req.rw = 1'b1` para escrita). O endereço enviado à memória é reconstruído combinando a **Tag antiga/residente** com o índice atual (`{tag_read.tag, req_idx, 4'b0000}`).
* **Transição:** A FSM permanece travada neste estado aguardando a latência da Memória Principal. Quando o sinal de confirmação `mem_data.ready == 1'b1` é recebido, a transição para o estado `ALLOCATE` é autorizada.

### D. ALLOCATE (`2'b10`)
* **Propósito:** Buscar o bloco de 128 bits atualizado na Memória Principal.
* **Comportamento:** Configura a interface de memória para leitura (`mem_req.valid = 1'b1` e `mem_req.rw = 1'b0`), utilizando o endereço original solicitado pela CPU.
* **Transição:** Permanece em espera até que a memória sinalize `mem_data.ready == 1'b1`. Nesse momento, a cache captura o bloco de 128 bits vindo da memória, grava-o na SRAM de dados (`data_req.we = 1'b1`), grava a nova Tag e valida o bloco na SRAM de tags (`tag_req.we = 1'b1`, `valid = 1'b1`, `dirty = 1'b0`). Em seguida, retorna para o estado `COMPARE_TAG` para concluir a requisição original da CPU de forma transparente.

---

## 4.3. Matriz de Transições e Condições Lógicas

| Estado Atual | Condição de Entrada / Gatilho | Próximo Estado | Ações de Controle Associadas |
| :--- | :--- | :--- | :--- |
| **IDLE** | `cpu_req.valid == 0` | **IDLE** | Aguarda requisição da CPU. Sinais inativos. |
| **IDLE** | `cpu_req.valid == 1` | **COMPARE_TAG** | Prepara barramentos de endereço para o Datapath. |
| **COMPARE_TAG** | `Hit == 1` (Leitura ou Escrita) | **IDLE** | Ativa `cpu_res.ready`. Se escrita, injeta palavra e seta `dirty=1`. |
| **COMPARE_TAG** | `Hit == 0` e `Valid && Dirty == 1` | **WRITE_BACK** | Miss com Evicção Bloqueante. Prepara escrita do bloco antigo na memória. |
| **COMPARE_TAG** | `Hit == 0` e `Valid && Dirty == 0` | **ALLOCATE** | Cold Miss ou Miss de bloco limpo. Prepara leitura na memória principal. |
| **WRITE_BACK** | `mem_data.ready == 0` | **WRITE_BACK** | Mantém requisição de escrita ativa. Aguarda latência da memória. |
| **WRITE_BACK** | `mem_data.ready == 1` | **ALLOCATE** | Escrita concluída. Modifica endereço para buscar novo bloco. |
| **ALLOCATE** | `mem_data.ready == 0` | **ALLOCATE** | Mantém requisição de leitura ativa. Aguarda transferência do bloco. |
| **ALLOCATE** | `mem_data.ready == 1` | **COMPARE_TAG** | Atualiza SRAM de Dados e Tags. Volta para reavaliar o acesso (Garante Hit). |

---

## 4.4. Segurança do Circuito: Prevenção de Latches

Para garantir que o sintetizador lógico mapeie o código combinacional estritamente para elementos de lógica combinatória (portas lógicas e multiplexadores), evitando a criação de *latches* indesejados (retroalimentação prejudicial), a Unidade de Controle implementa uma diretiva rígida de **atribuição default**.

No topo do bloco `always_comb`, todas as variáveis de saída são inicializadas com valores seguros (estáticos):
* Os sinais de validação de escrita do Datapath (`data_req.we`, `tag_req.we`) começam obrigatoriamente desativados (`1'b0`).
* Os sinais de requisição para a CPU e para a Memória Principal são zerados por padrão.
* Dessa forma, caso o fluxo de execução caia em uma ramificação condicional implícita ou incompleta, o compilador possui um valor padrão garantido para atribuir à saída, assegurando a estabilidade do hardware.
---

## 10. Ambiente de Simulação e Repositório

O ambiente de desenvolvimento e simulação já foi configurado e devidamente documentado no arquivo `README.md`. O repositório contém:

* Explicação clara da arquitetura e dos quatro estados da máquina de controle (FSM).
* Instruções detalhadas para compilação e extração de waveforms no GTKWave utilizando o Icarus Verilog.
* Suporte e comandos documentados para execução em ambientes Linux e Windows via WSL.