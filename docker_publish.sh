docker build -t elasticsearch:local .
docker tag elasticsearch:local physhi/futarist-mix:kib
docker push physhi/futarist-mix:kib