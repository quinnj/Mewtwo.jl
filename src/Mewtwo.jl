module Mewtwo

include("Mode.jl")
using .Model

include("Mapper.jl")
using .Mapper

include("Service.jl")
using .Service

include("Resource.jl")
using .Resource

function init()
    # Mapper.init()
end

function run()
    init()
    Resource.run()
end

end # module
