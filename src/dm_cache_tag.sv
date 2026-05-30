
// O código foi organizado a partir do modelo apresentado na Secao 5.12 do livro Computer Organization and Design: The Hardware/Software Interface RISC-V Edition, de Patterson & Hennessy.

// ---------------------------------------------------------------------------
// Obs: Grande parte dos comentários foram tirados ou baseados nos comentários do livro, mas traduzidos. 
// Caso necessário, o arquivo 'rascunho_do_livro.v' tem alguns desses comentários originais.
// ---------------------------------------------------------------------------

// A memoria de tags possui:
// - 1024 entradas;
// - uma entrada por linha da cache;
// - cada entrada contem valid bit, dirty bit e tag;
// - leitura combinacional;
// - escrita sincronizada na borda positiva do clock.
// -----------------------------------------------------------------------------

`timescale 1ns/1ps

/* verilator lint_off IMPORTSTAR */
import cache_def::*;
/* verilator lint_on IMPORTSTAR */

module dm_cache_tag (
  input  bit            clk,
  input  cache_req_type tag_req,
  input  cache_tag_type tag_write,
  output cache_tag_type tag_read
);

  // ---------------------------------------------------------------------------
  // Memoria interna de tags
  // ---------------------------------------------------------------------------
  //
  // Cada posicao do vetor representa os metadados de uma linha da cache.
  //
  // tag_mem[0]    -> valid, dirty e tag da linha 0
  // tag_mem[1]    -> valid, dirty e tag da linha 1
  // ...
  // tag_mem[1023] -> valid, dirty e tag da linha 1023
  //
  // O indice da linha vem de tag_req.index.
  // ---------------------------------------------------------------------------

  cache_tag_type tag_mem [0:CACHE_LINES-1];
  //cache_tag_type tag_mem [0:1023];

  // ---------------------------------------------------------------------------
  // Inicializacao da memoria de tags
  // ---------------------------------------------------------------------------
  //
  // Para fins de simulacao, todas as entradas comecam zeradas.
  //
  // Isso significa:
  // - valid = 0;
  // - dirty = 0;
  // - tag = 0.
  //
  // O ponto mais importante e valid = 0, pois indica que a cache esta inicialmente vazia. Assim, o primeiro acesso a qualquer linha deve gerar miss.
  // ---------------------------------------------------------------------------

  initial begin
    for (int i = 0; i < CACHE_LINES; i++) begin
    //for (int i = 0; i < 1024; i++) begin
      tag_mem[i] = '0;
    end
  end

  // ---------------------------------------------------------------------------
  // Leitura combinacional
  // ---------------------------------------------------------------------------
  //
  // A saida tag_read reflete continuamente a entrada de tag da linha selecionada.
  //
  // O controlador usa essa informacao para:
  // - verificar valid bit;
  // - comparar a tag armazenada com a tag do endereco solicitado;
  // - verificar dirty bit em caso de miss;
  // - decidir se deve ir para ALLOCATE ou WRITE_BACK.
  // ---------------------------------------------------------------------------

  assign tag_read = tag_mem[tag_req.index];

  // ---------------------------------------------------------------------------
  // Escrita sincronizada
  // ---------------------------------------------------------------------------
  //
  // A escrita ocorre apenas na borda positiva do clock e somente quando
  // tag_req.we == 1.
  //
  // Em uma escrita, o controlador atualiza a entrada inteira:
  // - valid;
  // - dirty;
  // - tag.
  //
  // Esse comportamento segue o modelo do livro, no qual a entrada de tag é tratada como uma estrutura unica. Portanto, mesmo quando apenas o dirty bit muda, a FSM escreve novamente a entrada completa.
  // ---------------------------------------------------------------------------

  always @(posedge clk) begin
    if (tag_req.we) begin
      tag_mem[tag_req.index] <= tag_write;
    end
  end

endmodule
