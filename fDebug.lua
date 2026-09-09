--- Módulo de depuração (debug).
--- Fornece funções utilitárias para logging, validação e tratamento seguro de erros.
local M = {}

--- Habilita ou desabilita a saída de mensagens de debug.
--- Quando `false`, nenhuma mensagem será impressa no console.
local enabled = false

--- Função interna responsável por formatar e imprimir a mensagem de log.
--- Não deve ser chamada diretamente fora deste módulo.
---@param level string Nível do log (ex: "INFO", "WARN", "ERROR", "OK")
---@param message any Mensagem a ser exibida (será convertida para string)
local function output(level, message)
    if not enabled then return end
    print(string.format("%s - %s",  level, tostring(message)))
end

--- Retorna uma string "arquivo:linha" referente ao ponto de chamada original
--- (dois níveis acima da função interna que a invocou).
---@return string
local function location()
    local info = debug.getinfo(3, "Sl")
    if not info then
        return "?:?"
    end
    return string.format("%s:%d", info.short_src, info.currentline)
end

--- Exibe uma mensagem de log com nível informativo (INFO).
---@param message any Mensagem a ser exibida
local function info(message)
    output("INFO", message)
end

--- Exibe uma mensagem de log com nível de aviso (WARN).
---@param message any Mensagem a ser exibida
local function warn(message)
    output("WARN", message)
end

--- Exibe uma mensagem de log indicando sucesso (OK).
---@param message any Mensagem a ser exibida
local function success(message)
    output("OK", message)
end

--- Exibe uma mensagem de log com nível de erro (ERROR).
---@param message any Mensagem a ser exibida
local function error(message)
    output("ERROR", message)
end

--- Garante que um valor não seja `nil`/`false`, registrando um erro padronizado caso não seja válido.
--- Útil para validar retornos de funções antes de prosseguir com a execução.
---@generic T
---@param value T Valor a ser validado
---@param name string? Nome/identificador do valor (ex: "player", "config.path"), usado apenas na mensagem
---@return T|nil # Retorna o próprio `value` se válido, ou `nil` caso contrário
local function ensure(value, name)
    if value then
        return value
    end

    error(
        string.format("Valor inválido%s em %s",
            name and (" (" .. name .. ")") or "",
            location()
        )
    )
    return nil
end

--- Verifica se uma condição é verdadeira, registrando um erro padronizado caso contrário.
--- Útil para asserções simples que não devem interromper a execução do script.
---@param condition boolean Condição a ser avaliada
---@param name string? Nome/identificador da verificação (ex: "player.health > 0"), usado apenas na mensagem
---@return boolean # `true` se a condição for verdadeira, `false` caso contrário
local function expect(condition, name)
    if condition then
        return true
    end

    error(
        string.format("Condição falhou%s em %s",
            name and (" (" .. name .. ")") or "",
            location()
        )
    )
    return false
end

--- Executa uma função de forma segura utilizando `pcall`, capturando e registrando
--- qualquer erro que ocorra durante sua execução, com mensagem padronizada.
---@param fn function Função a ser executada com segurança
---@param name string? Nome/identificador da função/módulo, usado apenas na mensagem
---@return boolean, any # `true`/`false` indicando sucesso, e o resultado (ou erro) retornado por `fn`
local function protect(fn, name)
    local ok, result = pcall(fn)

    if not ok then
        error(
            string.format("Erro%s em %s: %s",
                name and (" em " .. name) or "",
                location(),
                tostring(result)
            )
        )
    end

    return ok, result
end

M.enabled = function (set)
        enabled = set
    end
M.info = info
M.warn = warn
M.success = success
M.error = error
M.ensure = ensure
M.expect = expect
M.protect = protect

return M
