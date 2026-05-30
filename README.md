# 📘 Trabalho Prático 1 — Controlador de Cache

## 🎯 Objetivo

Este projeto tem como objetivo implementar, simular e analisar um **controlador de cache** em **SystemVerilog**, com base no modelo apresentado no livro _Computer Organization and Design: The Hardware/Software Interface — RISC-V Edition_, de Patterson & Hennessy.

O foco principal do trabalho é compreender, por meio de implementação prática, como uma cache simples interage com a CPU e com a memória principal, tratando corretamente acessos de leitura, escrita, hits, misses, substituição de blocos e escrita de blocos modificados.

Este projeto tem caráter didático e acadêmico. O objetivo não é implementar uma cache industrial altamente otimizada, mas sim uma cache funcional, organizada e bem documentada, capaz de demonstrar os principais conceitos de hierarquia de memória estudados na disciplina **Arquitetura de Computadores III**.

### ⚠️ **Ponto importante**

O arquivo `rascunho_do_livro.sv` <u>***NÃO FAZ***</u> parte do projeto diretamente, portanto o mesmo não compila por ser uma cópia grosseira do conteúdo do livro _Computer Organization and Design: The Hardware/Software Interface — RISC-V Edition_ - Seção 5.12, servindo apenas para ter um ponto de referência tirado diretamente do livro. 

---

## 🧠 Conceitos Envolvidos

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

## 📝 Descrição Geral do Projeto

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

## 🏗️ Organização do Endereço

A cache trabalha com endereços de 32 bits.

Como a cache possui 1024 linhas, são necessários 10 bits para selecionar a linha da cache:

$\log _2{1024} = 10$

Como cada bloco possui 16 bytes, são necessários 4 bits para selecionar o byte dentro do bloco:

$\log _2{16} = 4$

Assim, o endereço de 32 bits é dividido da seguinte forma:

| Bits [31:14] | Bits [13:4] | Bits [3:0] |
| :----------- | :---------- | :--------- |
| **TAG**      | **INDEX**   | **OFFSET** |
| 18 bits      | 10 bits     | 4 bits     |

---

## 📍 Campos do endereço

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

## ✍️ Política de Escrita

A política de escrita adotada neste projeto é write-back.

Na política write-back, quando a CPU realiza uma escrita em um endereço que está presente na cache, o dado é atualizado apenas na cache. A memória principal não é atualizada imediatamente.

A linha modificada é marcada com dirty = 1.

A memória principal só será atualizada posteriormente, quando esse bloco precisar ser substituído por outro bloco.

### 🟢 Vantagem

A política write-back reduz a quantidade de escritas na memória principal, pois várias escritas podem ser feitas na cache antes que seja necessário atualizar a memória.

### 🛑 Consequência

A cache precisa controlar quais blocos foram modificados. Por isso, cada linha possui um dirty bit.

---

## 🔍 Política de Alocação

A política de alocação adotada é write-allocate.

Na política write-allocate, quando ocorre uma escrita em um endereço que não está presente na cache, o bloco correspondente é primeiro buscado na memória principal e carregado para a cache. Depois disso, a escrita é feita na palavra correta dentro do bloco carregado.

Portanto, uma escrita com miss segue o seguinte comportamento geral:

- CPU solicita escrita
- Cache detecta miss
- Cache busca o bloco na memória principal
- Cache aloca o bloco
- Cache modifica a palavra solicitada
- Cache marca a linha como dirty
- Cache responde à CPU

---

## 🤖 Estados da Máquina de Estados

O controlador de cache é implementado como uma máquina de estados finitos, ou FSM.

A FSM possui quatro estados principais:

- **IDLE**
- **COMPARE_TAG**
- **ALLOCATE**
- **WRITE_BACK**

### 💤 Estado IDLE

O estado IDLE é o estado de repouso do controlador.

Nesse estado, a cache aguarda uma requisição válida da CPU.

Se não houver requisição válida, o controlador permanece em IDLE.

Se houver uma requisição válida, o controlador avança para o estado COMPARE_TAG.

Fluxo conceitual:

