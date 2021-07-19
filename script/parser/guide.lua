local error        = error
local type         = type

---@class parser.guide.object
---@field bindDocs              parser.guide.object[]
---@field bindGroup             parser.guide.object[]
---@field bindSources           parser.guide.object[]
---@field value                 parser.guide.object
---@field parent                parser.guide.object
---@field type                  string
---@field special               string
---@field tag                   string
---@field args                  parser.guide.object[]
---@field locals                parser.guide.object[]
---@field returns               parser.guide.object[]
---@field uri                   uri
---@field start                 integer
---@field finish                integer
---@field effect                integer
---@field attrs                 string[]
---@field specials              parser.guide.object[]
---@field labels                parser.guide.object[]
---@field node                  parser.guide.object
---@field dummy                 boolean
---@field field                 parser.guide.object
---@field method                parser.guide.object
---@field index                 parser.guide.object
---@field extends               parser.guide.object[]
---@field types                 parser.guide.object[]
---@field enums                 parser.guide.object[]
---@field resumes               parser.guide.object[]
---@field fields                parser.guide.object[]
---@field typeGeneric           table<integer, parser.guide.object[]>
---@field tkey                  parser.guide.object
---@field tvalue                parser.guide.object
---@field tindex                integer
---@field op                    parser.guide.object
---@field next                  parser.guide.object
---@field docParam              parser.guide.object
---@field sindex                integer
---@field name                  parser.guide.object
---@field call                  parser.guide.object
---@field closure               parser.guide.object
---@field proto                 parser.guide.object
---@field exp                   parser.guide.object
---@field isGeneric             boolean
---@field alias                 parser.guide.object
---@field class                 parser.guide.object
---@field vararg                parser.guide.object
---@field param                 parser.guide.object
---@field overload              parser.guide.object
---@field docParamMap           table<string, integer>
---@field upvalues              table<string, string[]>
---@field ref                   parser.guide.object[]
---@field returnIndex           integer
---@field _root                 parser.guide.object
---@field _noders               noders
---@field _mnode                parser.guide.object

---@class guide
---@field debugMode boolean
local m = {}

m.ANY = {"<ANY>"}

local blockTypes = {
    ['while']       = true,
    ['in']          = true,
    ['loop']        = true,
    ['repeat']      = true,
    ['do']          = true,
    ['function']    = true,
    ['ifblock']     = true,
    ['elseblock']   = true,
    ['elseifblock'] = true,
    ['main']        = true,
}

local breakBlockTypes = {
    ['while']       = true,
    ['in']          = true,
    ['loop']        = true,
    ['repeat']      = true,
}

