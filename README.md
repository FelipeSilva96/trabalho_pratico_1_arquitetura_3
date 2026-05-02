# Trabalho Prático 1 — Controlador de Cache

## Objetivo

Este projeto tem como objetivo implementar, simular e analisar um **controlador de cache** em **SystemVerilog**, com base no modelo apresentado no livro _Computer Organization and Design: The Hardware/Software Interface — RISC-V Edition_, de Patterson & Hennessy.

O foco principal do trabalho é compreender, por meio de implementação prática, como uma cache simples interage com a CPU e com a memória principal, tratando corretamente acessos de leitura, escrita, hits, misses, substituição de blocos e escrita de blocos modificados.

Este projeto tem caráter didático e acadêmico. O objetivo não é implementar uma cache industrial altamente otimizada, mas sim uma cache funcional, organizada e bem documentada, capaz de demonstrar os principais conceitos de hierarquia de memória estudados na disciplina **Arquitetura de Computadores III**.

---

## Conceitos Envolvidos

Este trabalho envolve os seguintes conceitos fundamentais de arquitetura de computadores:

- Hierarquia de memória
- Cache mapeada diretamente
- Cache hit
- Cache miss
- Tag
- Index
- Offset
- Valid bit
- Dirty bit
- Bloco de cache
- Política de escrita write-back
- Política de alocação write-allocate
- Substituição de blocos
- Escrita de bloco sujo na memória principal
- Máquina de estados finitos
- Interface CPU-cache
- Interface cache-memória
- Simulação em SystemVerilog
- Testbench
- Análise de waveform com GTKWave

---

## Descrição Geral do Projeto

O projeto implementa um controlador de cache simplificado, baseado em uma cache **direct-mapped**, isto é, uma cache mapeada diretamente.

Em uma cache mapeada diretamente, cada bloco da memória principal só pode ser armazenado em uma única posição específica da cache. Essa posição é determinada por uma parte do endereço chamada **index**.

A cache utilizada neste projeto segue o modelo didático apresentado no livro de Patterson & Hennessy, com as seguintes características:

- Cache mapeada diretamente
- Tamanho total da cache: **16 KiB**
- Quantidade de linhas/blocos na cache: **1024**
- Tamanho de cada bloco: **4 palavras**
- Tamanho de cada palavra: **32 bits**
- Tamanho de cada bloco: **128 bits**
- Endereços de CPU com **32 bits**
- Dados transferidos entre CPU e cache com **32 bits**
- Dados transferidos entre cache e memória principal em blocos de **128 bits**
- Política de escrita: **write-back**
- Política de alocação em escrita: **write-allocate**
- Um bit de validade por linha
- Um bit de sujeira por linha
- Uma tag por linha

---

## Organização do Endereço

A cache trabalha com endereços de 32 bits.

Como a cache possui 1024 linhas, são necessários 10 bits para selecionar a linha da cache:

```text
1024 = 2^10
```
Como cada bloco possui 16 bytes, são necessários 4 bits para selecionar o byte dentro do bloco:

```text
16 = 2^4
```

Assim, o endereço de 32 bits é dividido da seguinte forma:

31                  14 13          4 3        0
+---------------------+-------------+----------+
|        TAG          |    INDEX    |  OFFSET  |
+---------------------+-------------+----------+
        18 bits          10 bits       4 bits

## Campos do endereço

| Campo  |      Bits | Tamanho | Função                                                             |
| ------ | --------: | ------: | ------------------------------------------------------------------ |
| Tag    | `[31:14]` | 18 bits | Identifica qual bloco da memória está armazenado na linha da cache |
| Index  |  `[13:4]` | 10 bits | Seleciona uma das 1024 linhas da cache                             |
| Offset |   `[3:0]` |  4 bits | Seleciona uma posição dentro do bloco de 16 bytes                  |



Como cada bloco possui 4 palavras de 32 bits, os bits addr[3:2] são usados para selecionar qual palavra será lida ou escrita dentro do bloco:

