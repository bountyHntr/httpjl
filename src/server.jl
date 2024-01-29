module WebServers

export WebServer, run!

using Sockets
using Logging
using Base.Threads


Base.exit_on_sigint(false)

const SCHEDULER_TRIGGER_TIMEOUT::Real = 50 // 1000 # 50ms


mutable struct WebServer
    host::IPAddr
    port::Int
    tcp::Sockets.TCPServer
    connections::Channel{TCPSocket}
    workers::Vector{Task}
    handler::Function

    function WebServer(;
        host::IPAddr=Sockets.localhost,
        port::Int=8888,
        handler::Function=echohandler,
        workers::Int=4
    )
        workers = min(nthreads(), workers)
        connections = Channel{TCPSocket}(workers)
        worker_threads = Vector{Task}(undef, workers)
        new(host, port, listen(host, port), connections, worker_threads, handler)
    end
end

function run!(server::WebServer)
    @info "Run web server: $(server.host):$(server.port); workers $(length(server.workers))"

    for i = 1:length(server.workers)
        server.workers[i] = @spawn runworker!(server, i)        
    end

     try
        # изначально было вот так:
        # while true put!(connections, accept(server)) end
        # однако вследствие https://github.com/JuliaLang/julia/issues/45055
        # graceful shutdown неработает, поэтому пришлось немного извернуться
        # может иметь небольшой кост с точки зрения производительности,
        # так как постоянно тригерит планировщик
        @sync begin
            @async while true put!(server.connections, accept(server.tcp)) end
            while true sleep(SCHEDULER_TRIGGER_TIMEOUT) end
        end
    catch e
        if isa(e, InterruptException) || isa(e, Base.IOError) && e.code == -103 # ECONNABORTED
            @debug "caught error $e"
        else
            @error "server error $e"
            rethrow(e)
        end
    finally
        close(server)
    end
    @info "server stopped"
end

function Base.close(server::WebServer)
    close(server.connections)
    close(server.tcp)
    map(wait, server.workers)
end


function runworker!(server::WebServer, id::Int)
    try
        @sync for conn in server.connections
            addr, port = getpeername(conn)
            @debug "worker $id: get connection for $addr:$port"
            println(typeof(conn))
            @async handlereq(conn, server.handler)
        end
    catch e
        @debug "worker $id died: $e"
        isa(e, InterruptException) && close(server)
    end
end

function handlereq(conn::TCPSocket, handler::Function)
    try
        data = readavailable(conn)
        handler(conn, data)
    finally
        addr, port = getpeername(conn)
        @debug "close connection $addr:$port"
        close(conn)
    end
end

function echohandler(conn, req)
    write(conn, req)
end

end