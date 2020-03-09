module Mewtwo

include("Model.jl")
using .Model; export Model

include("Mapper.jl")
using .Mapper; export Mapper

include("Service.jl")
using .Service; export Service

include("Resource.jl")
using .Resource; export Resource

include("Client.jl")
using .Client; export Client

function init()
    Mapper.init()
    Service.init()
    Resource.init()
end

function run()
    t = time()
    println("starting Mewtwo service")
    init()
    println(raw"""
    __  __________       _________       ______ 
   /  |/  / ____/ |     / /_  __/ |     / / __ \
  / /|_/ / __/  | | /| / / / /  | | /| / / / / /
 / /  / / /___  | |/ |/ / / /   | |/ |/ / /_/ / 
/_/  /_/_____/  |__/|__/ /_/    |__/|__/\____/  
""")
    println("started Mewtwo service in $(round(time() - t, digits=2)) seconds")
    Resource.run()
end

end # module
