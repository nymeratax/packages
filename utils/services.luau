--!strict

local get_service = clonefunction(game.GetService)
local service_cache: { [string]: Instance } = {}

type Services = {
    [string]: Instance?
}

local services = setmetatable({}, {
    __index = function(_, index: string): Instance?
        local service = service_cache[index]
        if service ~= nil then return service end

        local success, result = pcall(get_service, game, index)
        if success and result then
            service = cloneref(result)
            service_cache[index] = service
            return service
        end

        return nil
    end
}) :: Services

return services