m.childMap = {
    ['main']        = {'#', 'docs'},
    ['repeat']      = {'#', 'filter'},
    ['while']       = {'filter', '#'},
    ['in']          = {'keys', '#'},
    ['loop']        = {'loc', 'max', 'step', '#'},
    ['if']          = {'#'},
    ['ifblock']     = {'filter', '#'},
    ['elseifblock'] = {'filter', '#'},
    ['elseblock']   = {'#'},
    ['setfield']    = {'node', 'field', 'value'},
    ['setglobal']   = {'value'},
    ['local']       = {'attrs', 'value'},
    ['setlocal']    = {'value'},
    ['return']      = {'#'},
    ['do']          = {'#'},
    ['select']      = {'vararg'},
    ['table']       = {'#'},
    ['tableindex']  = {'index', 'value'},
    ['tablefield']  = {'field', 'value'},
    ['tableexp']    = {'value'},
    ['function']    = {'args', '#'},
    ['funcargs']    = {'#'},
    ['setmethod']   = {'node', 'method', 'value'},
    ['getmethod']   = {'node', 'method'},
    ['setindex']    = {'node', 'index', 'value'},
    ['getindex']    = {'node', 'index'},
    ['paren']       = {'exp'},
    ['call']        = {'node', 'args'},
    ['callargs']    = {'#'},
    ['getfield']    = {'node', 'field'},
    ['list']        = {'#'},
    ['binary']      = {1, 2},
    ['unary']       = {1},

    ['doc']                = {'#'},
    ['doc.class']          = {'class', '#extends', 'comment'},
    ['doc.type']           = {'#types', '#enums', '#resumes', 'name', 'comment'},
    ['doc.alias']          = {'alias', 'extends', 'comment'},
    ['doc.param']          = {'param', 'extends', 'comment'},
    ['doc.return']         = {'#returns', 'comment'},
    ['doc.field']          = {'field', 'extends', 'comment'},
    ['doc.generic']        = {'#generics', 'comment'},
    ['doc.generic.object'] = {'generic', 'extends', 'comment'},
    ['doc.vararg']         = {'vararg', 'comment'},
    ['doc.type.array']     = {'node'},
    ['doc.type.table']     = {'tkey', 'tvalue', 'comment'},
    ['doc.type.function']  = {'#args', '#returns', 'comment'},
    ['doc.type.ltable']    = {'#fields', 'comment'},
    ['doc.type.literal']   = {'node'},
    ['doc.type.arg']       = {'extends'},
    ['doc.type.field']     = {'extends'},
    ['doc.overload']       = {'overload', 'comment'},
    ['doc.see']            = {'name', 'field'},
}

m.actionMap = {
    ['main']        = {'#'},
    ['repeat']      = {'#'},
    ['while']       = {'#'},
    ['in']          = {'#'},
    ['loop']        = {'#'},
    ['if']          = {'#'},
    ['ifblock']     = {'#'},
    ['elseifblock'] = {'#'},
    ['elseblock']   = {'#'},
    ['do']          = {'#'},
    ['function']    = {'#'},
    ['funcargs']    = {'#'},
}

local inf          = 1 / 0
local nan          = 0 / 0

local function isInteger(n)
    if math.type then
        return math.type(n) == 'integer'
    else
        return type(n) == 'number' and n % 1 == 0
    end
end

local function formatNumber(n)
    if n == inf
    or n == -inf
    or n == nan
    or n ~= n then -- IEEE 标准中，NAN 不等于自己。但是某些实现中没有遵守这个规则
        return ('%q'):format(n)
    end
    if isInteger(n) then
        return tostring(n)
    end
    local str = ('%.10f'):format(n)
    str = str:gsub('%.?0*$', '')
    return str
end

--- 是否是字面量
---@param obj parser.guide.object
---@return boolean
function m.isLiteral(obj)
    local tp = obj.type
    return tp == 'nil'
        or tp == 'boolean'
        or tp == 'string'
        or tp == 'number'
        or tp == 'integer'
        or tp == 'table'
        or tp == 'function'
end

--- 获取字面量
---@param obj parser.guide.object
---@return any
function m.getLiteral(obj)
    local tp = obj.type
    if     tp == 'boolean' then
        return obj[1]
    elseif tp == 'string' then
        return obj[1]
    elseif tp == 'number' then
        return obj[1]
    elseif tp == 'integer' then
        return obj[1]
    end
    return nil
end

--- 寻找父函数
---@param obj parser.guide.object
---@return parser.guide.object
function m.getParentFunction(obj)
    for _ = 1, 1000 do
        obj = obj.parent
        if not obj then
            break
        end
        local tp = obj.type
        if tp == 'function' or tp == 'main' then
            return obj
        end
    end
    return nil
end

