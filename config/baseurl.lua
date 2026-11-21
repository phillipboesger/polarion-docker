-- Rewrites Polarion's fixed base URL (http://localhost/) to the host:port the client really
-- used (Host header), so the image works on any published port without extra parameters.
-- Only JSON and HTML answers are touched; encoded (gzip) answers and static assets pass through.
local NEEDLE = "http://localhost/"

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
    r.headers_out["Content-Length"] = nil -- length changes
    coroutine.yield()
    local carry = ""
    while bucket do
        local data = carry .. bucket
        -- hold back a possible partial needle at the end of this chunk
        local keep = 0
        for n = #NEEDLE - 1, 1, -1 do
            if data:sub(-n) == NEEDLE:sub(1, n) then keep = n break end
        end
        carry = keep > 0 and data:sub(-keep) or ""
        local body = keep > 0 and data:sub(1, #data - keep) or data
        coroutine.yield((body:gsub(NEEDLE, function() return replacement end)))
    end
    if carry ~= "" then coroutine.yield(carry) end
end
