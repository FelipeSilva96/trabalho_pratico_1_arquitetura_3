/*
---------------------------------------------------------------------------------------------
Neste arquivo encontra se o modelo para a memoria principal da maquina que estamos simulando
---------------------------------------------------------------------------------------------
Esse módulo deve responder às requisições da cache por meio de um sinal ready.
A memória principal trabalha com blocos de 128 bits. 
---------------------------------------------------------------------------------------------

---------------------------------------------------------------------------------------------
Uma requisicao de acesso a memoria e definida por:
=>32 bits de endereco => 4.294.967.296 endereços distintos
=>cada palavra na memoria principal possui 32 bits 
=>128 bits de dados
=>ao buscar um dado na memoria principal, resgatamos os dados do endereço especifico + 3 seguintes = 128 bits de dados
---------------------------------------------------------------------------------------------
*/
`timescale 1ns/1ps

/* verilator lint_off IMPORTSTAR */
import cache_def::*;
/* verilator lint_on IMPORTSTAR */


module main_memory (
    input bit clk,
    input mem_req_type mem_req, //requisicao do controlador para a memoria
    output mem_data_type mem_data //resposta da memoria contendo bit ready e os 128 bits de dados lidos
);

    // 1028 * 262144 = 2^18 = 268435456
    //  Para não gerar um programa excessivamente grande, diminuímos para haver apenas 8 endereços por
    // índice, já que uma memória completa não é parte do escopo desse projeto
    parameter int NTAGS = 8;
    parameter int NADDR = 8224;
    typedef cache_data_type [NADDR:0] memory_data;


    memory_data memory_storage;
    /* verilator lint_off UNUSEDSIGNAL */
    logic [17:0] req_tag;
    /* verilator lint_on UNUSEDSIGNAL */
    logic [9:0]  req_idx;
    integer request_idx;
    integer request_tag;
    int mem_addr;

    assign mem_data.data = memory_storage[mem_addr];

    initial begin
        for (int i = 0; i < NADDR; i++) begin
            memory_storage[i] = 128'd0;
        end
    end

    always @(posedge clk) begin
        if (mem_req.valid == 1'b1) begin
            mem_data.ready <= 1'b0;

            req_tag <= mem_req.addr[31:14];
            req_idx <= mem_req.addr[13:4];

            /* verilator lint_off WIDTHEXPAND */
            request_idx <= req_idx;
            request_tag <= req_tag;
            /* verilator lint_on WIDTHEXPAND */

            mem_addr <= (request_idx * NTAGS) + (request_tag%NTAGS);
            if (mem_req.rw == 1'b0) begin // Leitura
                // Lógica para lidar com dirty bit
            end
            else begin // Escrita
                memory_storage[mem_addr] <= mem_req.data;
                //$display("Escrito %h na memória no endereço %d", mem_req.data, mem_addr);
            end
            mem_data.ready <= 1'b1;
        end
    end
    
endmodule
