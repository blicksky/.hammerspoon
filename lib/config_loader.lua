local M = {}

function M.load(defaults, configPath)
    if not defaults or type(defaults) ~= "table" then
        error("loadConfig: defaults must be a table")
    end
    
    if not configPath then
        error("loadConfig: configPath is required")
    end
    
    local result = {}
    for key, value in pairs(defaults) do
        result[key] = value
    end
    
    local configFile = io.open(configPath, "r")
    
    if configFile then
        configFile:close()
        local success, userConfig = pcall(function()
            return dofile(configPath)
        end)
        
        if success and userConfig and type(userConfig) == "table" then
            for key, value in pairs(userConfig) do
                result[key] = value
            end
        end
    end
    
    return result
end

return M