```
Se cpu_req.valid == 0:
    permanecer em IDLE

Se cpu_req.valid == 1:
    ir para COMPARE_TAG
```

### 🔍 Estado COMPARE_TAG

O estado COMPARE_TAG é responsável por verificar se a requisição da CPU gera um hit ou um miss.

Nesse estado, o controlador:

- Usa o campo index do endereço para acessar a linha correspondente da cache.
- Lê a tag armazenada nessa linha.
- Lê o valid bit.
- Compara a tag armazenada com a tag do endereço solicitado.
- Decide se ocorreu hit ou miss.

A condição de hit é:

```
hit = valid == 1 && tag_armazenada == tag_do_endereco
```

#### Em caso de hit de leitura

Se a requisição for uma leitura e houver hit:

```
Cache seleciona a palavra correta dentro do bloco
Cache retorna o dado para a CPU
Cache sinaliza ready
FSM retorna para IDLE
```

#### Em caso de hit de escrita

Se a requisição for uma escrita e houver hit:

```
Cache seleciona a palavra correta dentro do bloco
Cache modifica essa palavra
Cache mantém valid = 1
Cache marca dirty = 1
Cache sinaliza ready
FSM retorna para IDLE
```

#### Em caso de miss

Se houver miss, o controlador verifica a situação da linha antiga.

Existem três possibilidades:

- Linha inválida
- Linha válida e limpa
- Linha válida e suja

Se a linha estiver inválida ou limpa, o controlador pode buscar diretamente o novo bloco na memória principal.

Se a linha estiver suja, o controlador precisa primeiro escrever o bloco antigo de volta na memória principal.

Fluxo conceitual:
```
Se miss e linha inválida:
    ir para ALLOCATE

Se miss e linha limpa:
    ir para ALLOCATE

Se miss e linha suja:
    ir para WRITE_BACK
```

### 💾 Estado WRITE_BACK

O estado WRITE_BACK é usado quando ocorre um miss em uma linha válida e suja.

Uma linha suja contém dados modificados que ainda não foram atualizados na memória principal. Por isso, antes de substituir essa linha, o controlador precisa salvar o bloco antigo na memória.

Nesse estado, o controlador:

```
Monta o endereço do bloco antigo.
Envia o bloco antigo para a memória principal.
Solicita uma operação de escrita na memória.
Aguarda a memória sinalizar ready.
Após a conclusão da escrita, avança para ALLOCATE.
```

Fluxo conceitual:

```
WRITE_BACK:
enviar bloco antigo para memória

    se mem_data.ready == 0:
        permanecer em WRITE_BACK

    se mem_data.ready == 1:
        ir para ALLOCATE
```

#### Observação importante

No write-back, o endereço usado não é o endereço novo solicitado pela CPU.

O endereço usado no write-back deve ser o endereço do bloco antigo, formado pela tag antiga armazenada na cache e pelo índice da linha atual.

De forma conceitual:
```
endereco_write_back = {tag_antiga, index, offset_zero}
```
### 🏗️ Estado ALLOCATE

O estado ALLOCATE é responsável por buscar o novo bloco na memória principal.

Esse estado ocorre em situações de miss.

Nesse estado, o controlador:

- Solicita à memória principal a leitura do bloco correspondente ao endereço da CPU.
- Aguarda a memória sinalizar ready.
- Recebe o bloco de 128 bits vindo da memória principal.
- Escreve esse bloco na linha selecionada da cache.
- Atualiza a tag da linha.
- Marca a linha como válida.
- Retorna para COMPARE_TAG.

Fluxo conceitual:

```
ALLOCATE:
solicitar leitura do bloco novo

    se mem_data.ready == 0:
        permanecer em ALLOCATE

    se mem_data.ready == 1:
        armazenar bloco na cache
        retornar para COMPARE_TAG
```

O retorno para COMPARE_TAG permite que a requisição original seja reavaliada. Após o bloco ser carregado, a comparação de tag deve resultar em hit.

---

## 🌊  Fluxos Esperados

