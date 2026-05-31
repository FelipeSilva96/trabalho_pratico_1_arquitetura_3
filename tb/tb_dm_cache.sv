`timescale 1ns/1ps
/* verilator lint_off IMPORTSTAR */
import cache_def::*;
/* verilator lint_on IMPORTSTAR */

module tb_dm_cache;

    // ---------------------------------------------------------
    // 1. Declaração dos Sinais Externos (CPU e Memória Principal)
    // ---------------------------------------------------------
    logic clk;
    logic rst;

    /* verilator lint_off UNUSEDSIGNAL */
    bit [3:0] test_instruction_number;
    int address;
    /* verilator lint_on UNUSEDSIGNAL */

    cpu_req_type    cpu_req_in;
    cpu_result_type cpu_res_out;
    
    /* verilator lint_off UNUSEDSIGNAL */
    mem_req_type    mem_req_out;
    /* verilator lint_on UNUSEDSIGNAL */
    mem_data_type   mem_data_in;

    // ---------------------------------------------------------
    // 2. Declaração dos Sinais Internos (Fios entre FSM e SRAMs)
    // ---------------------------------------------------------
    cache_data_type data_read, data_write;
    cache_req_type  data_req, tag_req;
    cache_tag_type  tag_read, tag_write;

    // ---------------------------------------------------------
    // 3. Instanciação dos Módulos do Projeto
    // ---------------------------------------------------------
    
    // Controlador FSM
    dm_cache_fsm fsm_inst (
        .clk(clk),
        .rst(rst),
        .cpu_req(cpu_req_in),
        .cpu_res(cpu_res_out),
        .mem_data(mem_data_in),
        .mem_req(mem_req_out),
        .data_read(data_read),
        .data_write(data_write),
        .data_req(data_req),
        .tag_read(tag_read),
        .tag_write(tag_write),
        .tag_req(tag_req)
    );

    // Memória de Dados
    dm_cache_data data_inst (
        .clk(clk),
        .data_req(data_req),
        .data_write(data_write),
        .data_read(data_read)
    );

    // Memória de Tags
    dm_cache_tag tag_inst (
        .clk(clk),
        .tag_req(tag_req),
        .tag_write(tag_write),
        .tag_read(tag_read)
    );

    // ---------------------------------------------------------
    // 4. Geração de Clock (Período de 10ns)
    // ---------------------------------------------------------
    always #5 clk <= ~clk;

    // ---------------------------------------------------------
    // 5. Simulação do comportamento da Memória Principal
    // ---------------------------------------------------------
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

    // ---------------------------------------------------------
    // 6. Tasks Auxiliares
    // ---------------------------------------------------------
    
    // Task para simular uma LEITURA da CPU
    task cpu_read(input logic [31:0] addr, input logic show_result);
        begin
            @(posedge clk);
            cpu_req_in.valid = 1'b1; 
            cpu_req_in.rw    = 1'b0; // 0 = leitura
            cpu_req_in.addr  = addr;
            
            // Fica esperando até a cache avisar que terminou
            wait(cpu_res_out.ready == 1'b1); 
            @(posedge clk);
            
            cpu_req_in.valid = 1'b0;
            if (show_result) begin
                $display("[%0t] LEITURA CONCLUIDA | Endereco: %h | Dado Lido: %h", $time, addr, cpu_res_out.data);
            end
        end
    endtask

    // Task para simular uma ESCRITA da CPU
    task cpu_write(input logic [31:0] addr, input logic [31:0] data, input logic show_result);
        begin
            @(posedge clk);
            cpu_req_in.valid = 1'b1;
            cpu_req_in.rw    = 1'b1; // 1 = escrita
            cpu_req_in.addr  = addr;
            cpu_req_in.data  = data; // Passando o dado a ser escrito
            
            wait(cpu_res_out.ready == 1'b1);
            @(posedge clk);
            
            cpu_req_in.valid = 1'b0;
            if (show_result) begin
                $display("[%0t] ESCRITA CONCLUIDA | Endereco: %h | Dado Escrito: %h", $time, addr, data);
            end
        end
    endtask

    // ---------------------------------------------------------
    // 7. Bloco Principal de Execução dos Testes
    // ---------------------------------------------------------
    initial begin
        // Configuração para exportar as formas de onda para o GTKWave
        //$dumpfile("ondas_cache.vcd");
        //$dumpvars(0, tb_dm_cache);

        // Inicialização dos sinais e Reset
        $display("\n\n--- INICIANDO SIMULACAO ---");
        clk = 0;
        rst = 1;
       //$display("clock and reset set");
        
        // Zera a struct de requisição inicial
        cpu_req_in.valid = 1'b0;
        cpu_req_in.rw    = 1'b0;
        cpu_req_in.addr  = 32'd0;
        cpu_req_in.data  = 32'd0;
        
        //$display("teste");
        //#1 $display("--- 1ns ---");
        //#1 $display("--- 2ns ---");
        //#1 $display("--- 3ns ---");
        //#1 $display("--- 4ns ---");
        //#1 $display("--- 5ns ---");
        //#5 $display("--- 10ns ---");
        //#5 $display("--- 15ns ---");
        //#5 rst = 0; // Libera o reset após 20ns
        #20 rst = 0; // Libera o reset após 20ns
        $display("[%0t] Reset liberado. Cache inicializada.", $time);

        //  Seria interessante um teste para percorrer a cache e relatar se houver
        // algumas linha diferente de 0, mas isso não é possível pela forma
        // como é feita a modularização, em que não se tem acesso a toda a cache diretamente

        // --- INÍCIO DOS CENÁRIOS DE TESTE ---

        $display("\n\n--- Teste 1.1: Leitura de endereco vazio (Miss) ---");
        // Vai ler o endereço. Como está vazio, vai na memória buscar. 
        // A memória deve devolver a palavra correspondente ao final do bloco (AAAAAAAA, BBBBBBBB, etc).
        test_instruction_number = 4'd1;
        cpu_read(32'h0000_1004, 1'b1); 

        $display("\n\n--- Teste 1.2: Leitura do mesmo endereco (Hit) ---");
        // O dado agora deve estar na cache, resolvendo em 1 ou 2 ciclos sem ir na memória.
        test_instruction_number = 4'd2;
        cpu_read(32'h0000_1004, 1'b1);

        $display("\n\n--- Teste 2.1: Escrita no mesmo endereco (Hit Write) ---");
        // Vai sobrescrever a palavra que estava lá pelo valor DEADBEEF e marcar o Dirty bit como 1.
        test_instruction_number = 4'd3;
        cpu_write(32'h0000_1004, 32'hDEADBEEF, 1'b1);

        $display("\n\n--- Teste 2.2: Escrita em endereço com dirty bit 1 (Política Write-Back)---");
        // Endereço tem mesmo índice que o anterior, mas o tag é diferente
        cpu_write(32'h0001_1004, 32'h0000000F, 1'b1);

        $display("\n\n--- Teste 2.3: Escrita em endereco diferente (Miss Write)---");
        // Endereço tem índice não salvo na cache
        cpu_write(32'h0000_1014, 32'h0000001F, 1'b1);

        $display("\n\n--- Teste 3.1: Consistencia em sequencia de operacoes ---");
        test_instruction_number = 4'd5;
        //  Aqui provamos a consistência de dados em um endereço
        // salvando um valor a ele, substituindo sua presença na cache
        // com um endereço de mesmo índice mas tag diferente, e então realizando
        // a leitura novamente para verificar que o valor permanece
        cpu_read(32'h0000_1010, 1'b1);
        cpu_write(32'h0000_1010, 32'h0000002F, 1'b1);
        cpu_read(32'h0000_1010, 1'b1);
        cpu_read(32'h0000_3010, 1'b1);
        cpu_read(32'h0000_1010, 1'b1);

        $display("\n\n--- Teste 3.2: Consistencia em acesso ao mesmo endereco ---");
        cpu_write(32'h0000_1020, 32'h0000003F, 1'b1);
        for (int i = 0; i < 4; i++) begin
            cpu_read(32'h0000_1020, 1'b1);
        end

        $display("\n\n--- Teste 3.3: Acesso em enderecos com conflito de indice ---");
        cpu_write(32'h0000_1030, 32'hFF0000FF, 1'b1);
        cpu_write(32'h0001_1030, 32'h00FFFF00, 1'b1);
        cpu_read(32'h0000_1030, 1'b1);
        // Endereço tem mesmo índice que o anterior, mas o tag é diferente
        cpu_read(32'h0001_1030, 1'b1);

        $display("\n\n--- Teste 4: Enderecos Extremos---");
        test_instruction_number = 4'd6;
        // Escrito no primeiro e último endereço da cache
        cpu_write(32'h0000_0000, 32'h00000001, 1'b1);
        cpu_read(32'h0000_0000, 1'b1);
        cpu_write(32'hFFFF_FFFF, 32'hFFFFFFFF, 1'b1);
        cpu_read(32'hFFFF_FFFF, 1'b1);

        $display("\n\n--- Teste 5:Preenchimento da cache ---");
        test_instruction_number = 4'd4;
        $display("\n Preenchendo a cache \n");
        for (int i = 0; i < CACHE_LINES; i++) begin
            address = 32'h0000_0000;
            address = address + (i*16);
            cpu_write(address, 32'h00000001, 1'b0);
            if ((i+1)%128 == 0) begin
                $display(" Preenchido %d enderecos", i+1);
            end
        end
        $display("\n Cache preenchida");

        // Finaliza a simulação
        #50;
        test_instruction_number = 4'd7;
        $display("\n\n--- SIMULACAO FINALIZADA ---\n\n");
        $finish;
    end

endmodule
