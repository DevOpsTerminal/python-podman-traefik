# Tutorial Deployment Flask z Podman + Traefik

Jak używać Traefik jako zaawansowanego reverse proxy Jak konfigurować service discovery Jak używać labels w kontenerach Jak monitorować aplikacje przez dashboard

## Czego się nauczysz?
- Jak używać Traefik jako zaawansowanego reverse proxy
- Jak konfigurować service discovery
- Jak używać labels w kontenerach
- Jak monitorować aplikacje przez dashboard

**⚠️ Uwaga**: Ten tutorial jest bardziej zaawansowany niż Caddy!

---

## Krok 1: Przygotowanie środowiska

### Sprawdzenie narzędzi
```bash
podman info
podman-compose --version
docker compose version 
```

### Instalacja podstawowych narzędzi na debian, Ubuntu
```bash
# Zaktualizuj system 
sudo apt update && sudo apt upgrade -y

# Zainstaluj Podman
sudo apt install podman -y

# Zainstaluj podman-compose (potrzebne do docker-compose.yml)
pip3 install podman-compose

# Lub alternatywnie docker-compose
sudo apt install docker-compose-plugin -y
```

### Instalacja podstawowych narzędzi na Fedora

```bash
# Zaktualizuj system
sudo dnf upgrade --refresh -y

# Zainstaluj Podman
sudo dnf install podman -y

# Zainstaluj podman-compose (potrzebne do docker-compose.yml)
pip3 install --user podman-compose

# Upewnij się, że ~/.local/bin jest w PATH (jeśli nie, dodaj do ~/.bashrc lub ~/.zshrc)
export PATH=$HOME/.local/bin:$PATH

# (Opcjonalnie) Zainstaluj docker-compose-plugin z Dockerem
sudo dnf install dnf-plugins-core -y
sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
sudo dnf install docker-ce docker-ce-cli containerd.io docker-compose-plugin -y

# (Opcjonalnie) Włącz Docker jeśli został zainstalowany
sudo systemctl enable --now docker
```

---



## Krok 2: Struktura projektu

```bash
mkdir -p ~/traefik-setup/{sklep,blog,api,portfolio}
cd ~/traefik-setup
```

### Główny docker-compose.yml
```bash
nano docker-compose.yml
```

