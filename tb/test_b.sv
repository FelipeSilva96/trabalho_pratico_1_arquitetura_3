`timescale 1ns/1ps
import cache_def::*; // Traz as structs do pacote

module tb_cache;

    //  Declaração dos Sinais (Usando as structs)
    logic clk;
    logic rst;

    cpu_req_type    cpu_req_in;
    cpu_result_type cpu_res_out;
    
    mem_req_type    mem_req_out;
    mem_data_type   mem_data_in;

   
    cache_controller dut (
        .clk(clk),
        .rst(rst),
        .cpu_req(cpu_req_in),
        .cpu_res(cpu_res_out),
        .mem_data(mem_data_in),
        .mem_req(mem_req_out)
    );

    // Geração de Clock (Período de 10ns)
    always #5 clk = ~clk;

    // Simulação do comportamento da Memória Principal
    always @(posedge clk) begin
        // Valores por padrão
        mem_data_in.ready <= 1'b0;
        
        if (mem_req_out.valid) begin
            if (mem_req_out.rw == 1'b0) begin
                // É um Miss (Leitura). A memória precisa devolver um bloco de 128 bits.
                mem_data_in.data <= {32'hDDDDDDDD, 32'hCCCCCCCC, 32'hBBBBBBBB, 32'hAAAAAAAA}; 
                mem_data_in.ready <= 1'b1;
            end else begin
                // É um Write-Back (Escrita na memória). Apenas sinalizamos que recebemos.
                mem_data_in.ready <= 1'b1;
            end
        end
    end

    // Tasks Auxiliares
    // Task para simular uma LEITURA da CPU
    task cpu_read(input logic [31:0] addr);
        begin
            @(posedge clk);
            cpu_req_in.valid = 1'b1; 
            cpu_req_in.rw    = 1'b0; // 0 = leitura
            cpu_req_in.addr  = addr;
            
            // Fica esperando até a cache avisar que terminou
            wait(cpu_res_out.ready == 1'b1); 
            @(posedge clk);
            
            cpu_req_in.valid = 1'b0;
            $display("[%0t] LEITURA CONCLUIDA | Endereco: %h | Dado Lido: %h", $time, addr, cpu_res_out.data);
        end
    endtask

    // Task para simular uma ESCRITA da CPU (Atualizada para usar Structs)
    task cpu_write(input logic [31:0] addr, input logic [31:0] data);
        begin
            @(posedge clk);
            cpu_req_in.valid = 1'b1;
            cpu_req_in.rw    = 1'b1; // 1 = escrita
            cpu_req_in.addr  = addr;
            cpu_req_in.data  = data; // Passando o dado a ser escrito
            
            wait(cpu_res_out.ready == 1'b1);
            @(posedge clk);
            
            cpu_req_in.valid = 1'b0;
            $display("[%0t] ESCRITA CONCLUIDA | Endereco: %h | Dado Escrito: %h", $time, addr, data);
        end
    endtask

    //  Bloco Principal de Execução dos Testes
    initial begin
        // Configuração para exportar as formas de onda para o GTKWave
        $dumpfile("ondas_cache.vcd");
        $dumpvars(0, tb_cache);

        // Inicialização dos sinais e Reset
        $display("--- INICIANDO SIMULACAO ---");
        clk = 0;
        rst = 1;
        
        // Zera a struct de requisição inicial
        cpu_req_in.valid = 1'b0;
        cpu_req_in.rw    = 1'b0;
        cpu_req_in.addr  = 32'd0;
        cpu_req_in.data  = 32'd0;
        
        #20 rst = 0; // Libera o reset após 20ns
        $display("[%0t] Reset liberado. Cache inicializada.", $time);

        // --- INÍCIO DOS CENÁRIOS DE TESTE ---

        $display("\n--- Teste 7.1: Leitura de endereco vazio (Miss) ---");
        // Vai ler o endereço. Como está vazio, vai na memória buscar. 
        // A memória deve devolver a palavra correspondente ao final do bloco (AAAAAAAA, BBBBBBBB, etc).
        cpu_read(32'h0000_1004); 

        $display("\n--- Teste 7.1: Leitura do mesmo endereco (Hit) ---");
        // O dado agora deve estar na cache, resolvendo em 1 ou 2 ciclos sem ir na memória.
        cpu_read(32'h0000_1004);

        $display("\n--- Teste 7.2: Escrita no mesmo endereco (Hit Write) ---");
        // Vai sobrescrever a palavra que estava lá pelo valor DEADBEEF e marcar o Dirty bit como 1.
        cpu_write(32'h0000_1004, 32'hDEADBEEF);

        // Finaliza a simulação
        #50;
        $display("\n--- SIMULACAO FINALIZADA ---");
        $finish;
    end

endmodule
