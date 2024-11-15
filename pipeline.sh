docker build --tag launchpad:devel - < docker/build.dockerfile
docker run --rm --mount "type=bind,src=$PWD,dst=/tmp/launchpad" \
  -it launchpad:devel /tmp/launchpad/oss_build.sh