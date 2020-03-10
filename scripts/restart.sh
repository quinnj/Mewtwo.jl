git pull origin master
docker build . -t quinnj/mewtwo
docker container stop $(docker container ls –aq)
docker container rm $(docker container ls –aq)
nohup docker run -p 0.0.0.0:8081:8081/tcp -p 0.0.0.0:8082:8082/tcp quinnj/mewtwo > mewtwo.log 2>&1 &