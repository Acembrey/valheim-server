mkdir -p ~/valheim-server/config ~/valheim-server/data

docker run -d \
  --name valheim-server \
  --cap-add=sys_nice \
  --stop-timeout 120 \
  -p 2456-2457:2456-2457/udp \
  -v ~/valheim-server/config:/config \
  -v ~/valheim-server/data:/opt/valheim \
  -e SERVER_NAME="My Server" \
  -e WORLD_NAME="Midgard" \
  -e SERVER_PASS="changeme123" \
  -e SERVER_PUBLIC="true" \
  ghcr.io/community-valheim-tools/valheim-server