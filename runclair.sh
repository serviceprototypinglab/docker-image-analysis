# Runs the clair docker image security scanner in containerised form

docker pull postgres:9.6 quay.io/coreos/clair:latest

if [ ! -f clair_config/config.yaml ]
then
	mkdir $PWD/clair_config
	curl -L https://raw.githubusercontent.com/coreos/clair/master/config.yaml.sample -o $PWD/clair_config/config.yaml
fi
docker run -d -e POSTGRES_PASSWORD="" -p 5432:5432 postgres:9.6
for i in `seq 10`; do echo -n zZzZzZ; sleep 1; done
docker run --net=host -ti -p 6060-6061:6060-6061 -v $PWD/clair_config:/config quay.io/coreos/clair:latest -config=/config/config.yaml
