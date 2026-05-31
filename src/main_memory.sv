`timescale 1ns/1ps

/* verilator lint_off IMPORTSTAR */
import cache_def::*;
/* verilator lint_on IMPORTSTAR */

module main_memory #(
    parameter int LATENCY = 10 
)(
    input  logic           clk,
    input  mem_req_type    mem_req,  
    output mem_data_type   mem_data  
);

    // 1. Armazenamento Esparso (Array Associativo)
    cache_data_type memory_array [int];

    // 2. Máquina de Estados Interna para simular Latência
    typedef enum logic [1:0] {IDLE, WAIT_LATENCY, RESPOND} state_t;
    state_t state = IDLE;

    int counter;
    
    // Ajuste de largura para 32 bits para casar com a chave [int] e evitar WIDTHTRUNC/EXPAND
    bit [31:0] block_addr;
    assign block_addr = {4'b0000, mem_req.addr[31:4]};

    // 3. Lógica Sequencial da Memória
    always_ff @(posedge clk) begin
        // Valor padrão da saída (Evita latches e resolve o erro BLKANDNBLK)
        // Toda a struct mem_data agora é controlada de forma não-bloqueante (<=)
        mem_data.ready <= 1'b0;

        case (state)
            IDLE: begin
                if (mem_req.valid) begin
                    state   <= WAIT_LATENCY;
                    counter <= LATENCY;
                end
            end

            WAIT_LATENCY: begin
                if (counter > 0) begin
                    counter <= counter - 1; 
                end else begin
                    if (mem_req.rw == 1'b1) begin
                        // ESCRITA
                        // Silencia o aviso BLKSEQ para manipulação segura de array dinâmico
                        /* verilator lint_off BLKSEQ */
                        memory_array[block_addr] = mem_req.data;
                        /* verilator lint_on BLKSEQ */
                    end else begin
                        // LEITURA
                        // exists() retorna int. A comparação '== 0' evita WIDTHTRUNC do operador '!'
                        if (memory_array.exists(block_addr) == 0) begin
                            /* verilator lint_off BLKSEQ */
                            memory_array[block_addr] = 128'h0;
                            /* verilator lint_on BLKSEQ */
                        end
                        mem_data.data <= memory_array[block_addr];
                    end
                    
                    // Dispara o sinal de pronto
                    mem_data.ready <= 1'b1;
                    state <= RESPOND;
                end
            end

            RESPOND: begin
                // mem_data.ready cai para 0 naturalmente pelo estado padrão (default) no topo
                state <= IDLE;
            end

            default: state <= IDLE;
        endcase
    end

endmodule
