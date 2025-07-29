local utils = require('mp.utils')
local msg = require('mp.msg')

local start_timestamp = nil

local function copy_array(orig)
    return table.move(orig, 1, #orig, 1, {})
end
local function append(cmd, ...)
    for i = 1, select('#', ...) do
        cmd[#cmd + 1] = select(i, ...)
    end
end
local function osd_set(str)
    mp.set_osd_ass(0, 0, str)
end
local function osd_msg(str)
    mp.osd_message(str)
end
local function get_extension_for_encoder(encoder)
    if encoder == 'libvpx' or encoder == 'libvpx-vp9' then
        return '.webm'
    end
    return '.mp4'
end
local function append_num_to_filename(dir, filename, extension)
    local res = utils.readdir(dir)
    if not res then
        return nil
    end
    local files = {}
    for _, f in ipairs(res) do
        files[f] = true
    end
    for i = 1, 1000 do
        local potential_name = filename .. '_' .. tostring(i) .. extension
        if not files[potential_name] then
            return potential_name
        end
    end
    return nil
end

-- clear state
local function clear()
    start_timestamp = nil
    mp.remove_key_binding('clear-timestamp')
    osd_set('')
end

--- @param o options
local function clip(o)
    if not mp.get_property('path') then
        osd_msg('clip: no file currently playing')
        msg.error('no file currently playing')
        clear()
        return
    end
    if not mp.get_property_bool('seekable') then
        osd_msg('clip: cannot create clips from non-seekable media')
        msg.error('cannot create clips from non-seekable media')
        clear()
        return
    end

    -- start clipping
    local from = start_timestamp
    msg.info('from = ' .. from)
    clear()
    local to = mp.get_property_number('time-pos')
    msg.info('to = ' .. to)
    if to <= from then
        osd_msg('clip: end timestamp cannot be before start')
        msg.error('end timestamp cannot be before start')
        return
    end

    -- add a frame to the end because ffmpeg's `-to` is exclusive but it makes more sense to add the last frame
    local fps = mp.get_property_number('container-fps') or 30
    to = math.floor((to + 1 / fps) * 1000) / 1000
    msg.info('to after adding a frame = ' .. to)

    -- path of the input
    local path = mp.get_property('path')
    msg.info('path = ' .. path)

    -- set up the command
    local cmd = {
        'ffmpeg',
        '-ss',
        tostring(from),
        '-to',
        tostring(to),
        '-i',
        path,
        '-c:a',
        o.audio_encoder,
        '-b:a',
        tostring(o.audio_bitrate),
        '-c:v',
        o.video_encoder,
        '-preset',
        o.preset,
    }

    -- map streams explicitly to what's currently playing
    local vid = mp.get_property('vid')
    msg.info('vid = ' .. vid)
    if vid and vid ~= 'no' then
        append(cmd, '-map', '0:v:' .. vid - 1)
    end
    local aid = mp.get_property('aid')
    msg.info('aid = ' .. aid)
    if aid and aid ~= 'no' then
        append(cmd, '-map', '0:a:' .. aid - 1)
    end
    local sid = mp.get_property('sid')
    msg.info('sid = ' .. sid)
    if sid and sid ~= 'no' then
        append(cmd, '-map', '0:s:' .. sid - 1)
    end

    -- calculate bitrate
    if o.file_size ~= 0 then
        local bitrate = math.floor(o.file_size * 8 / (to - from))
        msg.info('total bitrate = ' .. bitrate)
        local video_bitrate = bitrate - o.audio_bitrate
        append(cmd, '-b:v', tostring(video_bitrate))
        msg.info('video bitrate = ' .. video_bitrate)
    end

    -- generate path of the output
    local dir, filename = utils.split_path(path)
    local filename_without_ext = string.gsub(filename, '%.[^.]+$', '')
    local ext = get_extension_for_encoder(o.video_encoder)
    local output_dir = dir
    if o.output_dir ~= '' then
        output_dir = o.output_dir
    end
    local output_name = append_num_to_filename(output_dir, filename_without_ext, ext)
    if output_name == nil then
        osd_msg('clip: failed to generate output filename')
        msg.error('failed to generate output filename')
        return
    end
    local output_path = utils.join_path(output_dir, output_name)

    if not o.two_pass then
        append(cmd, output_path)
        msg.info('command = ' .. table.concat(cmd, ' '))
        osd_set(string.format('clip: encoding from %s to %s...', from, to))
        local res = utils.subprocess({ args = cmd })
        osd_set('')
        if res.status == 0 then
            osd_msg('clip: finished creating clip ' .. output_name)
            msg.info('finished encoding to ' .. output_name)
        else
            osd_msg('encode: failed to encode, check the console')
            msg.error('failed to encode')
        end
    else
        -- get a temp file for the first pass log
        local temp_file = os.tmpname()
        msg.info('passlogfile = ' .. temp_file)

        local first_pass = copy_array(cmd)
        append(first_pass, '-an', '-pass', '1', '-f', 'null', '-passlogfile', temp_file, '/dev/null')
        if package.config:sub(1, 1) == '\\' then
            -- windows
            first_pass[#first_pass] = 'NUL'
        end
        msg.info('command = ' .. table.concat(first_pass, ' '))
        osd_set(string.format('clip: analyzing...', from, to))
        local res = utils.subprocess({ args = first_pass })
        if res.status ~= 0 then
            osd_msg('clip: first pass failed, check the console')
            msg.error('first pass failed')
            os.remove(temp_file)
            os.remove(temp_file .. '-0.log')
            os.remove(temp_file .. '-0.log.mbtree')
            return
        end

        -- second pass
        osd_set(string.format('clip: encoding from %s to %s...', from, to))
        local second_pass = copy_array(cmd)
        append(second_pass, '-pass', '2', '-passlogfile', temp_file, output_path)
        msg.info('command = ' .. table.concat(second_pass, ' '))
        res = utils.subprocess({ args = second_pass })
        osd_set('')
        os.remove(temp_file)
        os.remove(temp_file .. '-0.log')
        os.remove(temp_file .. '-0.log.mbtree')
        if res.status == 0 then
            osd_msg('clip: finished creating clip ' .. output_name)
            msg.info('finished encoding to ' .. output_name)
        else
            osd_msg('encode: failed to encode, check the console')
            msg.error('failed to encode')
        end
    end
end

mp.register_script_message('clip', function(...)
    -- short circuit if no timestamp has been set yet
    if not start_timestamp then
        start_timestamp = mp.get_property_number('time-pos')
        osd_set('clip: waiting for timestamp')
        msg.info('waiting for timestamp')
        mp.add_forced_key_binding('ESC', 'clear-timestamp', clear)
        return
    end

    --- @class options
    --- @field file_size number
    --- @field video_encoder string
    --- @field audio_encoder string
    --- @field audio_bitrate number
    --- @field two_pass boolean
    --- @field preset string
    --- @field output_dir string
    local o = {
        file_size = 0,
        video_encoder = 'libx264',
        audio_encoder = 'aac',
        audio_bitrate = 128 * 1000,
        two_pass = false,
        preset = 'medium',
        output_dir = '',
    }

    -- parse named parameters, if any, into the options table
    local args = { ... }
    for _, arg in ipairs(args) do
        local key, value = arg:match('([^=]+)=([^=]+)')
        if key == 'file_size' then
            -- convert file_size from mebibytes to bytes
            o[key] = tonumber(value) * 1024 * 1024
        elseif key == 'video_encoder' then
            o[key] = value
        elseif key == 'audio_encoder' then
            o[key] = value
        elseif key == 'audio_bitrate' then
            o[key] = tonumber(value) * 1000
        elseif key == 'two_pass' then
            o[key] = value == 'true'
        elseif key == 'preset' then
            o[key] = value
        elseif key == 'output_dir' then
            o[key] = value
        end
    end

    msg.info('file_size = ' .. o.file_size)
    msg.info('video_encoder = ' .. o.video_encoder)
    msg.info('audio_encoder = ' .. o.audio_encoder)
    msg.info('audio_bitrate = ' .. o.audio_bitrate)
    msg.info('two_pass = ' .. tostring(o.two_pass))
    msg.info('preset = ' .. o.preset)
    msg.info('output_dir = ' .. o.output_dir)

    -- sanity checks
    if o.file_size < 0 then
        osd_msg('clip: file_size must be greater than or equal to 0')
        msg.error('file_size must be greater than or equal to 0')
        clear()
        return
    end
    if o.audio_bitrate < 0 then
        osd_msg('clip: audio_bitrate must be greater than or equal to 0')
        msg.error('audio_bitrate must be greater than or equal to 0')
        clear()
        return
    end
    if o.two_pass and o.file_size == 0 then
        osd_msg('clip: two_pass cannot be used without specifying a file_size')
        msg.error('two_pass cannot be used without specifying a file_size')
        clear()
        return
    end
    if o.output_dir ~= '' then
        local res = utils.readdir(o.output_dir)
        if not res then
            osd_msg('clip: output directory does not exist: ' .. o.output_dir)
            msg.error('output directory does not exist: ' .. o.output_dir)
            clear()
            return
        end
    end
    clip(o)
end)