```yaml
version: '3.8'

networks:
  web:
    driver: bridge

services:
  # Traefik - reverse proxy z dashboard
  traefik:
    image: traefik:v3.0
    container_name: traefik
    restart: unless-stopped
    command:
      # Włącz API i dashboard
      - "--api.insecure=true"
      - "--api.dashboard=true"
      
      # Konfiguracja dostawców
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--providers.docker.network=web"
      
      # Entrypoints (porty wejściowe)
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      
      # SSL z Let's Encrypt
      - "--certificatesresolvers.myresolver.acme.httpchallenge=true"
      - "--certificatesresolvers.myresolver.acme.httpchallenge.entrypoint=web"
      - "--certificatesresolvers.myresolver.acme.email=twoj@email.com"
      - "--certificatesresolvers.myresolver.acme.storage=/letsencrypt/acme.json"
      
      # Przekierowanie HTTP na HTTPS
      - "--entrypoints.web.http.redirections.entrypoint.to=websecure"
      - "--entrypoints.web.http.redirections.entrypoint.scheme=https"
    
    ports:
      - "80:80"
      - "443:443"
      - "8082:8080"  # Dashboard
    
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
      - "./letsencrypt:/letsencrypt"
    
    networks:
      - web
    
    labels:
      - "traefik.enable=true"
      # Dashboard
      - "traefik.http.routers.dashboard.rule=Host(`dashboard.twoja-domena.pl`)"
      - "traefik.http.routers.dashboard.entrypoints=websecure"
      - "traefik.http.routers.dashboard.tls.certresolver=myresolver"

  # Sklep Flask App
  sklep:
    build: ./sklep
    container_name: sklep
    restart: unless-stopped
    networks:
      - web
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.sklep.rule=Host(`sklep.twoja-domena.pl`)"
      - "traefik.http.routers.sklep.entrypoints=websecure"
      - "traefik.http.routers.sklep.tls.certresolver=myresolver"
      - "traefik.http.services.sklep.loadbalancer.server.port=5000"

  # Blog Flask App
  blog:
    build: ./blog
    container_name: blog
    restart: unless-stopped
    networks:
      - web
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.blog.rule=Host(`blog.twoja-domena.pl`)"
      - "traefik.http.routers.blog.entrypoints=websecure"
      - "traefik.http.routers.blog.tls.certresolver=myresolver"
      - "traefik.http.services.blog.loadbalancer.server.port=5000"

  # API Flask App
  api:
    build: ./api
    container_name: api
    restart: unless-stopped
    networks:
      - web
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.api.rule=Host(`api.twoja-domena.pl`)"
      - "traefik.http.routers.api.entrypoints=websecure"
      - "traefik.http.routers.api.tls.certresolver=myresolver"
      - "traefik.http.services.api.loadbalancer.server.port=5000"
      # CORS dla API
      - "traefik.http.routers.api.middlewares=cors"
      - "traefik.http.middlewares.cors.headers.accesscontrolallowmethods=GET,OPTIONS,PUT,POST,DELETE"
      - "traefik.http.middlewares.cors.headers.accesscontrolalloworigin=*"
      - "traefik.http.middlewares.cors.headers.accesscontrolmaxage=100"
      - "traefik.http.middlewares.cors.headers.addvaryheader=true"

  # Portfolio Flask App
  portfolio:
    build: ./portfolio
    container_name: portfolio
    restart: unless-stopped
    networks:
      - web
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.portfolio.rule=Host(`portfolio.twoja-domena.pl`)"
      - "traefik.http.routers.portfolio.entrypoints=websecure"
      - "traefik.http.routers.portfolio.tls.certresolver=myresolver"
      - "traefik.http.services.portfolio.loadbalancer.server.port=5000"
```

---

## Krok 3: Przygotowanie aplikacji Flask

### Przykład aplikacji (sklep/app.py)
```python
from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/')
def home():
    return jsonify({
        "message": "Witaj w moim sklepie!",
        "version": "1.0",
        "endpoints": ["/", "/produkty", "/kategorie"]
    })

@app.route('/produkty')
def produkty():
    return jsonify({
        "produkty": [
            {"id": 1, "nazwa": "Laptop", "cena": 2999},
            {"id": 2, "nazwa": "Telefon", "cena": 1299}
        ]
    })

@app.route('/kategorie')
def kategorie():
    return jsonify({
        "kategorie": ["Elektronika", "Ubrania", "Książki"]
    })

if __name__ == '__main__':
    app.run(debug=True)
```

### requirements.txt (dla każdej aplikacji)
```
Flask==2.3.3
gunicorn==21.2.0
flask-cors==4.0.0
```

### Dockerfile (ten sam dla wszystkich)
```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Kopiuj requirements i zainstaluj zależności
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Kopiuj aplikację
COPY . .

EXPOSE 5000

# Używaj Gunicorn do produkcji
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "app:app"]
```

---

## Krok 4: Konfiguracja dla testów bez domeny

### docker-compose-local.yml (do testów na IP)
```yaml
version: '3.8'

networks:
  web:
    driver: bridge

services:
  traefik:
    image: traefik:v3.0
    container_name: traefik
    restart: unless-stopped
    command:
      - "--api.insecure=true"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
    ports:
      - "80:80"
      - "8082:8080"
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
    networks:
      - web

  sklep:
    build: ./sklep
    container_name: sklep
    networks:
      - web
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.sklep.rule=PathPrefix(`/sklep`)"
      - "traefik.http.services.sklep.loadbalancer.server.port=5000"

  blog:
    build: ./blog
    container_name: blog
    networks:
      - web
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.blog.rule=PathPrefix(`/blog`)"
      - "traefik.http.services.blog.loadbalancer.server.port=5000"

  api:
    build: ./api
    container_name: api
    networks:
      - web
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.api.rule=PathPrefix(`/api`)"
      - "traefik.http.services.api.loadbalancer.server.port=5000"

  portfolio:
    build: ./portfolio
    container_name: portfolio
    networks:
      - web
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.portfolio.rule=PathPrefix(`/portfolio`)"
      - "traefik.http.services.portfolio.loadbalancer.server.port=5000"
```

