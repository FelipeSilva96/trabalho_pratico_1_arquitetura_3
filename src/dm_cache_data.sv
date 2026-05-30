
// O código foi organizado a partir do modelo apresentado na Secao 5.12 do livro Computer Organization and Design: The Hardware/Software Interface RISC-V Edition, de Patterson & Hennessy.

// ---------------------------------------------------------------------------
// Obs: Grande parte dos comentários foram tirados ou baseados nos comentários do livro, mas traduzidos. 
// Caso necessário, o arquivo 'rascunho_do_livro.v' tem alguns desses comentários originais.
// ---------------------------------------------------------------------------

// A memoria de dados possui:
// - 1024 linhas;
// - cada linha armazena um bloco de 128 bits;
// - cada bloco contem 4 palavras de 32 bits;
// - leitura combinacional;
// - escrita sincronizada na borda positiva do clock.
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

import cache_def::*;

module dm_cache_data (
  input  bit             clk,
  input  cache_req_type  data_req,
  input  cache_data_type data_write,
  output cache_data_type data_read
);

  // ---------------------------------------------------------------------------
  // Memoria interna de dados da cache
  // ---------------------------------------------------------------------------
  //
  // Cada posicao do vetor representa uma linha da cache.
  //
  // Como a cache possui 1024 linhas e cada linha possui 128 bits:
  //
  // data_mem[0]    -> bloco armazenado na linha 0
  // data_mem[1]    -> bloco armazenado na linha 1
  // ...
  // data_mem[1023] -> bloco armazenado na linha 1023
  //
  // O indice da linha vem de data_req.index.
  // ---------------------------------------------------------------------------

  cache_data_type data_mem [0:CACHE_LINES-1];
  //cache_data_type data_mem [0:1023];

  // ---------------------------------------------------------------------------
  // Inicializacao da memoria de dados
  // ---------------------------------------------------------------------------
 
  initial begin
    for (int i = 0; i < CACHE_LINES; i++) begin
    //for (int i = 0; i < 1024; i++) begin
      data_mem[i] = '0;
    end
  end

  // ---------------------------------------------------------------------------
  // Leitura combinacional
  // ---------------------------------------------------------------------------
  //
  // A saida data_read reflete continuamente o conteudo da linha selecionada.
  // Isso segue o modelo  do livro, no qual a memoria da cache é lida pelo indice e o dado fica disponivel para o controlador comparar tags, selecionar palavras e responder a CPU.
  // ---------------------------------------------------------------------------

  assign data_read = data_mem[data_req.index];

  // ---------------------------------------------------------------------------
  // Escrita sincronizada
  // ---------------------------------------------------------------------------
  //
  // A escrita ocorre apenas na borda positiva do clock e somente quando
  // data_req.we == 1.
  //
  // Em caso de escrita:
  // - data_req.index seleciona a linha da cache;
  // - data_write contem o bloco completo de 128 bits a ser gravado.
  //
  // Mesmo quando apenas uma palavra de 32 bits é modificada, o controlador monta previamente o bloco completo atualizado em data_write.
  // ---------------------------------------------------------------------------

  always @(posedge clk) begin
    if (data_req.we) begin
      data_mem[data_req.index] <= data_write;
    end
  end

endmodule