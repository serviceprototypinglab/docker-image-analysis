# Produces a visual inheritance and layering tree for docker images

if [ -z $1 ]
then
	echo "Syntax: $0 <containerimagename> [hubcheck]" >&2
	exit 1
fi

jq --version >/dev/null 2>/dev/null
hasjq=$?
shuf --version >/dev/null 2>/dev/null
hasshuf=$?
docker version >/dev/null 2>/dev/null
hasdocker=$?
if [ $hasjq != 0 -o $hasshuf != 0 -o $hasdocker != 0 ]
then
	echo "Check obligatory dependencies: jq $hasjq shuf $hasshuf docker $hasdocker" >&2
	exit 1
fi
dot -V >/dev/null 2>/dev/null
hasdot=$?
clair-scanner -h >/dev/null 2>/dev/null
hasclair=$?
if [ $hasdot != 0 -o $hasclair != 0 ]
then
	echo "Check optional dependencies: dot $hasdot clair-scanner $hasclair" >&2
fi

imgname=$1
hubcheck=$2

id=`docker images --format "{{.ID}}" $imgname | head -1`
if [ -z $id ]
then
	echo "(Image not found; try pulling)"
	docker pull $imgname
	if [ $? != 0 ]
	then
		echo "Pull failed!" >&2
		exit 1
	fi
	id=`docker images --format "{{.ID}}" $imgname | head -1`
fi
echo "→ ID: $id"

s="digraph docker {"
s="$s\nranksep=0.1;"

oldid=""
for id in `docker history $id | grep -v IMAGE | awk '{print $1}'`; do
	tag=""
	xid=$id
	if [ $id != "<missing>" ]
	then
		tag=`docker inspect $id | jq ".[0].RepoTags[0]" | tr -d "\""`

		recenttagcolor="#E06060"
		recenttaglabel="$tag (unknown status)"
		if [ "$tag" != "null" -a "$hubcheck" = "hubcheck" ]
		then
			recenttagcolor="#E060E0"
			recenttaglabel="$tag (up-to-date)"
			digest=`docker inspect $id | jq ".[0].RepoDigests[0]"`
			digest=`echo $digest | cut -d "@" -f 2 | tr -d '"'`
			echo "($digest)"
			name=$imgname
			echo $name | grep -q "/"
			if [ $? != 0 ]
			then
				name="library/$name"
			fi
			wget -q https://hub.docker.com/v2/repositories/$name/tags?page_size=1000 -O- | jq ".results[].images[].digest" | grep -q $digest
			if [ $? = 1 ]
			then
				recenttagcolor="#B020B0"
				recenttaglabel="$tag (outdated)"
			fi

			if [ $hasclair = 0 ]
			then
				clair-scanner $id >/dev/null
				if [ $? = 1 ]
				then
					recenttaglabel="$recenttaglabel (vulnerable!)"
				else
					recenttaglabel="$recenttaglabel (secure)"
				fi
			fi
		fi
	else
		id=missing`shuf -i 100000-999999 -n 1`
		tag=null
	fi
	echo "* $id $tag"
	if [ ! -z $oldid ]
	then
		s="$s\nx$oldid -> x$id;"
	fi
	if [ "$tag" != "null" ]
	then
		s="$s\nx$id [color=\"$recenttagcolor\",label=\"$recenttaglabel\",style=filled];"
	else
		s="$s\nx$id [label=\"$id\"];"
	fi
	if [ "$xid" = "<missing>" ]
	then
		s="$s\nx$id [color=\"#E0E060\",label=\"$xid\",style=filled];"
	fi
	oldid=$id
done

s="$s\n}"

echo $s > docker.dot
if [ $hasdot = 0 ]
then
	dot -Tpng docker.dot > docker.png
fi
