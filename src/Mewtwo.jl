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
    # Mapper.init()
end

function run()
    init()
    Resource.run()
end

end # module
