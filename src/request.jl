module WebRequests

export request, clear, Result

include("./common.jl")
using .WebUtils: HTTPMethod, GET, POST
using LibCURL


struct Result
    code::Int64
    data::Union{Vector{UInt8}, Nothing}

    function Result(status, data)
        data = length(data) > 0 ? data : nothing
        new(status, data)
    end
end

mutable struct VectorWrapper
    data::Vector{UInt8}
end

# Multi interface is not currently used
function request(
    url::AbstractString,
    method::HTTPMethod=GET,
    payload::Union{AbstractString, Nothing}=nothing,
    readpost::Bool=false
)::Result
    curl = curl_easy_init()
    output = VectorWrapper([])

    curl_easy_setopt(curl, CURLOPT_URL, url)
    curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1)
    if method == POST && !isnothing(payload)
        curl_easy_setopt(curl, CURLOPT_POSTFIELDS, payload)
        curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, length(payload))
    end
    if method == GET || readpost
        curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, c_curl_write_cb)
        curl_easy_setopt(curl, CURLOPT_WRITEDATA, pointer_from_objref(output))
    end

    res = curl_easy_perform(curl)
    code = Ref{Clong}(0)
    curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, code)
    curl_easy_cleanup(curl)
    res != CURLE_OK && error(curl_easy_strerror(res))

    Result(code[], output.data)
end

function clear()
    curl_global_cleanup()
end

function curl_write_cb(curlbuf::Ptr{Cvoid}, size::Csize_t, nmemb::Csize_t, outptr::Ptr{Cvoid})
    realsize = size * nmemb
    w = unsafe_load(Ptr{VectorWrapper}(outptr))
    prevlen = length(w.data)
    resize!(w.data, prevlen+realsize)
    
    ccall(:memcpy, Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}, UInt64),
                                pointer(w.data)+prevlen, curlbuf, realsize)
    realsize::Csize_t
end

c_curl_write_cb = @cfunction(curl_write_cb, Csize_t, (Ptr{Cvoid}, Csize_t, Csize_t, Ptr{Cvoid}))

end