FROM julia:buster

ENV MEWTWO=/home/mewtwo

RUN mkdir $MEWTWO
WORKDIR $MEWTWO
ENV MEWTWO_DOCKER_VERSION 1
ADD . $MEWTWO
ENV JULIA_PROJECT @.

# instantiate project
RUN julia -e 'using Pkg; Pkg.instantiate(); using Mewtwo'

ENTRYPOINT ["julia", "-e", "using Mewtwo; Mewtwo.run()"]
