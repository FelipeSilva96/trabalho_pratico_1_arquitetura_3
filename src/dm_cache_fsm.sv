`timescale 1ns/1ps

/* verilator lint_off IMPORTSTAR */
import cache_def::*;
/* verilator lint_on IMPORTSTAR */

module dm_cache_fsm (
    input  logic           clk, // Clock
    input  logic           rst, // Reset
    //input  bit           clk, // Clock
    //input  bit           rst, // Reset

    // Interface CPU <-> Cache
    input  cpu_req_type     cpu_req,
    output cpu_result_type  cpu_res,

    // Interface Cache <-> Memória Principal
    input  mem_data_type    mem_data,
    output mem_req_type     mem_req,

    // Interface com o Datapath (Memória de Dados)
    input  cache_data_type  data_read,
    output cache_data_type  data_write,
    output cache_req_type   data_req,

    // Interface com o Datapath (Memória de Tags)
    input  cache_tag_type   tag_read,
    output cache_tag_type   tag_write,
    output cache_req_type   tag_req
);

    // -------------------------------------------------------------------------
    // 1. Descodificação do Endereço (32 bits -> Tag, Index, Offset)
    // Bloco: 128 bits (16 Bytes) -> Offset = 4 bits [3:0]
    // Linhas: 1024 -> Index = 10 bits [13:4]
    // Tag: Restante -> Tag = 18 bits [31:14]
    // -------------------------------------------------------------------------
    logic [17:0] req_tag;
    logic [9:0]  req_idx;
    
    assign req_tag = cpu_req.addr[31:14];
    assign req_idx = cpu_req.addr[13:4];

    // -------------------------------------------------------------------------
    // 2. Definição dos Estados da FSM
    // -------------------------------------------------------------------------
    typedef enum logic [1:0] {
        IDLE        = 2'b00,
        COMPARE_TAG = 2'b01,
        ALLOCATE    = 2'b10,
        WRITE_BACK  = 2'b11
    } state_t;

    state_t rstate, vstate; // rstate = estado atual, vstate = próximo estado

    // -------------------------------------------------------------------------
    // 3. Registo de Estado (Sequencial - Flanco Ascendente)
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst) begin
            rstate <= IDLE;
        end else begin
            rstate <= vstate;
        end
    end

    // -------------------------------------------------------------------------
    // 4. Lógica de Transição e Saídas (Combinacional)
    // -------------------------------------------------------------------------
    always_comb begin
        // Valores por padrão (Evita a criação de latches indesejados)
        vstate = rstate;
        
        cpu_res.ready = 1'b0;
        cpu_res.data  = 32'd0;
        
        mem_req.valid = 1'b0;
        mem_req.rw    = 1'b0;
        mem_req.addr  = 32'd0;
        mem_req.data  = 128'd0;
        
        data_req.we    = 1'b0;
        data_req.index = req_idx;
        data_write     = data_read; // Mantém o dado atual por padrão
        
        tag_req.we     = 1'b0;
        tag_req.index  = req_idx;
        tag_write      = tag_read;  // Mantém a tag atual por padrão

        // Escolha da palavra correspondente ao offset enviada continuamente para a CPU
        case (cpu_req.addr[3:2])
            2'b00: cpu_res.data = data_read[31:0];
            2'b01: cpu_res.data = data_read[63:32];
            2'b10: cpu_res.data = data_read[95:64];
            2'b11: cpu_res.data = data_read[127:96];
        endcase

        case (rstate)
            // =================================================================
            // ESTADO: IDLE
            // Aguarda um pedido válido da CPU.
            // =================================================================
            IDLE: begin
                if (cpu_req.valid) begin
                    vstate = COMPARE_TAG;
                end
            end

            // =================================================================
            // ESTADO: COMPARE_TAG
            // Verifica se a Tag corresponde e se o bloco é válido.
            // =================================================================
            COMPARE_TAG: begin
                // Avaliação do HIT local e segura diretamente dentro do estado
                if (tag_read.valid && (tag_read.tag == req_tag)) begin
                    // CACHE HIT!
                    cpu_res.ready = 1'b1;
                    
                    if (cpu_req.rw == 1'b0) begin
                        // HIT de Leitura: Extrair a palavra correta do bloco (Feito no case estático acima)
                        vstate = IDLE;
                    end else begin
                        // HIT de Escrita: Atualiza a palavra no bloco e marca como Dirty
                        data_req.we = 1'b1;
                        // Modifica apenas a palavra correspondente ao offset
                        case (cpu_req.addr[3:2])
                            2'b00: data_write[31:0]   = cpu_req.data;
                            2'b01: data_write[63:32]  = cpu_req.data;
                            2'b10: data_write[95:64]  = cpu_req.data;
                            2'b11: data_write[127:96] = cpu_req.data;
                        endcase
                        
                        tag_req.we      = 1'b1;
                        tag_write.dirty = 1'b1; // Bloco foi modificado (Write-Back ativado)
                        tag_write.valid = 1'b1;
                        tag_write.tag   = req_tag;
                        
                        vstate = IDLE;
                    end
                end else begin
                    // CACHE MISS!
                    if (tag_read.valid && tag_read.dirty) begin
                        // O bloco atual está sujo. Tem de ir para a Memória primeiro.
                        vstate = WRITE_BACK;
                    end else begin
                        // Bloco está limpo ou inválido. Podemos alocar um novo logo.
                        vstate = ALLOCATE;
                    end
                end
            end

            // =================================================================
            // ESTADO: WRITE_BACK
            // Envia o bloco inteiro modificado para a Memória Principal.
            // =================================================================
            WRITE_BACK: begin
                mem_req.valid = 1'b1;
                mem_req.rw    = 1'b1; // 1 = Escrita na Memória
                // O endereço na memória junta a Tag ANTIGA com o Index atual e offset zerado
                mem_req.addr  = {tag_read.tag, req_idx, 4'b0000}; 
                mem_req.data  = data_read;
                
                if (mem_data.ready) begin
                    // Memória confirmou a escrita. Agora podemos alocar o novo bloco.
                    vstate = ALLOCATE;
                end
            end

            // =================================================================
            // ESTADO: ALLOCATE
            // Pede o novo bloco à Memória Principal e guarda-o na Cache.
            // =================================================================
            ALLOCATE: begin
                mem_req.valid = 1'b1;
                mem_req.rw    = 1'b0; // 0 = Leitura da Memória
                // Pede o endereço que a CPU originalmente solicitou com final zerado (início do bloco)
                mem_req.addr  = {req_tag, req_idx, 4'b0000};
                
                if (mem_data.ready) begin
                    // Memória devolveu o novo bloco. Escrever nas SRAMs da Cache.
                    data_req.we = 1'b1;
                    data_write  = mem_data.data;
                    
                    tag_req.we      = 1'b1;
                    tag_write.valid = 1'b1;
                    tag_write.dirty = 1'b0; // Bloco acabado de chegar está limpo
                    tag_write.tag   = req_tag;
                    
                    // Com o bloco novo na cache, volta para IDLE para reavaliar a requisição estavelmente
                    vstate = IDLE;
                end
            end
        endcase
    end

endmodule
