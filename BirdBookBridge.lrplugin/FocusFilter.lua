local LrTasks = import 'LrTasks'
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrUUID = import 'LrUUID'
local LrDialogs = import 'LrDialogs'

local formats = { JPEG = true, TIFF = true, PNG = true }
local reasons = {
    format = '此格式暂不支持补全；请选择 JPEG、TIFF 或 PNG。',
    metadata = '本次保留了你的元数据选择；如需补全，请选择“所有元数据”。',
    source = '来源格式暂不支持；目前支持索尼 α1 II 的 ARW、JPG 和 JPEG。',
    offline = '原片离线；请先在 Lightroom 中找到原片后重试。',
    camera = '相机暂不支持；目前支持索尼 α1 II。',
    failed = '处理失败；请检查原片是否可读，以及导出位置是否可写。',
}

local function quote(path)
    return "'" .. path:gsub("'", "'\\''") .. "'"
end

local function finishPhoto(source, target, settings)
    local ok, path = source:waitForRender()
    if not ok then return false, path, 'failed', 'failed' end
    local original = source.photo:getRawMetadata('path')
    local state, reason = 'skipped', nil
    if not formats[settings.LR_format] then
        reason = 'format'
    elseif settings.LR_embeddedMetadataOption and settings.LR_embeddedMetadataOption ~= 'all' then
        reason = 'metadata'
    elseif not original or LrFileUtils.exists(original) ~= 'file' then
        reason = 'offline'
    elseif not (original:lower():match('%.arw$') or original:lower():match('%.jpe?g$')) then
        reason = 'source'
    else
        local helper = LrPathUtils.child(_PLUGIN.path, 'write-focus.pl')
        local reportPath = LrPathUtils.child(LrPathUtils.getStandardFilePath('temp'), 'BBB-' .. LrUUID.generateUUID() .. '.txt')
        local ran, code = LrTasks.pcall(LrTasks.execute,
            '/usr/bin/perl ' .. quote(helper) .. ' ' .. quote(original) .. ' ' .. quote(path) .. ' > ' .. quote(reportPath))
        local readOK, report = LrTasks.pcall(LrFileUtils.readFile, reportPath)
        LrFileUtils.delete(reportPath)
        if not ran or code ~= 0 or not readOK then
            return false, reasons.failed, 'failed', 'failed'
        end
        report = report:match('^%s*(.-)%s*$')
        if report == 'completed' then
            state = 'completed'
        elseif report == 'partial-focus' then
            state = 'partial'
        elseif report == 'unsupported-camera' then
            reason = 'camera'
        else
            return false, '未能确认补全结果，请重新导出；如仍失败，请检查插件是否完整。', 'failed', 'failed'
        end
    end
    if path ~= target.destinationPath then
        local copied, message = LrFileUtils.copy(path, target.destinationPath)
        if not copied then return false, message or reasons.failed, 'failed', 'failed' end
    end
    return true, nil, state, reason
end

return {
    sectionForFilterInDialog = function(f)
        return { title = 'BirdBook Bridge (BBB)',
            f:static_text { title = '自动补全拍摄信息，无需逐项选择。支持 α1 II 的 ARW 和相机 JPG。' },
            f:static_text { title = '导出为 JPEG / TIFF / PNG；首次选“所有元数据”并保存预设，以后正常导出。' },
        }
    end,
    postProcessRenderedPhotos = function(_, context)
        local counts = { completed = 0, partial = 0, skipped = 0, failed = 0 }
        local found = {}
        for source, target in context:renditions { stopIfCanceled = true } do
            local ran, ok, message, state, reason = LrTasks.pcall(finishPhoto, source, target, context.propertyTable)
            if not ran then
                ok, message, state, reason = false, reasons.failed, 'failed', 'failed'
            end
            target:renditionIsDone(ok, message)
            counts[state] = counts[state] + 1
            if reason then found[reason] = true end
        end
        local total = counts.completed + counts.partial + counts.skipped + counts.failed
        if total == 0 then return end
        local summary = string.format('已补全 %d 张 · 部分补全 %d 张 · 未补全 %d 张 · 失败 %d 张',
            counts.completed, counts.partial, counts.skipped, counts.failed)
        local details = {}
        if counts.partial > 0 then details[#details + 1] = '部分补全：拍摄信息已处理，但未添加对焦框。' end
        for _, key in ipairs { 'format', 'metadata', 'source', 'offline', 'camera', 'failed' } do
            if found[key] then details[#details + 1] = reasons[key] end
        end
        if counts.skipped > 0 or counts.failed > 0 then
            LrDialogs.message('BBB 导出结果', summary .. '\n\n' .. table.concat(details, '\n'), 'warning')
        else
            LrDialogs.showBezel('BBB：' .. summary .. (#details > 0 and '\n' .. details[1] or ''), 6)
        end
    end,
}
