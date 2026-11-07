-- Exercise export routing and results without opening a catalog or touching photos.
local cases = 0
local function run(options)
    local done, notices, commands, deleted = {}, {}, {}, {}
    local current, serial = nil, 0
    local modules = {
        LrTasks = {
            pcall = pcall,
            execute = function(command)
                commands[#commands + 1] = command
                if current.executeError then error('process error') end
                return current.code or 0
            end,
        },
        LrFileUtils = {
            exists = function() if current.offline then return false end; return 'file' end,
            readFile = function()
                if current.readError then error('read error') end
                return current.report or 'completed\n'
            end,
            delete = function(path) deleted[#deleted + 1] = path; return true end,
            copy = function()
                if current.copyError then return false, 'copy failed' end
                return true
            end,
        },
        LrPathUtils = {
            child = function(a,b) return a .. '/' .. b end,
            getStandardFilePath = function() return '/temporary test' end,
        },
        LrUUID = { generateUUID = function() serial = serial + 1; return tostring(serial) end },
        LrDialogs = {
            message = function(title, text) notices[#notices + 1] = { kind = 'warning', text = text } end,
            showBezel = function(text) notices[#notices + 1] = { kind = 'bezel', text = text } end,
        },
    }
    import = function(name) return assert(modules[name], name) end
    _PLUGIN = { path = "/plugin's folder" }
    local filter = dofile('BirdBookBridge.lrplugin/FocusFilter.lua')
    local context = {
        propertyTable = { LR_format = options.format or 'JPEG', LR_embeddedMetadataOption = options.metadata or 'all' },
        renditions = function()
            local i = 0
            return function()
                i = i + 1; current = options.photos[i]
                if not current then return end
                local index, photo = i, current
                local source = {
                    waitForRender = function()
                        if photo.renderError then error('render exception') end
                        if photo.renderFailed then return false, 'render failed' end
                        return true, "/rendered's folder/照片.tif"
                    end,
                    photo = { getRawMetadata = function() return photo.original or "/original's folder/照片.ARW" end },
                }
                local target = {
                    destinationPath = photo.samePath and "/rendered's folder/照片.tif" or '/destination/photo.tif',
                    renditionIsDone = function(_, ok, message) done[index] = { ok = ok, message = message } end,
                }
                return source, target
            end
        end,
    }
    filter.postProcessRenderedPhotos(nil, context)
    return done, notices, commands, deleted
end
local function check(options, expected)
    cases = cases + 1
    local done, notices, commands, deleted = run(options)
    assert(#notices == (expected.notice and 1 or 0), 'notification count, case ' .. cases)
    if expected.notice then
        assert(notices[1].kind == expected.notice, 'notification kind, case ' .. cases)
        assert(notices[1].text:find(expected.text,1,true), notices[1].text)
    end
    assert(#commands == (expected.executions or 0), 'process count, case ' .. cases)
    assert(#deleted == #commands, 'temporary report cleanup, case ' .. cases)
    for _, result in ipairs(done) do assert(result.ok == (expected.ok ~= false), 'rendition result, case ' .. cases) end
    return done, notices, commands
end
for _, format in ipairs { 'JPEG', 'TIFF', 'PNG' } do
    check({format=format,photos={{}}},{notice='bezel',text='已补全 1 张',executions=1})
end
check({format='PSD',photos={{}}},{notice='warning',text='此格式暂不支持',executions=0})
check({metadata='copyrightOnly',photos={{}}},{notice='warning',text='保留了你的元数据选择',executions=0})
check({photos={{offline=true}}},{notice='warning',text='原片离线',executions=0})
check({photos={{original='/source/file.NEF'}}},{notice='warning',text='来源格式暂不支持',executions=0})
check({photos={{original='/source/file.JPG'}}},{notice='bezel',text='已补全 1 张',executions=1})
check({photos={{original='/source/file.jpeg'}}},{notice='bezel',text='已补全 1 张',executions=1})
check({photos={{report='unsupported-camera\n'}}},{notice='warning',text='相机暂不支持',executions=1})
check({photos={{report='partial-focus\n'}}},{notice='bezel',text='未添加对焦框',executions=1})
check({photos={{code=1}}},{notice='warning',text='处理失败',executions=1,ok=false})
check({photos={{executeError=true}}},{notice='warning',text='处理失败',executions=1,ok=false})
check({photos={{readError=true}}},{notice='warning',text='处理失败',executions=1,ok=false})
check({photos={{report='unexpected'}}},{notice='warning',text='失败 1 张',executions=1,ok=false})
check({photos={{copyError=true}}},{notice='warning',text='失败 1 张',executions=1,ok=false})
check({photos={{renderFailed=true}}},{notice='warning',text='失败 1 张',executions=0,ok=false})
check({photos={{renderError=true}}},{notice='warning',text='失败 1 张',executions=0,ok=false})
local _, _, commands = check({photos={{samePath=true}}},{notice='bezel',text='已补全 1 张',executions=1})
assert(commands[1]:find("'\\''",1,true), 'apostrophes must be shell-quoted')
check({photos={}},{executions=0})
local done, notices = run({photos={{code=1},{}}})
assert(not done[1].ok and done[2].ok, 'one failure must not abort subsequent photos')
assert(#notices==1 and notices[1].text:find('已补全 1 张',1,true) and notices[1].text:find('失败 1 张',1,true))
print('PASS: ' .. (cases + 1) .. ' export-flow cases; single batch result, failure recovery and shell quoting')
