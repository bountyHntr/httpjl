include("./src/common.jl")
include("./src/server.jl")

using .WebServers
using .WebUtils


function defaultresp()
    headers = Dict(
        "Server" => "Apache",
        "Date" => "Wed, 31 Jan 2024",
        "Content-type" => "text/html; charset=utf-8",
        "Content-Length" => 13,
    )
    HTTPResponse("HTTP/1.1", "OK", 200, "Hello, world!", headers)
end


const DEFAULT_RESPONSE = String(defaultresp())

function okhandler(conn, req)
    req = HTTPRequest(req)
    @debug "request: \n$req"
    write(conn, DEFAULT_RESPONSE)
end


ws = WebServer(handler=okhandler)
run!(ws)
