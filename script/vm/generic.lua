local nodeMgr = require 'vm.node'
local union   = require 'vm.union'

---@class parser.object
---@field _generic vm.generic

---@class vm.generic
---@field sign  vm.sign
---@field proto vm.node
local mt = {}
mt.__index = mt
mt.type = 'generic'

---@param source    parser.object
---@param resolved? table<string, vm.node>
---@return parser.object | vm.union
local function cloneObject(source, resolved)
    if not resolved then
        return source
    end
    if source.type == 'doc.generic.name' then
        local key = source[1]
        local newName = {
            type   = source.type,
            start  = source.start,
            finish = source.finish,
            parent = source.parent,
            [1]    = source[1],
        }
        nodeMgr.setNode(newName, resolved[key], true)
        return newName
    end
    if source.type == 'doc.type' then
        local newType = {
            type   = source.type,
            start  = source.start,
            finish = source.finish,
            parent = source.parent,
            types  = {},
        }
        for i, typeUnit in ipairs(source.types) do
            local newObj     = cloneObject(typeUnit, resolved)
            newType.types[i] = newObj
        end
        return newType
    end
    if source.type == 'doc.type.arg' then
        local newArg = {
            type    = source.type,
            start   = source.start,
            finish  = source.finish,
            parent  = source.parent,
            name    = source.name,
            extends = cloneObject(source.extends, resolved)
        }
        return newArg
    end
    if source.type == 'doc.type.array' then
        local newArray = {
            type   = source.type,
            start  = source.start,
            finish = source.finish,
            parent = source.parent,
            node   = cloneObject(source.node, resolved),
        }
        return newArray
    end
    if source.type == 'doc.type.table' then
        local newTable = {
            type   = source.type,
            start  = source.start,
            finish = source.finish,
            parent = source.parent,
            fields = {},
        }
        for i, field in ipairs(source.fields) do
            local newField = {
                type    = field.type,
                start   = field.start,
                finish  = field.finish,
                parent  = newTable,
                name    = cloneObject(field.name, resolved),
                extends = cloneObject(field.extends, resolved),
            }
            newTable.fields[i] = newField
        end
        return newTable
    end
    if source.type == 'doc.type.function' then
        local newDocFunc = {
            type    = source.type,
            start   = source.start,
            finish  = source.finish,
            parent  = source.parent,
            args    = {},
            returns = {},
        }
        for i, arg in ipairs(source.args) do
            local newObj = cloneObject(arg, resolved)
            if arg.optional and newObj.type == 'vm.union' then
                newObj:addOptional()
            end
            newDocFunc.args[i] = newObj
        end
        for i, ret in ipairs(source.returns) do
            local newObj  = cloneObject(ret, resolved)
            newObj.parent = newDocFunc
            if ret.optional and newObj.type == 'vm.union' then
                newObj:addOptional()
            end
            newDocFunc.returns[i] = cloneObject(ret, resolved)
        end
        return newDocFunc
    end
    return source
end

---@param uri uri
---@param args parser.object
---@return parser.object
function mt:resolve(uri, args)
    local compiler = require 'vm.compiler'
    local resolved = self.sign:resolve(uri, args)
    local result = union()
    for nd in nodeMgr.eachObject(self.proto) do
        local clonedNode = compiler.compileNode(cloneObject(nd, resolved))
        result:merge(clonedNode)
    end
    return result
end

---@param proto vm.node
---@param sign  vm.sign
return function (proto, sign)
    local generic = setmetatable({
        sign  = sign,
        proto = proto,
    }, mt)
    return generic
end