| `addr[3:2]` | Palavra selecionada | Bits do bloco |
| ----------- | ------------------- | ------------- |
| `2'b00`     | Palavra 0           | `[31:0]`      |
| `2'b01`     | Palavra 1           | `[63:32]`     |
| `2'b10`     | Palavra 2           | `[95:64]`     |
| `2'b11`     | Palavra 3           | `[127:96]`    |


## Política de Escrita

A política de escrita adotada neste projeto é write-back.

Na política write-back, quando a CPU realiza uma escrita em um endereço que está presente na cache, o dado é atualizado apenas na cache. A memória principal não é atualizada imediatamente.

A linha modificada é marcada com dirty = 1.

A memória principal só será atualizada posteriormente, quando esse bloco precisar ser substituído por outro bloco.

### Vantagem

A política write-back reduz a quantidade de escritas na memória principal, pois várias escritas podem ser feitas na cache antes que seja necessário atualizar a memória.

### Consequência

A cache precisa controlar quais blocos foram modificados. Por isso, cada linha possui um dirty bit.

## Política de Alocação

A política de alocação adotada é write-allocate.

Na política write-allocate, quando ocorre uma escrita em um endereço que não está presente na cache, o bloco correspondente é primeiro buscado na memória principal e carregado para a cache. Depois disso, a escrita é feita na palavra correta dentro do bloco carregado.

Portanto, uma escrita com miss segue o seguinte comportamento geral:

CPU solicita escrita
Cache detecta miss
Cache busca o bloco na memória principal
Cache aloca o bloco
Cache modifica a palavra solicitada
Cache marca a linha como dirty
Cache responde à CPU

## Estados da Máquina de Estados

O controlador de cache é implementado como uma máquina de estados finitos, ou FSM.

A FSM possui quatro estados principais:

IDLE
COMPARE_TAG
ALLOCATE
WRITE_BACK

### Estado IDLE

O estado IDLE é o estado de repouso do controlador.

Nesse estado, a cache aguarda uma requisição válida da CPU.

Se não houver requisição válida, o controlador permanece em IDLE.

Se houver uma requisição válida, o controlador avança para o estado COMPARE_TAG.

Fluxo conceitual:

Se cpu_req.valid == 0:
    permanecer em IDLE

Se cpu_req.valid == 1:
    ir para COMPARE_TAG

### Estado COMPARE_TAG

O estado COMPARE_TAG é responsável por verificar se a requisição da CPU gera um hit ou um miss.

Nesse estado, o controlador:

1 - Usa o campo index do endereço para acessar a linha correspondente da cache.
2 - Lê a tag armazenada nessa linha.
3 - Lê o valid bit.
4 - Compara a tag armazenada com a tag do endereço solicitado.
5 - Decide se ocorreu hit ou miss.

A condição de hit é:

hit = valid == 1 && tag_armazenada == tag_do_endereco

#### Em caso de hit de leitura

Se a requisição for uma leitura e houver hit:

Cache seleciona a palavra correta dentro do bloco
Cache retorna o dado para a CPU
Cache sinaliza ready
FSM retorna para IDLE

#### Em caso de hit de escrita

Se a requisição for uma escrita e houver hit:

Cache seleciona a palavra correta dentro do bloco
Cache modifica essa palavra
Cache mantém valid = 1
Cache marca dirty = 1
Cache sinaliza ready
FSM retorna para IDLE

#### Em caso de miss

Se houver miss, o controlador verifica a situação da linha antiga.

Existem três possibilidades:

1 - Linha inválida
2 - Linha válida e limpa
3 - Linha válida e suja

Se a linha estiver inválida ou limpa, o controlador pode buscar diretamente o novo bloco na memória principal.

Se a linha estiver suja, o controlador precisa primeiro escrever o bloco antigo de volta na memória principal.

Fluxo conceitual:

Se miss e linha inválida:
    ir para ALLOCATE

Se miss e linha limpa:
    ir para ALLOCATE

Se miss e linha suja:
    ir para WRITE_BACK

### Estado ALLOCATE

O estado ALLOCATE é responsável por buscar o novo bloco na memória principal.

Esse estado ocorre em situações de miss.

Nesse estado, o controlador:

