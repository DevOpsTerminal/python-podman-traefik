# Production Deployment Guide

This guide explains how to deploy the application stack in a production environment using Traefik as a reverse proxy with Let's Encrypt SSL certificates.

## Prerequisites

1. A server with Docker and Docker Compose installed
2. A domain name (e.g., `devopsterminal.com`) with DNS access
3. Ports 80 and 443 open in your firewall

## Setup Instructions

1. **Update DNS Records**
   Create the following DNS A records pointing to your server's IP address:
   - `devopsterminal.com`
   - `projekt1.devopsterminal.com`
   - `projekt2.devopsterminal.com`
   - `traefik.devopsterminal.com`

2. **Update Configuration**
   - Update the email address in `docker-compose.prod.yml` (search for `admin@devopsterminal.com`)
   - Update the domain names if you're using a different domain than `devopsterminal.com`
   - Change the default credentials for the Traefik dashboard (see below)

3. **Change Default Credentials**
   The default credentials for the Traefik dashboard are:
   - Username: `admin`
   - Password: `changeme`

   To generate a new password hash:
   ```bash
   echo $(htpasswd -nb admin your-new-password) | sed -e s/\\$/\\$\$/g
   ```
   Update the `traefik.http.middlewares.auth.basicauth.users` label in `docker-compose.prod.yml` with the new hash.

4. **Deploy the Stack**
   ```bash
   # Create the network if it doesn't exist
   podman network create prod_network
   
   # Create required directories
   mkdir -p letsencrypt traefik
   chmod 600 letsencrypt
   
   # Start the stack
   podman-compose -f docker-compose.prod.yml up -d
   ```

## Accessing Services

- **Project 1**: https://projekt1.devopsterminal.com
- **Project 2**: https://projekt2.devopsterminal.com
- **Traefik Dashboard**: https://traefik.devopsterminal.com (requires authentication)

## Monitoring

Traefik logs are available in the container and also mounted to:
- `./traefik/traefik.log` - Traefik service logs
- `./traefik/access.log` - Access logs

## Maintenance

### View Logs
```bash
podman-compose -f docker-compose.prod.yml logs -f
```

### Update Containers
```bash
podman-compose -f docker-compose.prod.yml pull
podman-compose -f docker-compose.prod.yml up -d --force-recreate
```

### Backup and Restore

**Backup Let's Encrypt certificates:**
```bash
tar -czvf letsencrypt_backup_$(date +%Y%m%d).tar.gz letsencrypt/
```

**Restore from backup:**
```bash
tar -xzvf letsencrypt_backup_YYYYMMDD.tar.gz
```

## Security Considerations

1. **Firewall**: Ensure only necessary ports (80, 443) are open to the internet
2. **Updates**: Regularly update your containers and host system
3. **Monitoring**: Set up monitoring for your services
4. **Backups**: Regularly back up your Let's Encrypt certificates and application data