#### Leitura com hit
```
IDLE -> COMPARE_TAG -> IDLE
```
#### Leitura com miss em linha inválida ou limpa
```
IDLE -> COMPARE_TAG -> ALLOCATE -> COMPARE_TAG -> IDLE
```
#### Leitura com miss em linha suja
```
IDLE -> COMPARE_TAG -> WRITE_BACK -> ALLOCATE -> COMPARE_TAG -> IDLE
```
#### Escrita com hit
```
IDLE -> COMPARE_TAG -> IDLE
```
#### Escrita com miss em linha inválida ou limpa
```
IDLE -> COMPARE_TAG -> ALLOCATE -> COMPARE_TAG -> IDLE
```
#### Escrita com miss em linha suja
```
IDLE -> COMPARE_TAG -> WRITE_BACK -> ALLOCATE -> COMPARE_TAG -> IDLE
```

---

## 📂 Estrutura do Projeto

A organização sugerida para o projeto é:

```
trabalho_pratico_1_arquitetura_3/
├── src/
│ ├── cache_def.sv
│ ├── dm_cache_data.sv
│ ├── dm_cache_fsm.sv
│ ├── dm_cache_tag.sv
│ └── main_memory.sv
│
├── tb/
│ └── tb_dm_cache.sv
│
├── sim/
│ └── sim_cache.cpp
│ └── wave.vcd
│
├── rascunho_do_livro.sv
└── README.md
```

---

## 📄 Descrição dos Arquivos

`src/cache_def.sv`

Arquivo responsável por armazenar as definições globais do projeto.

Contém:

Parâmetros da tag

- Tipo da entrada de tag
- Tipo do bloco de dados da cache
- Tipo da requisição da CPU para a cache
- Tipo da resposta da cache para a CPU
- Tipo da requisição da cache para a memória
- Tipo da resposta da memória para a cache

`src/dm_cache_data.sv`

Implementa a memória de dados da cache.

A cache possui 1024 linhas, e cada linha armazena um bloco de 128 bits.

Cada bloco representa quatro palavras de 32 bits.

`src/dm_cache_tag.sv`

Implementa a memória de tags da cache.

Cada linha da cache possui uma entrada de tag contendo:

- `valid`
- `dirty`
- `tag`

`src/dm_cache_fsm.sv`

Implementa o controlador principal da cache.

Esse módulo é responsável por:

- Receber requisições da CPU
- Detectar hit ou miss
- Controlar leituras da cache
- Controlar escritas na cache
- Controlar alocação de novos blocos
- Controlar write-back de blocos sujos
- Gerar requisições para a memória principal
- Retornar resposta para a CPU
- Controlar a FSM da cache

`src/main_memory.sv`

Implementa um modelo simplificado de memória principal para simulação.

Esse módulo deve responder às requisições da cache por meio de um sinal ready.

A memória principal trabalha com blocos de 128 bits.

`tb/tb_dm_cache.sv`

Arquivo de testbench do projeto.

É responsável por:

- Gerar clock
- Gerar reset
- Enviar requisições de leitura para a cache
- Enviar requisições de escrita para a cache
- Verificar hits
- Verificar misses
- Verificar alocação de blocos
- Verificar substituição de blocos
- Verificar write-back
- Gerar arquivo .vcd para visualização no GTKWave

`sim/sim_cache.cpp`

Arquivo para compilação do projeto via Verilator

---

## 🛠️ Ferramentas Utilizadas

O projeto utiliza as seguintes ferramentas:

- `SystemVerilog
`
- `Verilator
`
- `Icarus Verilog
`
- `GTKWave
`

---

## 🐧 Instalação no Linux

Para instalar as ferramentas necessárias em distribuições baseadas em Ubuntu/Debian:

```
sudo apt update
sudo apt install iverilog gtkwave
apt-get install verilator
```

Para verificar se a instalação foi concluída corretamente:

```
iverilog -V
gtkwave --version
verilator --version
```


#### Compilação

Para compilar o projeto:

Via Icarus Verilog:
```
iverilog -g2012 -o simv src/*.sv tb/tb_dm_cache.sv
```

