-- Rewrites Polarion's fixed base URL (http://localhost/) to the host:port the client really
-- used (Host header), so the image works on any published port without extra parameters.
-- Two needle forms are replaced, only in JSON and HTML answers; encoded (gzip) answers and
-- static assets pass through:
--   http://localhost/   -> http://<Host>/    URLs in JSON payloads and HTML attributes
--   "http://localhost"  -> "http://<Host>"   bare JSON string value (no trailing slash) that
--                                             GWT-RPC answers carry and Polarion Apps append
--                                             paths to — without this they lose a non-80 port
-- Chunk-boundary safe for BOTH needles: complete matches are replaced FIRST and only then a
-- partial trailing prefix is held back for the next chunk. Computing the hold-back on the raw
-- data would split a complete match ending at a chunk boundary, because the quoted needle
-- starts AND ends with a double quote — its final quote would be held back as a possible
-- start of the next match and the match would go unrewritten.
local NEEDLE = "http://localhost/"
local NEEDLE_Q = '"http://localhost"'

function baseurl_filter(r)
    local host = r.headers_in["Host"]
    local ctype = r.content_type or r.headers_out["Content-Type"] or ""
    local rewrite = host ~= nil and host ~= "localhost" and not host:find("[^%w%.:%-%[%]]")
        and r.headers_out["Content-Encoding"] == nil
        and (ctype:find("^application/json") or ctype:find("^text/html"))
    if not rewrite then
        coroutine.yield()
        while bucket do coroutine.yield(bucket) end
        return
    end
    local replacement = "http://" .. host .. "/"
    local replacement_q = '"http://' .. host .. '"'
    r.headers_out["Content-Length"] = nil -- length changes
    coroutine.yield()
    local carry = ""
    while bucket do
        local data = carry .. bucket
        -- Replace complete matches before holding back a partial suffix (see header comment).
        data = data:gsub(NEEDLE, function() return replacement end)
        data = data:gsub(NEEDLE_Q, function() return replacement_q end)
        -- hold back a possible partial needle at the end of this chunk
        local keep = 0
        for n = math.max(#NEEDLE, #NEEDLE_Q) - 1, 1, -1 do
            if data:sub(-n) == NEEDLE:sub(1, n) or data:sub(-n) == NEEDLE_Q:sub(1, n) then
                keep = n break
            end
        end
        carry = keep > 0 and data:sub(-keep) or ""
        local body = keep > 0 and data:sub(1, #data - keep) or data
        coroutine.yield(body)
    end
    if carry ~= "" then coroutine.yield(carry) end
end
