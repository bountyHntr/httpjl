module WebClients

export request, clear

include("./common.jl")
using .WebUtils
using LibCURL


# Multi interface is not currently used
function request(
    url::AbstractString,
    method::HTTPMethod=GET,
    payload::Union{AbstractString, Nothing}=nothing,
    readpost::Bool=false
)
    curl = curl_easy_init()
    output::Vector{UInt8} = []

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
    curl_easy_cleanup(curl)
    res != CURLE_OK && error(curl_easy_strerror(res))
    length(output) > 0 ? output : nothing
end

function clear()
    curl_global_cleanup()
end

function curl_write_cb(curlbuf::Ptr{Cvoid}, size::Csize_t, nmemb::Csize_t, outptr::Ptr{Cvoid})
    realsize = size * nmemb
    outlen = unsafe_load(convert(Ptr{Int}, outptr+8))
    outbegin = convert(Ptr{UInt8}, outptr + 40)

    output = unsafe_wrap(Array, outbegin, outlen)
    resize!(output, outlen+realsize)
    
    ccall(:memcpy, Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}, UInt64), outbegin+outlen, curlbuf, realsize)
    realsize::Csize_t
end

c_curl_write_cb = @cfunction(curl_write_cb, Csize_t, (Ptr{Cvoid}, Csize_t, Csize_t, Ptr{Cvoid}))

end