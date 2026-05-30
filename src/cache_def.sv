// Aqui estão as definicoes globais do projeto.

// O código foi organizado a partir do modelo apresentado na Secao 5.12 do livro Computer Organization and Design: The Hardware/Software Interface RISC-V Edition, de Patterson & Hennessy.

// ---------------------------------------------------------------------------
// Obs: Grande parte dos comentários foram tirados ou baseados nos comentários do livro, mas traduzidos. 
// Caso necessário, o arquivo 'rascunho_do_livro.v' tem alguns desses comentários originais.
// ---------------------------------------------------------------------------

// A cache modelada é uma cache mapeada diretamente, com:
// - endereco de 32 bits;
// - 1024 linhas/blocos;
// - bloco de 128 bits, ou seja, 4 palavras de 32 bits;
// - tag de 18 bits;
// - indice de 10 bits;
// - offset de 4 bits;
// - politica write-back com write-allocate.

`timescale 1ns/1ps

package cache_def;


  // Bits da tag no endereco de 32 bits.
  // No modelo do livro:
  // addr[31:14] = tag
  // addr[13:4]  = index
  // addr[3:0]   = offset dentro do bloco

  parameter int TAGMSB = 31;
  parameter int TAGLSB = 14;

  // Bits do indice da cache.
  // 1024 linhas = 2^10, logo o indice possui 10 bits.
  /* verilator lint_off UNUSEDPARAM */
  parameter int INDEXMSB = 13;
  parameter int INDEXLSB = 4;
  parameter int INDEX_BITS = 10;
  /* verilator lint_off UNUSEDPARAM */
  parameter int CACHE_LINES = 1024;

  // Bits de offset dentro do bloco.
  // Cada bloco tem 16 bytes = 2^4, logo o offset possui 4 bits.
  /* verilator lint_off UNUSEDPARAM */
  parameter int OFFSETMSB = 3;
  parameter int OFFSETLSB = 0;
  parameter int OFFSET_BITS = 4;
  /* verilator lint_off UNUSEDPARAM */

  // Cada bloco possui 4 palavras de 32 bits.
  parameter int WORD_BITS = 32;
  parameter int WORDS_PER_BLOCK = 4;
  parameter int BLOCK_BITS = WORD_BITS * WORDS_PER_BLOCK;

  // ---------------------------------------------------------------------------
  // Tipos basicos
  // ---------------------------------------------------------------------------

  // Linha/bloco de dados da cache: 128 bits.
  //typedef bit [BLOCK_BITS-1:0] cache_data_type;
  //  Aqui abrimos mão da dinamicidade de estabelecer o tamanho via o tamanho do bloco
  // pois o verilog reclama de tentar estabelecer dinamicamente o tamanho disso.
  //  Não é impossível definir com base em uma variável, mas não descobri uma maneira
  // fácil, então decide que não vale a pena a considerar o escopo desse projeto.
  typedef bit [127:0] cache_data_type;

  // Entrada da memoria de tags da cache.
  // Cada linha possui:
  // - valid: indica se a linha contem um bloco valido;
  // - dirty: indica se o bloco foi modificado e ainda nao foi escrito na memoria;
  // - tag: identifica qual bloco da memoria principal esta armazenado na linha.
  typedef struct packed {
    bit valid;
    bit dirty;
    bit [TAGMSB:TAGLSB] tag;
    //bit [31:14] tag;
  } cache_tag_type;

  // Requisicao interna para acessar a memoria de dados ou de tags da cache.
  // O campo index seleciona uma das 1024 linhas.
  // O campo we habilita escrita quando vale 1.
  typedef struct packed {
    //bit [INDEX_BITS-1:0] index;
    bit [9:0] index;
    bit we;
  } cache_req_type;

  // ---------------------------------------------------------------------------
  // Interface CPU -> Cache
  // ---------------------------------------------------------------------------

  // Requisicao enviada pela CPU para a cache.
  typedef struct packed {
    bit [31:0] addr;   // endereco de byte solicitado pela CPU
    bit [31:0] data;   // dado de escrita, usado quando rw = 1
    bit rw;            // 0 = leitura, 1 = escrita
    bit valid;         // indica que a requisicao e valida
  } cpu_req_type;

  // Resposta enviada pela cache para a CPU.
  typedef struct packed {
    bit [31:0] data;   // dado lido, usado em operacoes de leitura
    bit ready;         // indica que a cache terminou a requisicao
  } cpu_result_type;

  // ---------------------------------------------------------------------------
  // Interface Cache -> Memoria principal
  // ---------------------------------------------------------------------------

  // Requisicao enviada pela cache para a memoria principal.
  // A memoria principal trabalha com blocos completos de 128 bits.
  typedef struct packed {
    bit [31:0] addr;   // endereco de byte do bloco solicitado
    bit [127:0] data;  // bloco escrito na memoria quando rw = 1
    bit rw;            // 0 = leitura, 1 = escrita
    bit valid;         // indica que a requisicao para memoria e valida
  } mem_req_type;

  // Resposta enviada pela memoria principal para a cache.
  typedef struct packed {
    cache_data_type data; // bloco de 128 bits retornado pela memoria
    bit ready;            // indica que a memoria concluiu a operacao
  } mem_data_type;

endpackage
