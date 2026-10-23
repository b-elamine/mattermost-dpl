#!/bin/bash
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
docker compose -f ~/compose/docker-compose.yml exec -T postgres pg_dump -U mmuser mattermost > ~/backups/mattermost_$TIMESTAMP.sql
find ~/backups -name "mattermost_*.sql" -mtime +7 -delete