module receiver (
    input clk,
    input rstn,
    output reg ready,
    output reg [6:0] data_out,
    output reg parity_ok_n,
    input serial_in
);

//insira seu código aqui

// Definição dos estados da máquina de estados do receptor
localparam IDLE               = 3'b000; // Estado ocioso, aguardando o bit de início
localparam START_BIT_DETECTED = 3'b001; // Bit de início detectado
localparam RECEIVE_DATA       = 3'b010; // Recebendo os 7 bits de dados
localparam RECEIVE_PARITY     = 3'b011; // Recebendo o bit de paridade
localparam RECEIVE_STOP       = 3'b100; // Recebendo o bit de parada
localparam DATA_VALID         = 3'b101; // Dados válidos e paridade verificada

reg [2:0] current_state; // Registro para o estado atual
reg [2:0] next_state;    // Registro para o próximo estado
reg [2:0] bit_counter;   // Contador para os 7 bits de dados (0 a 6)
reg [6:0] received_data; // Registro para armazenar os 7 bits de dados recebidos
reg received_parity_bit; // Registro para armazenar o bit de paridade recebido
reg [7:0] received_8_bits; // Combinação dos 7 dados + 1 paridade para verificação

// Lógica combinacional para determinar o próximo estado
always @(*) begin
    next_state = current_state; // Por padrão, permanece no estado atual
    case (current_state)
        IDLE: begin
            if (serial_in == 1'b0) begin // Se a linha serial for baixa, detecta o bit de início
                next_state = START_BIT_DETECTED;
            end
        end
        START_BIT_DETECTED: begin
            // Em uma UART real, haveria um atraso ou amostragem no meio do bit.
            // Aqui, assumimos que cada bit dura um ciclo de relógio.
            next_state = RECEIVE_DATA; // Após detectar o bit de início, vá para receber dados
        end
        RECEIVE_DATA: begin
            if (bit_counter == 6) begin // Se todos os 7 bits de dados foram recebidos (0 a 6)
                next_state = RECEIVE_PARITY; // Vá para receber o bit de paridade
            end else begin
                next_state = RECEIVE_DATA; // Continue recebendo bits de dados
            end
        end
        RECEIVE_PARITY: begin
            next_state = RECEIVE_STOP; // Após receber o bit de paridade, vá para o bit de parada
        end
        RECEIVE_STOP: begin
            next_state = DATA_VALID; // Após receber o bit de parada, os dados estão válidos
        end
        DATA_VALID: begin
            // Permanece neste estado por um ciclo para sinalizar 'ready' e depois volta para IDLE
            if (serial_in == 1'b1) begin // A linha deve estar alta após o stop bit para um novo início limpo
                next_state = IDLE; // Volta para o estado ocioso para aguardar uma nova transmissão
            end else begin
                next_state = DATA_VALID; // Aguarda o stop bit limpar a linha
            end
        end
        default: next_state = IDLE; // Estado padrão em caso de erro
    endcase
end

// Lógica sequencial para transições de estado e controle de saída
always @(posedge clk or negedge rstn) begin
    if (!rstn) begin // Reset assíncrono
        current_state <= IDLE;               // Volta para o estado IDLE
        ready         <= 1'b0;               // 'ready' é baixo
        data_out      <= 7'b0;               // Zera a saída de dados
        parity_ok_n   <= 1'b1;               // 'parity_ok_n' é alto (paridade não OK por padrão)
        bit_counter   <= 0;                  // Zera o contador de bits
        received_data <= 7'b0;               // Zera os dados recebidos
        received_parity_bit <= 1'b0;         // Zera o bit de paridade recebido
        received_8_bits <= 8'b0;             // Zera a combinação de 8 bits
    end else begin
        current_state <= next_state;         // Atualiza o estado para o próximo estado
        ready <= 1'b0; // 'ready' é baixo por padrão, só fica alto por um ciclo em DATA_VALID

        case (next_state)
            IDLE: begin
                bit_counter <= 0;            // Reinicia o contador de bits
                received_data <= 7'b0;       // Limpa os dados recebidos
                received_parity_bit <= 1'b0; // Limpa o bit de paridade recebido
                parity_ok_n <= 1'b1;         // Reinicia o sinal de paridade
            end
            START_BIT_DETECTED: begin
                // Nenhum dado é amostrado neste estado, apenas transição
            end
            RECEIVE_DATA: begin
                received_data[bit_counter] <= serial_in; // Armazena o bit atual (LSB primeiro)
                bit_counter <= bit_counter + 1;         // Incrementa o contador
            end
            RECEIVE_PARITY: begin
                received_parity_bit <= serial_in; // Armazena o bit de paridade recebido
            end
            RECEIVE_STOP: begin
                // Em uma UART real, verificaríamos se serial_in é alto aqui para erros de frame.
                // Para este exercício, assumimos que o stop bit é válido.
            end
            DATA_VALID: begin
                ready <= 1'b1; // Sinaliza que os dados estão prontos
                data_out <= received_data; // Saída dos 7 bits de dados

                // Monta os 8 bits para a verificação de paridade (paridade + dados)
                received_8_bits = {received_parity_bit, received_data};
                // Verifica a paridade par: o XOR de todos os 8 bits deve ser 0
                if (^received_8_bits == 1'b0) begin
                    parity_ok_n <= 1'b0; // Paridade OK (nível baixo)
                end else begin
                    parity_ok_n <= 1'b1; // Paridade NÃO OK (nível alto)
                end
            end
            default: begin
                // Não deve acontecer
            end
        endcase
    end
end

endmodule