--- 寻找所在区块
---@param obj parser.guide.object
---@return parser.guide.object
function m.getBlock(obj)
    for _ = 1, 1000 do
        if not obj then
            return nil
        end
        local tp = obj.type
        if blockTypes[tp] then
            return obj
        end
        if obj == obj.parent then
            error('obj == obj.parent?', obj.type)
        end
        obj = obj.parent
    end
    -- make stack
    local stack = {}
    for _ = 1, 10 do
        stack[#stack+1] = ('%s:%s'):format(obj.type, obj.finish)
        obj = obj.parent
        if not obj then
            break
        end
    end
    error('guide.getBlock overstack:' .. table.concat(stack, ' -> '))
end

--- 寻找所在父区块
---@param obj parser.guide.object
---@return parser.guide.object
function m.getParentBlock(obj)
    for _ = 1, 1000 do
        obj = obj.parent
        if not obj then
            return nil
        end
        local tp = obj.type
        if blockTypes[tp] then
            return obj
        end
    end
    error('guide.getParentBlock overstack')
end

--- 寻找所在可break的父区块
---@param obj parser.guide.object
---@return parser.guide.object
function m.getBreakBlock(obj)
    for _ = 1, 1000 do
        obj = obj.parent
        if not obj then
            return nil
        end
        local tp = obj.type
        if breakBlockTypes[tp] then
            return obj
        end
        if tp == 'function' then
            return nil
        end
    end
    error('guide.getBreakBlock overstack')
end

--- 寻找doc的主体
---@param obj parser.guide.object
---@return parser.guide.object
function m.getDocState(obj)
    for _ = 1, 1000 do
        local parent = obj.parent
        if not parent then
            return obj
        end
        if parent.type == 'doc' then
            return obj
        end
        obj = parent
    end
    error('guide.getDocState overstack')
end

--- 寻找所在父类型
---@param obj parser.guide.object
---@return parser.guide.object
function m.getParentType(obj, want)
    for _ = 1, 1000 do
        obj = obj.parent
        if not obj then
            return nil
        end
        if want == obj.type then
            return obj
        end
    end
    error('guide.getParentType overstack')
end

--- 寻找根区块
---@param obj parser.guide.object
---@return parser.guide.object
function m.getRoot(obj)
    local source = obj
    if source._root then
        return source._root
    end
    for _ = 1, 1000 do
        if obj.type == 'main' then
            source._root = obj
            return obj
        end
        if obj._root then
            source._root = obj._root
            return source._root
        end
        local parent = obj.parent
        if not parent then
            return nil
        end
        obj = parent
    end
    error('guide.getRoot overstack')
end

---@param obj parser.guide.object
---@return string
function m.getUri(obj)
    if obj.uri then
        return obj.uri
    end
    local root = m.getRoot(obj)
    if root then
        return root.uri or ''
    end
    return ''
end

function m.getENV(source, start)
    if not start then
        start = 1
    end
    return m.getLocal(source, '_ENV', start)
        or m.getLocal(source, '@fenv', start)
end

--- 寻找函数的不定参数，返回不定参在第几个参数上，以及该参数对象。
--- 如果函数是主函数，则返回`0, nil`。
---@return table
---@return integer
function m.getFunctionVarArgs(func)
    if func.type == 'main' then
        return 0, nil
    end
    if func.type ~= 'function' then
        return nil, nil
    end
    local args = func.args
    if not args then
        return nil, nil
    end
    for i = 1, #args do
        local arg = args[i]
        if arg.type == '...' then
            return i, arg
        end
    end
    return nil, nil
end

--- 获取指定区块中可见的局部变量
---@param block table
---@param name string {comment = '变量名'}
---@param pos integer {comment = '可见位置'}
function m.getLocal(block, name, pos)
    block = m.getBlock(block)
    for _ = 1, 1000 do
        if not block then
            return nil
        end
        local locals = block.locals
        local res
        if not locals then
            goto CONTINUE
        end
        for i = 1, #locals do
            local loc = locals[i]
            if loc.effect > pos then
                break
            end
            if loc[1] == name then
                if not res or res.effect < loc.effect then
                    res = loc
                end
            end
        end
        if res then
            return res, res
        end
        ::CONTINUE::
        block = m.getParentBlock(block)
    end
    error('guide.getLocal overstack')
end

--- 获取指定区块中所有的可见局部变量名称
function m.getVisibleLocals(block, pos)
    local result = {}
    m.eachSourceContain(m.getRoot(block), pos, function (source)
        local locals = source.locals
        if locals then
            for i = 1, #locals do
                local loc = locals[i]
                local name = loc[1]
                if loc.effect <= pos then
                    result[name] = loc
                end
            end
        end
    end)
    return result
end

--- 获取指定区块中可见的标签
---@param block table
---@param name string {comment = '标签名'}
function m.getLabel(block, name)
    block = m.getBlock(block)
    for _ = 1, 1000 do
        if not block then
            return nil
        end
        local labels = block.labels
        if labels then
            local label = labels[name]
            if label then
                return label
            end
        end
        if block.type == 'function' then
            return nil
        end
        block = m.getParentBlock(block)
    end
    error('guide.getLocal overstack')
end

function m.getStartFinish(source)
    local start  = source.start
    local finish = source.finish
    if not start then
        local first = source[1]
        if not first then
            return nil, nil
        end
        local last  = source[#source]
        start  = first.start
        finish = last.finish
    end
    return start, finish
end

function m.getRange(source)
    local start  = source.vstart or source.start
    local finish = source.range  or source.finish
    if not start then
        local first = source[1]
        if not first then
            return nil, nil
        end
        local last  = source[#source]
        start  = first.vstart or first.start
        finish = last.range   or last.finish
    end
    return start, finish
end

--- 判断source是否包含offset
function m.isContain(source, offset)
    local start, finish = m.getStartFinish(source)
    if not start then
        return false
    end
    return start <= offset and finish >= offset
end

--- 判断offset在source的影响范围内
---
--- 主要针对赋值等语句时，key包含value
function m.isInRange(source, offset)
    local start, finish = m.getRange(source)
    if not start then
        return false
    end
    return start <= offset and finish >= offset
end

function m.isBetween(source, tStart, tFinish)
    local start, finish = m.getStartFinish(source)
    if not start then
        return false
    end
    return start <= tFinish and finish >= tStart
end

function m.isBetweenRange(source, tStart, tFinish)
    local start, finish = m.getRange(source)
    if not start then
        return false
    end
    return start <= tFinish and finish >= tStart
end

--- 添加child
function m.addChilds(list, obj, map)
    local keys = map[obj.type]
    if keys then
        for i = 1, #keys do
            local key = keys[i]
            if key == '#' then
                for j = 1, #obj do
                    list[#list+1] = obj[j]
                end
            elseif obj[key] then
                list[#list+1] = obj[key]
            elseif type(key) == 'string'
            and key:sub(1, 1) == '#' then
                key = key:sub(2)
                if obj[key] then
                    for j = 1, #obj[key] do
                        list[#list+1] = obj[key][j]
                    end
                end
            end
        end
    end
end

--- 遍历所有包含offset的source
function m.eachSourceContain(ast, offset, callback)
    local list = { ast }
    local mark = {}
    while true do
        local len = #list
        if len == 0 then
            return
        end
        local obj = list[len]
        list[len] = nil
        if not mark[obj] then
            mark[obj] = true
            if m.isInRange(obj, offset) then
                if m.isContain(obj, offset) then
                    local res = callback(obj)
                    if res ~= nil then
                        return res
                    end
                end
                m.addChilds(list, obj, m.childMap)
            end
        end
    end
end

--- 遍历所有在某个范围内的source
function m.eachSourceBetween(ast, start, finish, callback)
    local list = { ast }
    local mark = {}
    while true do
        local len = #list
        if len == 0 then
            return
        end
        local obj = list[len]
        list[len] = nil
        if not mark[obj] then
            mark[obj] = true
            if m.isBetweenRange(obj, start, finish) then
                if m.isBetween(obj, start, finish) then
                    local res = callback(obj)
                    if res ~= nil then
                        return res
                    end
                end
                m.addChilds(list, obj, m.childMap)
            end
        end
    end
end

--- 遍历所有指定类型的source
function m.eachSourceType(ast, type, callback)
    local cache = ast.typeCache
    if not cache then
        cache = {}
        ast.typeCache = cache
        m.eachSource(ast, function (source)
            local tp = source.type
            if not tp then
                return
            end
            local myCache = cache[tp]
            if not myCache then
                myCache = {}
                cache[tp] = myCache
            end
            myCache[#myCache+1] = source
        end)
    end
    local myCache = cache[type]
    if not myCache then
        return
    end
    for i = 1, #myCache do
        callback(myCache[i])
    end
end

--- 遍历所有的source
function m.eachSource(ast, callback)
    local list = { ast }
    local mark = {}
    local index = 1
    while true do
        local obj = list[index]
        if not obj then
            return
        end
        list[index] = false
        index = index + 1
        if not mark[obj] then
            mark[obj] = true
            local res = callback(obj)
            if res == true then
                goto CONTINUE
            end
            if res == false then
                return
            end
            m.addChilds(list, obj, m.childMap)
        end
        ::CONTINUE::
    end
end

--- 获取指定的 special
function m.eachSpecialOf(ast, name, callback)
    local root = m.getRoot(ast)
    if not root.specials then
        return
    end
    local specials = root.specials[name]
    if not specials then
        return
    end
    for i = 1, #specials do
        callback(specials[i])
    end
end

--- 获取偏移对应的坐标
---@param lines table
---@return integer {name = 'row'}
---@return integer {name = 'col'}
function m.positionOf(lines, offset)
    if offset < 1 then
        return 0, 0
    end
    local lastLine = lines[#lines]
    if offset > lastLine.finish then
        return #lines, offset - lastLine.start + 1
    end
    local min = 1
    local max = #lines
    for _ = 1, 100 do
        if max <= min then
            local line = lines[min]
            return min, offset - line.start + 1
        end
        local row = (max - min) // 2 + min
        local line = lines[row]
        if offset < line.start then
            max = row - 1
        elseif offset > line.finish then
            min = row + 1
        else
            return row, offset - line.start + 1
        end
    end
    error('Stack overflow!')
end

--- 获取坐标对应的偏移
---@param lines table
---@param row integer
---@param col integer
---@return integer {name = 'offset'}
function m.offsetOf(lines, row, col)
    if row < 1 then
        return 0
    end
    if row > #lines then
        local lastLine = lines[#lines]
        return lastLine.finish
    end
    local line = lines[row]
    local len = line.finish - line.start + 1
    if col < 0 then
        return line.start
    elseif col > len then
        return line.finish
    else
        return line.start + col - 1
    end
end

function m.lineContent(lines, text, row, ignoreNL)
    local line = lines[row]
    if not line then
        return ''
    end
    if ignoreNL then
        return text:sub(line.start, line.range)
    else
        return text:sub(line.start, line.finish)
    end
end

function m.lineRange(lines, row, ignoreNL)
    local line = lines[row]
    if not line then
        return 0, 0
    end
    if ignoreNL then
        return line.start, line.range
    else
        return line.start, line.finish
    end
end

function m.lineData(lines, row)
    return lines[row]
end

function m.isSet(source)
    local tp = source.type
    if tp == 'setglobal'
    or tp == 'local'
    or tp == 'setlocal'
    or tp == 'setfield'
    or tp == 'setmethod'
    or tp == 'setindex'
    or tp == 'tablefield'
    or tp == 'tableindex'
    or tp == 'tableexp' then
        return true
    end
    if tp == 'call' then
        local special = m.getSpecial(source.node)
        if special == 'rawset' then
            return true
        end
    end
    return false
end

function m.isGet(source)
    local tp = source.type
    if tp == 'getglobal'
    or tp == 'getlocal'
    or tp == 'getfield'
    or tp == 'getmethod'
    or tp == 'getindex' then
        return true
    end
    if tp == 'call' then
        local special = m.getSpecial(source.node)
        if special == 'rawget' then
            return true
        end
    end
    return false
end

function m.getSpecial(source)
    if not source then
        return nil
    end
    return source.special
end

function m.getKeyNameOfLiteral(obj)
    if not obj then
        return nil
    end
    local tp = obj.type
    if tp == 'field'
    or     tp == 'method' then
        return obj[1]
    elseif tp == 'string' then
        local s = obj[1]
        if s then
            return s
        end
    elseif tp == 'number' then
        local n = obj[1]
        if n then
            return formatNumber(obj[1])
        end
    elseif tp == 'integer' then
        local n = obj[1]
        if n then
            return formatNumber(obj[1])
        end
    elseif tp == 'boolean' then
        local b = obj[1]
        if b then
            return tostring(b)
        end
    end
end

function m.getKeyName(obj)
    if not obj then
        return nil
    end
    local tp = obj.type
    if tp == 'getglobal'
    or tp == 'setglobal' then
        return obj[1]
    elseif tp == 'local'
    or     tp == 'getlocal'
    or     tp == 'setlocal' then
        return obj[1]
    elseif tp == 'getfield'
    or     tp == 'setfield'
    or     tp == 'tablefield' then
        if obj.field then
            return obj.field[1]
        end
    elseif tp == 'getmethod'
    or     tp == 'setmethod' then
        if obj.method then
            return obj.method[1]
        end
    elseif tp == 'getindex'
    or     tp == 'setindex'
    or     tp == 'tableindex' then
        return m.getKeyNameOfLiteral(obj.index)
    elseif tp == 'tableexp' then
        return tostring(obj.tindex)
    elseif tp == 'field'
    or     tp == 'method'
    or     tp == 'doc.see.field' then
        return obj[1]
    elseif tp == 'doc.class' then
        return obj.class[1]
    elseif tp == 'doc.alias' then
        return obj.alias[1]
    elseif tp == 'doc.field' then
        return tostring(obj.field[1])
    elseif tp == 'doc.field.name' then
        return tostring(obj[1])
    elseif tp == 'doc.type.field' then
        return tostring(obj.name[1])
    elseif tp == 'dummy' then
        return obj[1]
    end
    return m.getKeyNameOfLiteral(obj)
end

function m.getKeyTypeOfLiteral(obj)
    if not obj then
        return nil
    end
    local tp = obj.type
    if tp == 'field'
    or     tp == 'method' then
        return 'string'
    elseif tp == 'string' then
        return 'string'
    elseif tp == 'number' then
        return 'number'
    elseif tp == 'integer' then
        return 'integer'
    elseif tp == 'boolean' then
        return 'boolean'
    end
end

function m.getKeyType(obj)
    if not obj then
        return nil
    end
    local tp = obj.type
    if tp == 'getglobal'
    or tp == 'setglobal' then
        return 'string'
    elseif tp == 'local'
    or     tp == 'getlocal'
    or     tp == 'setlocal' then
        return 'local'
    elseif tp == 'getfield'
    or     tp == 'setfield'
    or     tp == 'tablefield' then
        return 'string'
    elseif tp == 'getmethod'
    or     tp == 'setmethod' then
        return 'string'
    elseif tp == 'getindex'
    or     tp == 'setindex'
    or     tp == 'tableindex' then
        return m.getKeyTypeOfLiteral(obj.index)
    elseif tp == 'tableexp' then
        return 'integer'
    elseif tp == 'field'
    or     tp == 'method'
    or     tp == 'doc.see.field' then
        return 'string'
    elseif tp == 'doc.class' then
        return 'string'
    elseif tp == 'doc.alias' then
        return 'string'
    elseif tp == 'doc.field' then
        return type(obj.field[1])
    elseif tp == 'doc.type.field' then
        return type(obj.name[1])
    elseif tp == 'dummy' then
        return 'string'
    end
    if tp == 'doc.field.name' then
        return type(obj[1])
    end
    return m.getKeyTypeOfLiteral(obj)
end

--- 测试 a 到 b 的路径（不经过函数，不考虑 goto），
--- 每个路径是一个 block 。
---
--- 如果 a 在 b 的前面，返回 `"before"` 加上 2个`list<block>`
---
--- 如果 a 在 b 的后面，返回 `"after"` 加上 2个`list<block>`
---
--- 否则返回 `false`
---
--- 返回的2个 `list` 分别为基准block到达 a 与 b 的路径。
---@param a table
---@param b table
---@return string|boolean mode
---@return table pathA?
---@return table pathB?
function m.getPath(a, b, sameFunction)
    --- 首先测试双方在同一个函数内
    if sameFunction and m.getParentFunction(a) ~= m.getParentFunction(b) then
        return false
    end
    local mode
    local objA
    local objB
    if a.finish < b.start then
        mode = 'before'
        objA = a
        objB = b
    elseif a.start > b.finish then
        mode = 'after'
        objA = b
        objB = a
    else
        return 'equal', {}, {}
    end
    local pathA = {}
    local pathB = {}
    for _ = 1, 1000 do
        objA = m.getParentBlock(objA)
        pathA[#pathA+1] = objA
        if (not sameFunction and objA.type == 'function') or objA.type == 'main' then
            break
        end
    end
    for _ = 1, 1000 do
        objB = m.getParentBlock(objB)
        pathB[#pathB+1] = objB
        if (not sameFunction and objA.type == 'function') or objB.type == 'main' then
            break
        end
    end
    -- pathA: {1, 2, 3, 4, 5}
    -- pathB: {5, 6, 2, 3}
    local top = #pathB
    local start
    for i = #pathA, 1, -1 do
        local currentBlock = pathA[i]
        if currentBlock == pathB[top] then
            start = i
            break
        end
    end
    if not start then
        return nil
    end
    -- pathA: {   1, 2, 3}
    -- pathB: {5, 6, 2, 3}
    local extra = 0
    local align = top - start
    for i = start, 1, -1 do
        local currentA = pathA[i]
        local currentB = pathB[i+align]
        if currentA ~= currentB then
            extra = i
            break
        end
    end
    -- pathA: {1}
    local resultA = {}
    for i = extra, 1, -1 do
        resultA[#resultA+1] = pathA[i]
    end
    -- pathB: {5, 6}
    local resultB = {}
    for i = extra + align, 1, -1 do
        resultB[#resultB+1] = pathB[i]
    end
    return mode, resultA, resultB
end

---是否是全局变量（包括 _G.XXX 形式）
---@param source parser.guide.object
---@return boolean
function m.isGlobal(source)
    if source._isGlobal ~= nil then
        return source._isGlobal
    end
    if source.special == '_G' then
        source._isGlobal = true
        return true
    end
    if source.type == 'setglobal'
    or source.type == 'getglobal' then
        if source.node and source.node.tag == '_ENV' then
            source._isGlobal = true
            return true
        end
    end
    if source.type == 'setfield'
    or source.type == 'getfield'
    or source.type == 'setindex'
    or source.type == 'getindex' then
        local current = source
        while current do
            local node = current.node
            if not node then
                break
            end
            if node.special == '_G' then
                source._isGlobal = true
                return true
            end
            if m.getKeyName(node) ~= '_G' then
                break
            end
            current = node
        end
    end
    if source.type == 'call' then
        local node = source.node
        if node.special == 'rawget'
        or node.special == 'rawset' then
            if source.args and source.args[1] then
                local isGlobal = source.args[1].special == '_G'
                source._isGlobal = isGlobal
                return isGlobal
            end
        end
    end
    source._isGlobal = false
    return false
end

return m
