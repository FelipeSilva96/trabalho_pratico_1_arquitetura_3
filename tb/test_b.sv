`timescale 1ns/1ps

module tb_cache;

    // 1. Declaração dos Sinais (Conectando o TB à Cache)
    // Sinais globais
    logic clk;
    logic rst;

    // Sinais da CPU
    logic        cpu_req;
    logic        cpu_we;
    logic [31:0] cpu_addr;
    logic [31:0] cpu_wdata;
    logic [31:0] cpu_rdata;
    logic        cpu_ready;

    // Sinais da Memória Principal (Simulada pelo TB)
    logic        mem_req;
    logic        mem_we;
    logic [31:0] mem_addr;
    logic [31:0] mem_wdata;
    logic [31:0] mem_rdata;
    logic        mem_ready;

    // 2. Instanciação do Controlador de Cache (DUT - Device Under Test)
    // Certificar de que os nomes das portas batem com o módulo principal(mudar isso, caso seja diferente)
    cache_controller dut (
        .clk(clk),
        .rst(rst),
        .cpu_req(cpu_req),
        .cpu_we(cpu_we),
        .cpu_addr(cpu_addr),
        .cpu_wdata(cpu_wdata),
        .cpu_rdata(cpu_rdata),
        .cpu_ready(cpu_ready),
        .mem_req(mem_req),
        .mem_we(mem_we),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_rdata(mem_rdata),
        .mem_ready(mem_ready)
    );

    // 3. Geração de Clock (Período de 10ns)
    always #5 clk = ~clk;

    // 4. Tasks Auxiliares (Facilitam a escrita dos testes)
    // Task para simular uma LEITURA da CPU
    task cpu_read(input logic [31:0] addr);
        begin
            @(posedge clk);
            cpu_req  = 1'b1;
            cpu_we   = 1'b0; // 0 significa leitura
            cpu_addr = addr;
            
            // Fica esperando até a cache avisar que terminou (Hit ou resolveu o Miss)
            wait(cpu_ready == 1'b1);
            @(posedge clk);
            
            cpu_req = 1'b0; // Abaixa a requisição
            $display("[%0t] LEITURA CONCLUIDA | Endereco: %h | Dado Lido: %h", $time, addr, cpu_rdata);
        end
    endtask

    // Task para simular uma ESCRITA da CPU
    task cpu_write(input logic [31:0] addr, input logic [31:0] data);
        begin
            @(posedge clk);
            cpu_req   = 1'b1;
            cpu_we    = 1'b1; // 1 significa escrita
            cpu_addr  = addr;
            cpu_wdata = data;
            
            wait(cpu_ready == 1'b1);
            @(posedge clk);
            
            cpu_req = 1'b0;
            $display("[%0t] ESCRITA CONCLUIDA | Endereco: %h | Dado Escrito: %h", $time, addr, data);
        end
    endtask

    // 5. Bloco Principal de Execução dos Testes
    initial begin
        // Configuração para exportar as formas de onda para o GTKWave (Exigência do Relatório)
        $dumpfile("ondas_cache.vcd");
        $dumpvars(0, tb_cache);

        // Inicialização dos sinais e Reset (Cobre o Teste 7.5 - Estado vazio)
        $display("--- INICIANDO SIMULACAO ---");
        clk = 0;
        rst = 1;
        cpu_req = 0;
        cpu_we = 0;
        mem_ready = 1; // Simplificação inicial da resposta da memória principal
        
        #20 rst = 0; // Libera o reset após 20ns
        $display("[%0t] Reset liberado. Cache inicializada.", $time);

        // --- INÍCIO DOS CENÁRIOS DE TESTE ---

        // Teste 7.1: Acesso com Cache Miss (Compulsório)
        $display("\n--- Teste 7.1: Leitura de endereco vazio (Miss) ---");
        cpu_read(32'h0000_1004); 

        // Teste 7.1: Acesso com Cache Hit (O dado agora deve estar lá)
        $display("\n--- Teste 7.1: Leitura do mesmo endereco (Hit) ---");
        cpu_read(32'h0000_1004);

        // Teste 7.2: Escrita com Hit (Atualização direta)
        $display("\n--- Teste 7.2: Escrita no mesmo endereco (Hit Write) ---");
        cpu_write(32'h0000_1004, 32'hDEADBEEF);

        // Finaliza a simulação
        #50;
        $display("\n--- SIMULACAO FINALIZADA ---");
        $finish;
    end

endmodule