Via Verilator:
```
make
```

#### Execução

Via Icarus Verilog:
```
vvp simv
```

Via Verilator a execução será realizada junto à compilação

#### Visualização da Waveform

Após a execução, o testbench deve gerar um arquivo .vcd.

Para abrir no GTKWave:

```
gtkwave wave.vcd
```

Caso o arquivo seja gerado dentro da pasta sim/, use:

```
gtkwave sim/wave.vcd
```

---

## 🟦 Uso no Windows

#### Opção recomendada: WSL

A forma mais recomendada de executar o projeto no Windows é usando o WSL.

Para instalar o WSL:

```
wsl --install
```

Depois, dentro do Ubuntu/WSL:

```
sudo apt update
sudo apt install iverilog gtkwave
```

Em seguida, compile e execute normalmente:
```
iverilog -g2012 -o simv src/\*.sv tb/tb_dm_cache.sv
vvp simv
```

---

## 🧪 Testes Implementados

O testbench deve validar os principais comportamentos esperados do controlador de cache.

Os testes estão organizados nas seguintes categorias:

- Testes de leitura
- Testes de escrita
- Testes de substituição
- Testes de write-back
- Testes de consistência
- Testes de casos limite

### Testes de Leitura

#### Leitura com miss inicial

Esse teste verifica o comportamento da cache inicialmente vazia.

Fluxo esperado:
```

CPU solicita leitura
Cache detecta miss
Cache solicita bloco à memória principal
Memória retorna bloco
Cache atualiza linha, tag e valid bit
Cache retorna o dado solicitado à CPU

```

Esse teste valida:

- Cache inicialmente inválida
- Detecção de miss
- Alocação de bloco
- Atualização de tag
- Atualização de valid bit
- Retorno correto do dado para a CPU


#### Leitura com hit

Esse teste verifica se a cache consegue responder diretamente a uma leitura quando o bloco já está presente.

Fluxo esperado:

```

CPU solicita leitura de um endereço já carregado
Cache detecta hit
Cache seleciona a palavra correta dentro do bloco
Cache retorna o dado para a CPU
Memória principal não precisa ser acessada

```

Esse teste valida:

- Comparação correta de tag
- Uso correto do valid bit
- Seleção correta da palavra pelo offset
- Resposta rápida em caso de hit


#### Leitura em diferentes offsets do mesmo bloco

Esse teste verifica se a cache consegue selecionar corretamente diferentes palavras dentro de um mesmo bloco de 128 bits.

Exemplo:

```
Endereço base + 0 -> palavra 0
Endereço base + 4 -> palavra 1
Endereço base + 8 -> palavra 2
Endereço base + 12 -> palavra 3
```

Esse teste valida o uso correto de addr[3:2].

---

## ✍️ Testes de Escrita

#### Escrita com hit

Esse teste verifica o comportamento da cache quando a CPU escreve em um endereço cujo bloco já está carregado.

Fluxo esperado:

```
CPU solicita escrita
Cache detecta hit
Cache atualiza a palavra correta dentro do bloco
Cache marca dirty bit
Cache retorna ready para a CPU
```

Esse teste valida:

- Escrita correta na palavra selecionada
- Preservação das demais palavras do bloco
- Atualização do dirty bit
- Manutenção do valid bit
- Resposta correta à CPU

#### Escrita com miss

Esse teste verifica o comportamento da cache quando a CPU escreve em um endereço cujo bloco ainda não está carregado.

Como a política usada é write-allocate, o bloco deve ser carregado antes da escrita ser concluída.

Fluxo esperado:

```
CPU solicita escrita
Cache detecta miss
Cache solicita bloco à memória principal
Memória retorna bloco
Cache aloca bloco
Cache realiza a escrita na palavra correta
Cache marca dirty bit
Cache retorna ready para a CPU
```

Esse teste valida:

- Política write-allocate
- Alocação do bloco antes da escrita
- Escrita correta após allocate
- Marcação correta do dirty bit

#### Testes de Substituição

Como a cache é mapeada diretamente, dois endereços diferentes podem mapear para o mesmo índice.