Solicita à memória principal a leitura do bloco correspondente ao endereço da CPU.
Aguarda a memória sinalizar ready.
Recebe o bloco de 128 bits vindo da memória principal.
Escreve esse bloco na linha selecionada da cache.
Atualiza a tag da linha.
Marca a linha como válida.
Retorna para COMPARE_TAG.

Fluxo conceitual:

ALLOCATE:
    solicitar leitura do bloco novo

    se mem_data.ready == 0:
        permanecer em ALLOCATE

    se mem_data.ready == 1:
        armazenar bloco na cache
        retornar para COMPARE_TAG

O retorno para COMPARE_TAG permite que a requisição original seja reavaliada. Após o bloco ser carregado, a comparação de tag deve resultar em hit.

## Fluxos Esperados

#### Leitura com hit

IDLE -> COMPARE_TAG -> IDLE


#### Leitura com miss em linha inválida ou limpa

IDLE -> COMPARE_TAG -> ALLOCATE -> COMPARE_TAG -> IDLE

#### Leitura com miss em linha suja

IDLE -> COMPARE_TAG -> WRITE_BACK -> ALLOCATE -> COMPARE_TAG -> IDLE

#### Escrita com hit

IDLE -> COMPARE_TAG -> IDLE

#### Escrita com miss em linha inválida ou limpa

IDLE -> COMPARE_TAG -> ALLOCATE -> COMPARE_TAG -> IDLE

#### Escrita com miss em linha suja

IDLE -> COMPARE_TAG -> WRITE_BACK -> ALLOCATE -> COMPARE_TAG -> IDLE

## Estrutura do Projeto

A organização sugerida para o projeto é:

trabalho_pratico_1_arquitetura_3/
├── src/
│   ├── cache_def.sv
│   ├── dm_cache_data.sv
│   ├── dm_cache_tag.sv
│   ├── dm_cache_fsm.sv
│   └── main_memory.sv
│
├── tb/
│   └── tb_dm_cache_fsm.sv
│
├── sim/
│   └── wave.vcd
│
└── README.md

## Descrição dos Arquivos

```text
src/cache_def.sv
```

Arquivo responsável por armazenar as definições globais do projeto.

Contém:

Parâmetros da tag
- Tipo da entrada de tag
- Tipo do bloco de dados da cache
- Tipo da requisição da CPU para a cache
- Tipo da resposta da cache para a CPU
- Tipo da requisição da cache para a memória
- Tipo da resposta da memória para a cache

```text
src/dm_cache_data.sv
```
Implementa a memória de dados da cache.

A cache possui 1024 linhas, e cada linha armazena um bloco de 128 bits.

Cada bloco representa quatro palavras de 32 bits.

```text
src/dm_cache_tag.sv
```
Implementa a memória de tags da cache.

Cada linha da cache possui uma entrada de tag contendo:

- valid
- dirty
- tag





####
####
####
####
####
####
####
####
####
####
####
####
####
####
####
####
####



























### Estado WRITE_BACK

O estado WRITE_BACK é usado quando ocorre um miss em uma linha válida e suja.

Uma linha suja contém dados modificados que ainda não foram atualizados na memória principal. Por isso, antes de substituir essa linha, o controlador precisa salvar o bloco antigo na memória.

Nesse estado, o controlador:

Monta o endereço do bloco antigo.
Envia o bloco antigo para a memória principal.
Solicita uma operação de escrita na memória.
Aguarda a memória sinalizar ready.
Após a conclusão da escrita, avança para ALLOCATE.

Fluxo conceitual:

WRITE_BACK:
    enviar bloco antigo para memória

    se mem_data.ready == 0:
        permanecer em WRITE_BACK

    se mem_data.ready == 1:
        ir para ALLOCATE

#### Observação importante

No write-back, o endereço usado não é o endereço novo solicitado pela CPU.

O endereço usado no write-back deve ser o endereço do bloco antigo, formado pela tag antiga armazenada na cache e pelo índice da linha atual.

De forma conceitual:

endereco_write_back = {tag_antiga, index, offset_zero}