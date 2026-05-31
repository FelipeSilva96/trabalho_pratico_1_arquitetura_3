`timescale 1ns/1ps
/* verilator lint_off IMPORTSTAR */
import cache_def::*;
/* verilator lint_on IMPORTSTAR */

module tb_dm_cache;

    // ---------------------------------------------------------
    // 1. Declaração dos Sinais Externos
    // ---------------------------------------------------------
    logic clk;
    logic rst;

    /* verilator lint_off UNUSEDSIGNAL */
    bit [3:0] test_instruction_number;
    int address;
    /* verilator lint_on UNUSEDSIGNAL */

    cpu_req_type    cpu_req_in;
    cpu_result_type cpu_res_out;
    
    mem_req_type    mem_req_out;
    mem_data_type   mem_data_in;

    // ---------------------------------------------------------
    // 2. Declaração dos Sinais Internos
    // ---------------------------------------------------------
    cache_data_type data_read, data_write;
    cache_tag_type  tag_read, tag_write;

    /* verilator lint_off UNOPTFLAT */
    cache_req_type  data_req;
    cache_req_type  tag_req;
    /* verilator lint_on UNOPTFLAT */

    // ---------------------------------------------------------
    // 3. Instanciação dos Módulos (Projeto Completo Integrado)
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

    // Memória de Dados da Cache
    dm_cache_data data_inst (
        .clk(clk),
        .data_req(data_req),
        .data_write(data_write),
        .data_read(data_read)
    );

    // Memória de Tags da Cache
    dm_cache_tag tag_inst (
        .clk(clk),
        .tag_req(tag_req),
        .tag_write(tag_write),
        .tag_read(tag_read)
    );

    // Módulo Real da Memória Principal (Substitui a memória "falsa")
    // Latência configurada para 10 ciclos para evidenciar o tempo de espera real
    main_memory #(
        .LATENCY(10)
    ) mem_inst (
        .clk(clk),
        .mem_req(mem_req_out),
        .mem_data(mem_data_in)
    );

    // ---------------------------------------------------------
    // 4. Geração de Clock (Período de 10ns)
    // ---------------------------------------------------------
    always #5 clk <= ~clk;

    // ---------------------------------------------------------
    // 6. Tasks Auxiliares Sincronizadas
    // ---------------------------------------------------------
    task cpu_read(input logic [31:0] addr, input logic show_result);
        begin
            @(posedge clk);
            cpu_req_in.valid = 1'b1; 
            cpu_req_in.rw    = 1'b0; 
            cpu_req_in.addr  = addr;
            
            while (cpu_res_out.ready !== 1'b1) begin
                @(posedge clk);
            end 
            
            cpu_req_in.valid = 1'b0;
            if (show_result) begin
                $display("[%0t] LEITURA CONCLUIDA | Endereco: %h | Dado Lido: %h", $time, addr, cpu_res_out.data);
            end
        end
    endtask

    task cpu_write(input logic [31:0] addr, input logic [31:0] data, input logic show_result);
        begin
            @(posedge clk);
            cpu_req_in.valid = 1'b1;
            cpu_req_in.rw    = 1'b1; 
            cpu_req_in.addr  = addr;
            cpu_req_in.data  = data; 
            
            while (cpu_res_out.ready !== 1'b1) begin
                @(posedge clk);
            end
            
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
        $display("\n\n--- INICIANDO SIMULACAO (MEMORIA REAL CONECTADA) ---");
        clk = 0;
        rst = 1;
        
        cpu_req_in.valid = 1'b0;
        cpu_req_in.rw    = 1'b0;
        cpu_req_in.addr  = 32'd0;
        cpu_req_in.data  = 32'd0;
        
        #20 rst = 0;
        $display("[%0t] Reset liberado. Cache inicializada.", $time);

        $display("\n\n--- Teste 1.1: Leitura de endereco vazio (Miss) ---");
        test_instruction_number = 4'd1;
        cpu_read(32'h0000_1004, 1'b1); 

        $display("\n\n--- Teste 1.2: Leitura do mesmo endereco (Hit) ---");
        test_instruction_number = 4'd2;
        cpu_read(32'h0000_1004, 1'b1);

        $display("\n\n--- Teste 2.1: Escrita no mesmo endereco (Hit Write) ---");
        test_instruction_number = 4'd3;
        cpu_write(32'h0000_1004, 32'hDEADBEEF, 1'b1);

        $display("\n\n--- Teste 2.2: Escrita em endereço com dirty bit 1 (Política Write-Back)---");
        cpu_write(32'h0001_1004, 32'h0000000F, 1'b1);

        $display("\n\n--- Teste 2.3: Escrita em endereco diferente (Miss Write)---");
        cpu_write(32'h0000_1014, 32'h0000001F, 1'b1);

        $display("\n\n--- Teste 3.1: Consistencia em sequencia de operacoes ---");
        test_instruction_number = 4'd5;
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
        cpu_read(32'h0001_1030, 1'b1);

        $display("\n\n--- Teste 4: Enderecos Extremos---");
        test_instruction_number = 4'd6;
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

        #50;
        test_instruction_number = 4'd7;
        $display("\n\n--- SIMULACAO FINALIZADA ---\n\n");
        $finish;
    end

endmodule
