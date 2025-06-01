module transmitter (
    input clk,
    input rstn,
    input start,
    input [6:0] data_in,
    output reg serial_out
);

//insira seu código aqui


localparam IDLE         = 3'b000; // Estado ocioso, aguardando o sinal 'start'
localparam START_BIT    = 3'b001; // Enviando o bit de início (0)
localparam DATA_BITS    = 3'b010; // Enviando os 7 bits de dados
localparam PARITY_BIT   = 3'b011; // Enviando o bit de paridade
localparam STOP_BIT     = 3'b100; // Enviando o bit de parada (1)
localparam DONE         = 3'b101; // Transmissão concluída, linha em nível alto

reg [2:0] current_state; // Registro para o estado atual
reg [2:0] next_state;    // Registro para o próximo estado
reg [6:0] data_to_send;  // Registro para armazenar os dados a serem enviados
reg [2:0] bit_counter;   // Contador para os 7 bits de dados (0 a 6)

// Variável para o bit de paridade
reg parity_bit;

// Lógica combinacional para determinar o próximo estado
always @(*) begin
    next_state = current_state; // Por padrão, permanece no estado atual
    case (current_state)
        IDLE: begin
            if (start) begin
                next_state = START_BIT; // Se 'start' for alto, vá para o estado de bit de início
            end
        end
        START_BIT: begin
            next_state = DATA_BITS; // Após enviar o bit de início, vá para os bits de dados
        end
        DATA_BITS: begin
            if (bit_counter == 6) begin // Se todos os 7 bits de dados foram enviados (0 a 6)
                next_state = PARITY_BIT; // Vá para o bit de paridade
            end else begin
                next_state = DATA_BITS; // Continue enviando bits de dados
            end
        end
        PARITY_BIT: begin
            next_state = STOP_BIT; // Após enviar o bit de paridade, vá para o bit de parada
        end
        STOP_BIT: begin
            next_state = DONE; // Após enviar o bit de parada, vá para o estado de concluído
        end
        DONE: begin
            // Permanece em DONE até um reset
            next_state = DONE;
        end
        default: next_state = IDLE; // Estado padrão em caso de erro
    endcase
end

// Lógica sequencial para transições de estado e controle de saída
always @(posedge clk or negedge rstn) begin
    if (!rstn) begin // Reset assíncrono
        current_state <= IDLE;         // Volta para o estado IDLE
        serial_out    <= 1'b1;         // A linha serial fica em nível alto (ociosa)
        bit_counter   <= 0;            // Zera o contador de bits
        data_to_send  <= 7'b0;         // Zera os dados a serem enviados
        parity_bit    <= 1'b0;         // Zera o bit de paridade
    end else begin
        current_state <= next_state;   // Atualiza o estado para o próximo estado

        case (next_state) // Ações baseadas no PRÓXIMO estado
            IDLE: begin
                serial_out <= 1'b1; // Mantém a linha alta
                if (start) begin
                    data_to_send <= data_in; // Trava os dados de entrada quando 'start' é alto
                    bit_counter  <= 0;       // Reinicia o contador de bits
                    // Calcula o bit de paridade par para os 7 bits de dados
                    // O operador XOR de redução (^) calcula a paridade
                    parity_bit = ^data_in;
                end
            end
            START_BIT: begin
                serial_out <= 1'b0; // Envia o bit de início (nível baixo)
            end
            DATA_BITS: begin
                serial_out <= data_to_send[bit_counter]; // Envia o bit de dados atual (LSB primeiro)
                bit_counter <= bit_counter + 1;         // Incrementa o contador para o próximo bit
            end
            PARITY_BIT: begin
                serial_out <= parity_bit; // Envia o bit de paridade calculado
            end
            STOP_BIT: begin
                serial_out <= 1'b1; // Envia o bit de parada (nível alto)
            end
            DONE: begin
                serial_out <= 1'b1; // Mantém a linha em nível alto até o reset
            end
            default: begin
                serial_out <= 1'b1; // Caso padrão, mantém a linha alta
            end
        endcase
    end
end

endmodule