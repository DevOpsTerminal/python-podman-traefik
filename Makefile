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
