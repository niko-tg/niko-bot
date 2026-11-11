--- Отправка локальных ассетов (assets/) в Telegram.
--
-- Первый раз файл загружается multipart-ом, file_id из ответа кладётся
-- в спейс media_cache. Дальше отправка идёт по file_id без загрузки.
-- Если Telegram не принял file_id, кэш сбрасывается и файл загружается заново.
--
-- Пути ассетов относительные: 'pets/shop.jpg', 'kus/fox.mp4'.
--
-- @usage
-- local media = require('src.media')
--
-- media.sendPhoto({ chat_id = chatId, photo = 'pets/shop.jpg', caption = '...' })
-- media.sendAnimation({ chat_id = chatId, animation = 'kus/fox.mp4' })
-- media.editMessageMedia({
--   chat_id = chatId,
--   message_id = messageId,
--   media = { type = 'photo', media = 'pets/shop.jpg', caption = '...' },
-- })
--
local fio = require('fio')
local log = require('log')
local bot = require('bot')
local config = require('conf.config')
local tgErrors = require('src.utils.tgErrors')

local media = {}

-- Корень ассетов. Инстанс стартует из своего каталога (см. entrypoint).
local ROOT = fio.abspath(config.bot.assets_dir)

-- Имя multipart-части для editMessageMedia (media = 'attach://<имя>').
local ATTACH_NAME = 'asset'

local CONTENT_TYPES = {
  jpg = 'image/jpeg',
  jpeg = 'image/jpeg',
  png = 'image/png',
  gif = 'image/gif',
  mp4 = 'video/mp4',
}

--- Версия файла: размер и mtime. Нет файла - nil.
local function fileVersion(fullPath)
  local stat = fio.stat(fullPath)
  if not stat then
    return nil
  end

  return ('%d:%d'):format(stat.size, stat.mtime)
end

local function cacheGet(path, version)
  local tuple = box.space.media_cache:get(path)

  if tuple and tuple.version == version then
    return tuple.file_id
  end

  return nil
end

local function cacheSet(path, version, fileId)
  box.space.media_cache:replace({ path, version, fileId })
end

local function cacheDrop(path)
  box.space.media_cache:delete(path)
end

--- Файл для multipart: { data, filename, content_type }.
local function readFile(fullPath)
  local fd = fio.open(fullPath, { 'O_RDONLY' })
  if not fd then
    return nil
  end

  local data = fd:read()
  fd:close()

  if not data then
    return nil
  end

  local ext = (fullPath:match('%.([%w]+)$') or ''):lower()

  return {
    data = data,
    filename = fio.basename(fullPath),
    content_type = CONTENT_TYPES[ext] or 'application/octet-stream',
  }
end

--- file_id из отправленного сообщения.
-- Для фото - самый большой размер (последний в списке).
local function fileIdOf(message, kind)
  if type(message) ~= 'table' then
    return nil
  end

  if kind == 'photo' then
    local sizes = message.photo
    if type(sizes) == 'table' and #sizes > 0 then
      return sizes[#sizes].file_id
    end

    return nil
  end

  local object = message[kind] or message.document
  return object and object.file_id
end

--- Общая отправка ассета.
-- @tparam string method метод Bot API
-- @tparam string kind поле сообщения с файлом в ответе (photo/animation/...)
-- @tparam string path относительный путь ассета
-- @tparam function build (value, isUpload) -> fields: подставляет file_id или файл
local function send(method, kind, path, build)
  local fullPath = fio.pathjoin(ROOT, path)
  local version = fileVersion(fullPath)

  if not version then
    log.error('[Media] Asset not found: %s', fullPath)
    return nil, { description = 'Asset not found: '..path, __method = method }
  end

  local fileId = cacheGet(path, version)

  if fileId then
    local res, err = bot[method](bot, build(fileId, false))

    if not tgErrors.isBadFileId(err) then
      return res, err
    end

    log.warn('[Media] file_id rejected for %s, re-uploading', path)
    cacheDrop(path)
  end

  local file = readFile(fullPath)
  if not file then
    log.error('[Media] Cannot read asset: %s', fullPath)
    return nil, { description = 'Cannot read asset: '..path, __method = method }
  end

  local res, err = bot[method](bot, build(file, true), { multipart_post = true })

  if res then
    local newFileId = fileIdOf(res.result, kind)

    if newFileId then
      cacheSet(path, version, newFileId)
    end
  end

  return res, err
end

--- Копия полей с заменой одного поля (таблица вызывающего не меняется).
local function with(fields, key, value)
  local copy = table.copy(fields)
  copy[key] = value
  return copy
end

--- sendPhoto, fields.photo - путь ассета.
function media.sendPhoto(fields)
  return send('sendPhoto', 'photo', fields.photo, function(value)
    return with(fields, 'photo', value)
  end)
end

--- sendAnimation, fields.animation - путь ассета.
function media.sendAnimation(fields)
  return send('sendAnimation', 'animation', fields.animation, function(value)
    return with(fields, 'animation', value)
  end)
end

--- editMessageMedia, fields.media.media - путь ассета.
-- fields.media.type задаёт тип (photo/animation/video).
function media.editMessageMedia(fields)
  local kind = fields.media.type

  return send('editMessageMedia', kind, fields.media.media, function(value, isUpload)
    local inputMedia = table.copy(fields.media)
    local copy = table.copy(fields)

    if isUpload then
      inputMedia.media = 'attach://'..ATTACH_NAME
      copy[ATTACH_NAME] = value
    else
      inputMedia.media = value
    end

    copy.media = inputMedia
    return copy
  end)
end

return media
