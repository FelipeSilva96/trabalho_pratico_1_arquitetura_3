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
import cache_def::*;




module main_memory #(
    input bit clk,
    input mem_req_type, //requisicao do controlador para a memoria
    output mem_data_type //resposta da memoria contendo bit ready e os 128 bits de dados lidos
);


always @(posedge clk) begin // vamos escrever na borda de subida do clock

end
    
endmodule