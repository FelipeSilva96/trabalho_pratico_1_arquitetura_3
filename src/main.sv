`timescale 1ns/1ps

// Importa todas as definições e structs do pacote
import cache_def::*; 

module cache_controller (
    input  logic           clk,
    input  logic           rst,

    // Interface CPU <-> Cache (Vem/Vai para o Testbench)
    input  cpu_req_type    cpu_req,
    output cpu_result_type cpu_res,

    // Interface Cache <-> Memória Principal (Vem/Vai para o Testbench)
    input  mem_data_type   mem_data,
    output mem_req_type    mem_req
);

    // =========================================================================
    // 1. Declaração dos Fios Internos (Sinais de interligação)
    // =========================================================================
    
    // Fios que ligam a FSM à Memória de Dados
    cache_req_type  fsm_to_data_req;
    cache_data_type fsm_to_data_write;
    cache_data_type data_to_fsm_read;

    // Fios que ligam a FSM à Memória de Tags
    cache_req_type  fsm_to_tag_req;
    cache_tag_type  fsm_to_tag_write;
    cache_tag_type  tag_to_fsm_read;


    // =========================================================================
    // 2. Instanciação da Máquina de Estados (Controlo)
    // =========================================================================
    dm_cache_fsm u_fsm (
        .clk        (clk),
        .rst        (rst),
        
        // Ligações externas (CPU e Memória Principal)
        .cpu_req    (cpu_req),
        .cpu_res    (cpu_res),
        .mem_data   (mem_data),
        .mem_req    (mem_req),
        
        // Ligações internas (Para as Memórias SRAM)
        .data_read  (data_to_fsm_read),
        .data_write (fsm_to_data_write),
        .data_req   (fsm_to_data_req),
        
        .tag_read   (tag_to_fsm_read),
        .tag_write  (fsm_to_tag_write),
        .tag_req    (fsm_to_tag_req)
    );


    // =========================================================================
    // 3. Instanciação da Memória de Dados (Datapath)
    // =========================================================================
    dm_cache_data u_data (
        .clk        (clk),
        .data_req   (fsm_to_data_req),
        .data_write (fsm_to_data_write),
        .data_read  (data_to_fsm_read)
    );


    // =========================================================================
    // 4. Instanciação da Memória de Tags (Datapath)
    // =========================================================================
    dm_cache_tag u_tag (
        .clk        (clk),
        .tag_req    (fsm_to_tag_req),
        .tag_write  (fsm_to_tag_write),
        .tag_read   (tag_to_fsm_read)
    );

endmodule