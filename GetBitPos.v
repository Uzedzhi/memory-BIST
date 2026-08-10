// ----------------------Получить второй выставленный бит---------------------------
// Синтезируемый модуль, выдающий позицию изолированного бита в числе
// PARAMS:      BIT_WIDTH   - разрядность вводимого вектора
// INPUTS:      Vec         - вектор размерности BIT_WIDTH
// OUTPUTS:     BitPos      - позиция изолированного бита
// ---------------------------------------------------------------------------------
module GetBitPos #(
                            parameter BIT_WIDTH = 8
                        )(
                            input  [BIT_WIDTH         - 1:0] Vec,
                            output [$clog2(BIT_WIDTH) - 1:0] BitPos,
                            output is_onehot
                        );

    assign is_onehot = ((Vec) & (Vec - 1)) == 0;
    generate
        // получение позиции активного бита в векторе
        // генерация маски i бита побитовой декомпозиции всех чисел от 0 до BIT_WIDTH
        // и использование логического ИЛИ с И для получения позиции
        // Пример для BIT_WIDTH = 8, Vec = 00001000:
        //      |(00001000 & 11110000) = 0
        //      |(00001000 & 11001100) = 1
        //      |(00001000 & 10101010) = 1
        // BitPos = 3'b11 = 3
        for (genvar i = 0; i < $clog2(BIT_WIDTH); i = i + 1) begin
            wire [BIT_WIDTH - 1:0] mask;

            // Делаем маску используя битовое разложение до BIT_WIDTH
            for (genvar temp = 0; temp < BIT_WIDTH; temp = temp + 1) begin
                assign mask[temp] = temp[i];
            end

            assign BitPos[i] = |(Vec & mask);
        end
    endgenerate

endmodule