# Docker Deployment Guide for Ubuntu Server

## Prerequisites
- Ubuntu server (18.04 or later recommended)
- SSH access with sudo privileges
- Port 3000 (or your chosen port) available

## Step 1: Install Docker

### Update system packages
```bash
sudo apt-get update
sudo apt-get upgrade -y
```

### Install Docker
```bash
sudo apt-get install -y ca-certificates curl gnupg lsb-release

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

### Verify Docker installation
```bash
sudo docker --version
sudo docker run hello-world
```

### Add your user to docker group (optional, to run without sudo)
```bash
sudo usermod -aG docker $USER
newgrp docker
```

## Step 2: Install Docker Compose (if not using Docker Compose plugin)

If you installed Docker Compose plugin above, skip this step.

```bash
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
docker-compose --version
```

## Step 3: Transfer Project Files to Server

### Option A: Using Git (Recommended)
```bash
cd ~
git clone https://github.com/gsk-panda/Panovision.git panovision
cd panovision
```

### Option B: Using SCP
From your local machine:
```bash
scp -r /path/to/Panovision user@your-server-ip:~/
ssh user@your-server-ip
cd ~/Panovision
```

### Option C: Using rsync
From your local machine:
```bash
rsync -avz --exclude 'node_modules' --exclude 'dist' /path/to/Panovision user@your-server-ip:~/
```

## Step 4: Build and Run the Docker Image

### Option A: Using Docker Compose (Recommended)
```bash
cd ~/panovision
docker-compose up -d --build
```

### Option B: Using Docker commands
```bash
cd ~/panovision
docker build -t panovision .
docker run -d -p 3000:80 --name panovision --restart unless-stopped panovision
```

## Step 5: Verify the Container is Running

```bash
docker ps
docker logs panovision
```

You should see the container running and can access the application at `http://your-server-ip:3000`

## Step 6: Configure Firewall (if enabled)

```bash
sudo ufw allow 3000/tcp
sudo ufw status
```

## Step 7: Set Up as a Systemd Service (Optional)

Create a systemd service for better management:

```bash
sudo nano /etc/systemd/system/panovision.service
```

Add the following content:
```ini
[Unit]
Description=Panovision Docker Container
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/YOUR_USER/panovision
ExecStart=/usr/bin/docker-compose up -d
ExecStop=/usr/bin/docker-compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
```

Replace `YOUR_USER` with your actual username, then:
```bash
sudo systemctl daemon-reload
sudo systemctl enable panovision.service
sudo systemctl start panovision.service
```

## Step 8: Set Up Reverse Proxy with Nginx (Optional)

If you want to serve on port 80/443 with SSL:

### Install Nginx
```bash
sudo apt-get install -y nginx
```

### Create Nginx configuration
```bash
sudo nano /etc/nginx/sites-available/panovision
```

Add:
```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Enable the site
```bash
sudo ln -s /etc/nginx/sites-available/panovision /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### Set up SSL with Let's Encrypt (Optional)
```bash
sudo apt-get install -y certbot python3-certbot-nginx
sudo certbot --nginx -d your-domain.com
```

## Useful Commands

### View logs
```bash
docker logs -f panovision
```

### Stop container
```bash
docker-compose down
# or
docker stop panovision
```

### Start container
```bash
docker-compose up -d
# or
docker start panovision
```

### Restart container
```bash
docker-compose restart
# or
docker restart panovision
```

### Update application
```bash
cd ~/panovision
git pull
docker-compose up -d --build
```

### Remove container and image
```bash
docker-compose down
docker rmi panovision
```

## Troubleshooting

### Check if port is in use
```bash
sudo netstat -tulpn | grep 3000
```

### Check Docker status
```bash
sudo systemctl status docker
```

### View container logs
```bash
docker logs panovision
```

### Access container shell
```bash
docker exec -it panovision sh
```

### Check container resource usage
```bash
docker stats panovision
```
