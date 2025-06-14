up:
	podman-compose -f docker-compose.yml up -d

down:
	podman-compose -f docker-compose.yml down

logs:
	podman-compose -f docker-compose.yml logs

test:
	ansible-playbook ansible/test.yml

ps:
	podman ps -a

restart:
	podman-compose -f docker-compose.yml down && podman-compose -f docker-compose.yml up -d

up-prod:
	podman-compose -f docker-compose.prod.yml up -d

down-prod:
	podman-compose -f docker-compose.prod.yml down

logs-prod:
	podman-compose -f docker-compose.prod.yml logs