---

## Krok 5: Testowanie środowiska (Ansible)

Do automatycznych testów środowiska możesz użyć playbooka:

```bash
ansible-playbook ansible/test.yml
```

Testuje on:
- dostępność dashboardu Traefika (domyślnie na http://localhost:8083/dashboard/ lub http://localhost:8081/dashboard/)
- dostępność usług projekt1 i projekt2 przez Traefik
- nagłówek Server dla dashboardu Traefika

#### Przykład Makefile

```Makefile
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
```

## Krok 6: Debugowanie

- Jeśli dashboard nie działa na `/dashboard/`, sprawdź porty i ścieżki w traefik.yml.
- Sprawdź logi Traefika: `make logs`
- Sprawdź, czy backendy odpowiadają na `/projekt1` i `/projekt2`.

---

## Krok 7: Automatyzacja i zarządzanie

### Skrypt zarządzania
```bash
nano ~/manage-traefik.sh
```

```bash
#!/bin/bash

case $1 in
  start)
    echo "🚀 Uruchamianie wszystkich serwisów..."
    cd ~/traefik-setup
    docker-compose up -d
    ;;
  stop)
    echo "🛑 Zatrzymywanie wszystkich serwisów..."
    cd ~/traefik-setup
    docker-compose down
    ;;
  restart)
    echo "🔄 Restart wszystkich serwisów..."
    cd ~/traefik-setup
    docker-compose restart
    ;;
  rebuild)
    echo "🔨 Rebuild aplikacji: $2"
    cd ~/traefik-setup
    docker-compose build $2
    docker-compose up -d $2
    ;;
  logs)
    echo "📋 Logi serwisu: $2"
    cd ~/traefik-setup
    docker-compose logs -f $2
    ;;
  status)
    echo "📊 Status wszystkich serwisów:"
    cd ~/traefik-setup
    docker-compose ps
    ;;
  dashboard)
    echo "🖥️ Dashboard dostępny na:"
    echo "http://$(curl -s ifconfig.me):8082"
    ;;
  *)
    echo "Użycie: $0 {start|stop|restart|rebuild|logs|status|dashboard}"
    echo "Przykłady:"
    echo "  $0 start"
    echo "  $0 rebuild sklep"
    echo "  $0 logs api"
    ;;
esac
```

```bash
chmod +x ~/manage-traefik.sh
```

### Użycie skryptu
```bash
./manage-traefik.sh start       # Uruchom wszystko
./manage-traefik.sh rebuild sklep  # Przebuduj sklep
./manage-traefik.sh logs api    # Zobacz logi API
./manage-traefik.sh dashboard   # Pokaż URL dashboard
```

---

## Krok 8: Zaawansowane funkcje Traefik

### Load Balancing
```yaml
# W docker-compose.yml możesz skalować serwisy:
sklep:
  # ... existing config
  deploy:
    replicas: 3
  labels:
    # Traefik automatycznie load-balancuje między replikami
    - "traefik.http.services.sklep.loadbalancer.server.port=5000"
```

### Rate Limiting
```yaml
# Dodaj middleware do limitowania requestów
labels:
  - "traefik.http.routers.api.middlewares=api-ratelimit"
  - "traefik.http.middlewares.api-ratelimit.ratelimit.burst=100"
  - "traefik.http.middlewares.api-ratelimit.ratelimit.average=50"
```

### Basic Auth
```bash
# Wygeneruj hasło
sudo apt install apache2-utils
htpasswd -nb admin admin123
# Output: admin:$apr1$ruca84Hq$mbjdMZBAG.KWn7vfN/SNK/
```

```yaml
labels:
  - "traefik.http.routers.dashboard.middlewares=auth"
  - "traefik.http.middlewares.auth.basicauth.users=admin:$$apr1$$ruca84Hq$$mbjdMZBAG.KWn7vfN/SNK/"
```

---

## Krok 9: Backup i Recovery

### Skrypt backup
```bash
nano ~/backup-traefik.sh
```

```bash
#!/bin/bash

BACKUP_DIR=~/backups/$(date +%Y%m%d_%H%M%S)
mkdir -p $BACKUP_DIR

echo "📦 Tworzenie backup..."

# Backup konfiguracji
cp -r ~/traefik-setup $BACKUP_DIR/

# Backup certyfikatów SSL
cp -r ~/traefik-setup/letsencrypt $BACKUP_DIR/ 2>/dev/null || true

# Backup volumes (jeśli masz dane)
docker-compose -f ~/traefik-setup/docker-compose.yml exec sklep tar -czf /tmp/sklep-data.tar.gz /app/data 2>/dev/null || true

echo "✅ Backup zapisany w: $BACKUP_DIR"
```

---

## Krok 10: Troubleshooting

### Częste problemy

#### Traefik nie widzi kontenerów
```bash
# Sprawdź sieć
docker network ls
docker network inspect traefik-setup_web

# Sprawdź labels
docker inspect sklep | grep traefik
```

#### Certyfikaty SSL nie działają
```bash
# Sprawdź logi Traefika: `make logs`
# Sprawdź plik certyfikatów
ls -la letsencrypt/
```

#### Dashboard nie działa
```bash
# Sprawdź czy port 8082 jest otwarty
sudo netstat -tlnp | grep 8082

# Sprawdź konfigurację
docker-compose exec traefik traefik version
```

### Przydatne komendy debugowania
```bash
# Zobacz wszystkie routery
curl -s http://localhost:8082/api/http/routers | jq

# Zobacz wszystkie serwisy
curl -s http://localhost:8082/api/http/services | jq

# Status Traefik
curl -s http://localhost:8082/api/overview
```

---

## 📊 Porównanie: Traefik vs Caddy

| Funkcja | Traefik | Caddy |
|---------|---------|-------|
| **Konfiguracja** | Labels w YAML | Prosty Caddyfile |
| **Dashboard** | ✅ Pełny dashboard | ❌ Brak |
| **Load Balancing** | ✅ Zaawansowany | ⚠️ Podstawowy |
| **Middleware** | ✅ Bogaty zestaw | ⚠️ Ograniczony |
| **Learning Curve** | 🔴 Stroma | 🟢 Płaska |
| **Service Discovery** | ✅ Automatyczny | ❌ Manual |

---

## 🎯 Kiedy wybrać Traefik?

**Wybierz Traefik gdy:**
- Masz wiele mikrousług
- Potrzebujesz load balancing
- Chcesz dashboard do monitorowania
- Planujesz skalowanie poziome
- Potrzebujesz zaawansowane middleware

**Zostań z Caddy gdy:**
- Masz proste aplikacje (jak Twoje 4 projekty Flask)
- Chcesz szybko postawić serwer
- Nie potrzebujesz zaawansowanych funkcji
- Jesteś początkującym

---

## 🚀 Deployment produkcyjny z domeną

### Konfiguracja DNS
```bash
# Ustaw rekordy A w swoim DNS:
# sklep.twoja-domena.pl     → IP_SERWERA
# blog.twoja-domena.pl      → IP_SERWERA
# api.twoja-domena.pl       → IP_SERWERA
# portfolio.twoja-domena.pl → IP_SERWERA
# dashboard.twoja-domena.pl → IP_SERWERA
```

### Uruchomienie z pełną konfiguracją
```bash
cd ~/traefik-setup

# Zmień email w docker-compose.yml na swój
nano docker-compose.yml
# Znajdź: "--certificatesresolvers.myresolver.acme.email=twoj@email.com"

# Uruchom z pełną konfiguracją
docker-compose up -d

# Sprawdź logi SSL
docker-compose logs traefik | grep acme
```

### Test SSL
```bash
# Sprawdź czy certyfikaty zostały wydane
curl -I https://sklep.twoja-domena.pl
curl -I https://api.twoja-domena.pl

# Dashboard z SSL
open https://dashboard.twoja-domena.pl
```

---

## 📈 Monitoring i metryki

### Dodanie Prometheus + Grafana
```yaml
# Dodaj do docker-compose.yml:
  prometheus:
    image: prom/prometheus
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    networks:
      - web
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.prometheus.rule=Host(`prometheus.twoja-domena.pl`)"
      - "traefik.http.routers.prometheus.entrypoints=websecure"
      - "traefik.http.routers.prometheus.tls.certresolver=myresolver"

  grafana:
    image: grafana/grafana
    container_name: grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin123
    networks:
      - web
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.grafana.rule=Host(`grafana.twoja-domena.pl`)"
      - "traefik.http.routers.grafana.entrypoints=websecure"
      - "traefik.http.routers.grafana.tls.certresolver=myresolver"
```

### prometheus.yml
```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'traefik'
    static_configs:
      - targets: ['traefik:8082']
```

---

## 🔐 Bezpieczeństwo

### Firewall
```bash
sudo ufw allow ssh
sudo ufw allow 80
sudo ufw allow 443
sudo ufw enable
```

### Fail2ban dla Traefik
```bash
sudo apt install fail2ban

# Konfiguracja dla Traefik
sudo nano /etc/fail2ban/filter.d/traefik-auth.conf
```

```ini
[Definition]
failregex = ^<HOST> \- \S+ \[\] \"(GET|POST|HEAD).*\" 401
ignoreregex =
```

```bash
sudo nano /etc/fail2ban/jail.local
```

```ini
[traefik-auth]
enabled = true
port = http,https
filter = traefik-auth
logpath = /var/log/traefik/access.log
maxretry = 3
bantime = 3600
```

---

## 🔄 CI/CD z GitHub Actions

### .github/workflows/deploy.yml
```yaml
name: Deploy to VPS

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Deploy to server
      uses: appleboy/ssh-action@v0.1.7
      with:
        host: ${{ secrets.HOST }}
        username: ${{ secrets.USERNAME }}
        key: ${{ secrets.SSH_KEY }}
        script: |
          cd ~/traefik-setup
          git pull origin main
          docker-compose build sklep
          docker-compose up -d sklep
          echo "✅ Deployment completed!"
```

### Secrets w GitHub
```
HOST: IP_TWOJEGO_SERWERA
USERNAME: junior
SSH_KEY: (twój klucz prywatny SSH)
```

---

## 📱 Aplikacja mobilna do zarządzania

### Prosty monitoring script
```bash
nano ~/status-check.sh
```

```bash
#!/bin/bash

echo "🔍 Sprawdzanie statusu aplikacji..."

services=("sklep" "blog" "api" "portfolio" "traefik")
base_url="https://twoja-domena.pl"

for service in "${services[@]}"; do
    if [ "$service" = "traefik" ]; then
        url="https://dashboard.twoja-domena.pl"
    else
        url="https://$service.twoja-domena.pl"
    fi
    
    status=$(curl -s -o /dev/null -w "%{http_code}" "$url")
    
    if [ "$status" = "200" ]; then
        echo "✅ $service: OK"
    else
        echo "❌ $service: ERROR ($status)"
        # Restart kontenera
        cd ~/traefik-setup
        docker-compose restart $service
    fi
done

echo "📊 Zasoby serwera:"
echo "CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | awk -F'%' '{print $1}')%"
echo "RAM: $(free | grep Mem | awk '{printf("%.1f%%", $3/$2 * 100.0)}')"
echo "Dysk: $(df -h / | awk 'NR==2{print $5}')"
```

### Cron job dla monitoringu
```bash
crontab -e

# Dodaj:
*/5 * * * * ~/status-check.sh >> ~/monitoring.log 2>&1
```

---

## 🎓 Podsumowanie dla Juniora

### Co osiągnąłeś z Traefik:
✅ **Zaawansowany reverse proxy**  
✅ **Service discovery**  
✅ **Dashboard do monitorowania**  
✅ **Load balancing**  
✅ **Middleware (CORS, Auth, Rate limiting)**  
✅ **Automatyczne SSL**  
✅ **Metryki i monitoring**  

### Kompetencje DevOps które nabyłeś:
- **Docker/Podman** - konteneryzacja
- **Traefik** - advanced reverse proxy
- **YAML** - konfiguracja infrastructure as code
- **SSL/TLS** - zarządzanie certyfikatami
- **Monitoring** - Prometheus + Grafana
- **CI/CD** - GitHub Actions
- **Networking** - Docker networks
- **Security** - middleware, fail2ban

### Następne kroki:
1. **Kubernetes** - orkiestracja kontenerów
2. **Helm Charts** - pakiety Kubernetes
3. **ArgoCD** - GitOps deployment
4. **Service Mesh** - Istio/Linkerd
5. **Observability** - ELK Stack

---

## 💸 Koszt całego setup-u

| Komponent | Koszt/miesiąc |
|-----------|---------------|
| VPS Basic | 2 EUR |
| Domena | ~1 EUR |
| **Łącznie** | **~3 EUR** |

**Za cenę kawy masz:**
- Professional deployment setup
- Dashboard monitoring
- Automatic SSL
- Load balancing
- CI/CD ready environment

---

## 🆚 Ostateczne porównanie

### Traefik - 80 linii kodu, ale potężny!
```
✅ Enterprise-grade features
✅ Scalable architecture  
✅ Rich ecosystem
⚠️ Steep learning curve
⚠️ More complex setup
```

### Caddy - 30 linii kodu, ale prosty!
```
✅ Zero-config SSL
✅ Simple setup
✅ Perfect for small projects
⚠️ Limited advanced features
⚠️ Manual service discovery
```

**Verdict dla Juniora:**
- **Start z Caddy** - naucz się podstaw
- **Przejdź na Traefik** - gdy potrzebujesz więcej

**Oba są świetne! Wybór zależy od potrzeb projektu! 🚀**

---

## 🎉 Gratulacje!

Właśnie opanowałeś jeden z najpopularniejszych narzędzi DevOps! Traefik to standard w wielu firmach technologicznych.

**Jesteś gotowy na:**
- Mid-level DevOps positions
- Microservices architecture
- Cloud-native development
- Kubernetes orchestration

**Keep learning! 🚀**

---

## Bezpieczeństwo dashboardu Traefik w produkcji

Dashboard Traefika w środowisku produkcyjnym jest domyślnie zabezpieczony hasłem (basic auth):

- Dostęp do panelu jest możliwy tylko przez domenę `traefik.devopsterminal.com` po HTTPS.
- Do logowania wymagany jest login i hasło (domyślnie: `admin` / `changeme`).
- Hasło jest przechowywane jako hash bcrypt w labelu:
  ```yaml
  - "traefik.http.middlewares.auth.basicauth.users=admin:$$2y$$05$$5HXxP9X8wJqTgYz5jK5u8uJq5VZ5QkXJ5zQ9X8wJqTgYz5jK5u8uJ"
  ```
- Middleware `auth` jest przypisany tylko do dashboardu, nie do backendów.

### Jak zmienić hasło?
1. Wygeneruj nowy hash bcrypt (np. na https://bcrypt-generator.com/).
2. Podmień wartość labela w `docker-compose.prod.yml`:
   ```yaml
   - "traefik.http.middlewares.auth.basicauth.users=admin:<nowy_hash>"
   ```
3. Zrestartuj stack (`make restart-prod` lub przez systemd).

**Uwaga:**
- Nie udostępniaj dashboardu publicznie bez hasła!
- Możesz dodatkowo ograniczyć dostęp po adresie IP lub przez VPN, dodając kolejne middleware.