Se esses endereços tiverem tags diferentes, eles competem pela mesma linha da cache.

Exemplo conceitual:

```
Endereço A -> índice X, tag T1
Endereço B -> índice X, tag T21
```

Ao acessar B depois de A, a linha X deve passar a armazenar o bloco de B.

Esse teste valida:

- Cálculo correto do índice
- Comparação correta da tag
- Detecção de conflict miss
- Substituição da linha correta

#### Testes de Write-Back

Esse teste verifica se a cache escreve corretamente um bloco sujo de volta na memória principal antes de substituí-lo.

Fluxo esperado:

```
Bloco A é carregado na cache
Bloco A é modificado por uma escrita
Dirty bit de A é marcado
Bloco B, com mesmo índice e tag diferente, é acessado
Cache detecta miss
Cache percebe que o bloco antigo está dirty
Cache escreve bloco A na memória principal
Cache carrega bloco B
```

Esse teste valida:

- Detecção de bloco sujo
- Geração correta de requisição de escrita para a memória
- Uso correto do endereço do bloco antigo
- Preservação dos dados modificados
- Substituição correta após write-back


#### Testes de Consistência

Os testes de consistência verificam se os dados retornados pela cache são coerentes ao longo de várias operações.

Cenários esperados:

```
Ler endereço A
Escrever novo valor em A
Ler A novamente
Verificar se o novo valor é retornado
```

Outro cenário:

```
Carregar bloco A
Modificar bloco A
Acessar bloco B com mesmo índice
Forçar write-back de A
Acessar A novamente
Verificar se o valor modificado foi preservado
```

Esses testes validam:

- Leitura após escrita
- Preservação de dados modificados
- Atualização correta da memória principal após write-back
- Funcionamento correto em acessos repetidos

#### Testes de Casos Limite

O testbench também deve considerar casos limite, como:

- Cache completamente inválida após reset
- Primeiro acesso após reset
- Acesso ao endereço 0x00000000
- Acessos a endereços altos, se suportados pelo modelo de memória
- Escritas em palavras diferentes do mesmo bloco
- Substituição de linha limpa
- Substituição de linha suja
- Acessos consecutivos ao mesmo endereço
- Acessos consecutivos a endereços com mesmo índice e tags diferentes

---

## 🐞 Sinais Importantes para Debug

Durante a simulação, os principais sinais a serem observados são:

#### Sinais gerais

- `clk`
- `rst`

#### Interface CPU-cache

- `cpu_req.valid`
- `cpu_req.rw`
- `cpu_req.addr`
- `cpu_req.data`
- `cpu_res.ready`
- `cpu_res.data`

#### Interface cache-memória

- `mem_req.valid`
- `mem_req.rw`
- `mem_req.addr`
- `mem_req.data`
- `mem_data.ready`
- `mem_data.data`

#### FSM


- `rstate`
- `vstate`

#### Tag

- `tag_read.valid`
- `tag_read.dirty`
- `tag_read.tag`
- `tag_write.valid`
- `tag_write.dirty`
- `tag_write.tag`
- `tag_req.index`
- `tag_req.we`

#### Dados da cache

- `data_read`
- `data_write`
- `data_req.index`
- `data_req.we`

---

## 💡 Interpretação dos Sinais

`cpu_req.valid`

Indica que a CPU está enviando uma requisição válida para a cache.

`cpu_req.rw`

Indica o tipo da operação solicitada pela CPU.

``0 = leitura |
1 = escrita``

`cpu_res.ready`

Indica que a cache terminou de processar a requisição da CPU.

A CPU só deve considerar o dado válido quando cpu_res.ready == 1.

`mem_req.valid`

Indica que a cache está enviando uma requisição válida para a memória principal.

`mem_req.rw`

Indica o tipo da operação enviada pela cache para a memória.

`0 = leitura da memória |
1 = escrita na memória`

`mem_data.ready`

Indica que a memória principal terminou a operação solicitada.

`dirty`

Indica que a linha da cache foi modificada e ainda não foi escrita de volta na memória principal.

`valid`

