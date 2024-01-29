module WebClients

export request, clear

include("./common.jl")
using .WebUtils
using LibCURL


# Multi interface is not currently used
function request(
    url::AbstractString,
    method::HTTPMethod=GET,
    data::Union{AbstractString, Nothing}=nothing,
    readpost::Bool=false
)
    curl = curl_easy_init()

    curl_easy_setopt(curl, CURLOPT_URL, url)
    curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1)
    if method == POST && !isnothing(data)
        curl_easy_setopt(curl, CURLOPT_POSTFIELDS, data)
        curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, length(data))
    end
    if method == GET || readpost
        curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, c_curl_write_cb)
    end

    res = curl_easy_perform(curl)
    curl_easy_cleanup(curl)
    res != CURLE_OK && error(curl_easy_strerror(res))
    nothing
end

function clear()
    curl_global_cleanup()
end

function curl_write_cb(curlbuf::Ptr{Cvoid}, size::Csize_t, nmemb::Csize_t, p_ctxt::Ptr{Cvoid})
    realsize = size * nmemb
    data = Array{UInt8}(undef, realsize)
    ccall(:memcpy, Ptr{Cvoid}, (Ptr{Cvoid}, Ptr{Cvoid}, UInt64), data, curlbuf, realsize)
    println(String(data))
    realsize::Csize_t
end

c_curl_write_cb = @cfunction(curl_write_cb, Csize_t, (Ptr{Cvoid}, Csize_t, Csize_t, Ptr{Cvoid}))

end