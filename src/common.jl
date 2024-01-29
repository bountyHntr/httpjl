module WebUtils

export HTTPRequest, HTTPResponse


@enum HTTPMethod::UInt8 GET POST

function httpmethod(method::AbstractString)
    if method == "GET"
        return GET
    end
    return POST
end

function Base.show(io::IO, method::HTTPMethod)
    print(io, Symbol(method))
end


struct HTTPRequest
    method::HTTPMethod
    target::String
    version::String
    body::String
    headers::Dict{String, Any}
end

function HTTPRequest(data::AbstractString)
    lines = split(data, ['\n', '\r'], keepempty=false)
    method, target, version = split(lines[1], " ") .|> (httpmethod ∘ String, String, String)
    length(lines) == 1 && return HTTPRequest(method, target, version, "", Dict())

    i = 0; headers = Dict(); body = ""
    for outer i = 2:length(lines) 
        lines[i] == "" && break
        key, value = split(lines[i], ": ") .|> (String, String)
        headers[key] = value
    end
    i != length(lines) && (body = join(lines[i+1:end], "\n"))
    HTTPRequest(method, target, version, body, headers)
end

function HTTPRequest(data::Vector{UInt8})
    HTTPRequest(String(data))
end

function Base.show(io::IO, request::HTTPRequest)
    write(io, "$(request.method) $(request.target) $(request.version)")
    for (key, value) in request.headers
        write(io, "\n$key: $value")
    end
    request.body != "" && write(io, "\n\n", request.body)
end


struct HTTPResponse
    version::String
    status::String
    code::Int
    body::String
    headers::Dict{String, Any}
end

function Base.show(io::IO, response::HTTPResponse)
    write(io, "$(response.version) $(response.code) $(response.status)")
    for (key, value) in response.headers
        write(io, "\n$key: $value")
    end
    response.body != "" && write(io, "\n\n", response.body)
end

function String(response::HTTPResponse)
    io = IOBuffer()
    show(io, response)
    String(take!(io))
end

end