Indica que a linha da cache contém um bloco válido.

---

## 🏆 Comportamento Esperado em Alto Nível

O funcionamento geral do controlador pode ser resumido da seguinte forma:

```

CPU envia uma requisição
Cache extrai tag, index e offset
Cache acessa a linha indicada pelo index
Cache compara a tag armazenada com a tag do endereço
Cache verifica o valid bit

Se houver hit:
    Se for leitura:
        retorna a palavra solicitada
    Se for escrita:
        atualiza a palavra solicitada
        marca dirty
        retorna ready

Se houver miss:
    Se a linha antiga estiver dirty:
        escreve o bloco antigo na memória principal

    busca o novo bloco na memória principal
    instala o novo bloco na cache
    atualiza tag e valid bit

    se a operação original era escrita:
        escreve a palavra solicitada
        marca dirty

    retorna ready

```

---

## 📝 Observações sobre o Modelo

Este projeto utiliza uma cache bloqueante.

Isso significa que, enquanto a cache está tratando um miss, a CPU precisa aguardar a conclusão da operação.

Durante esse período, a cache pode precisar esperar a memória principal responder por meio do sinal ready.

Portanto, uma requisição da CPU não necessariamente é concluída em um único ciclo.

---

## 🚫 Possíveis Limitações

Por ser um projeto didático, algumas simplificações podem ser adotadas:

- Apenas uma requisição da CPU por vez
- Ausência de suporte a múltiplas requisições simultâneas
- Ausência de cache associativa
- Ausência de política LRU
- Ausência de suporte a bytes individuais
- Ausência de suporte completo a desalinhamento de endereço
- Memória principal simplificada para simulação
- Modelo de latência da memória simplificado
- Cache bloqueante

Essas limitações serão documentadas no relatório final do trabalho.

---

## 📊 Métricas e Evidências da Simulação

O projeto pode gerar evidências por meio de:

- Mensagens $display
- Logs no terminal
- Arquivo .vcd
- Visualização no GTKWave
- Tabelas no relatório
- Sequências de testes documentadas

Métricas possíveis:

- Quantidade de leituras
- Quantidade de escritas
- Quantidade de hits
- Quantidade de misses
- Quantidade de write-backs
- Quantidade de alocações
- Quantidade de ciclos por operação

---

## 🎬 Exemplo de Sequência de Teste

```

1. Resetar o sistema
2. Ler endereço A
   Resultado esperado: miss + allocate

3. Ler endereço A novamente
   Resultado esperado: hit

4. Escrever novo valor em A
   Resultado esperado: hit + dirty = 1

5. Ler endereço A
   Resultado esperado: hit + valor atualizado

6. Ler endereço B com mesmo índice de A e tag diferente
   Resultado esperado: miss + write-back de A + allocate de B

7. Ler endereço A novamente
   Resultado esperado: miss + allocate de A com valor preservado na memória

```

---

## 💬 Uso de IA

O uso de ferramentas de IA será documentado no relatório final.

A documentação deve conter:

- Quais ferramentas foram utilizadas
- Quais prompts foram usados
- Em quais partes do projeto a IA auxiliou
- Quais partes foram revisadas manualmente
- Quais correções foram feitas pelo grupo
- Quais decisões técnicas foram tomadas pelos integrantes

---

## 📢 Observação Final

Este projeto foi desenvolvido com finalidade acadêmica para a disciplina Arquitetura de Computadores III.

O principal objetivo é compreender, por meio de simulação, como um controlador de cache opera internamente, incluindo hits, misses, escrita em cache, dirty bit, write-back, alocação de blocos e controle sequencial por FSM.

### 🎓 **Autores**

- [**Felipe Pereira da Silva**](https://github.com/FelipeSilva96)
- [**Rikerson Antônio Freitas**](https://github.com/HansJung22)
- [**Diego Feitosa Ferreira**](https://github.com/Sil3ncy)
- [**Kauan Gabriel Pereira**](https://github.com/KauanHauger02)
- [**Mateus Resende Ottoni**](https://github.com/Mateus-Resende-Ottoni)
---
