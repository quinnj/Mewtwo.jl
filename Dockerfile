FROM julia:stretch

RUN apt-get update && apt-get install -y curl tar procps net-tools bzip2
RUN curl -L -o /usr/local/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v1.2.1/dumb-init_1.2.1_amd64
RUN chmod +x /usr/local/bin/dumb-init

ENV MEWTWO=/home/mewtwo

RUN mkdir $MEWTWO
WORKDIR $MEWTWO
ENV MEWTWO_DOCKER_VERSION 1
ADD . $MEWTWO
ENV JULIA_PROJECT @.

# instantiate project
RUN julia -e 'using Pkg; Pkg.instantiate(); using Mewtwo'

ENTRYPOINT ["/usr/local/bin/dumb-init", "julia", "-e", "using Mewtwo; Mewtwo.run()"]
