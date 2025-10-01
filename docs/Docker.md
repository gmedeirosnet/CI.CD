# Docker Guide

## Introduction
Docker is a platform for developing, shipping, and running applications in containers. Containers allow developers to package an application with all its dependencies and ship it as one package.

## Key Features
- Lightweight containerization
- Portability across different environments
- Version control for images
- Isolation of applications
- Efficient resource utilization
- Fast startup times
- Large ecosystem (Docker Hub)
- Support for microservices architecture

## Prerequisites
- 64-bit operating system
- Virtualization support enabled in BIOS
- Basic understanding of command-line interface
- Understanding of application deployment concepts

## Installation

### On macOS
```bash
# Install Docker Desktop
# Download from: https://www.docker.com/products/docker-desktop/

# Or use Homebrew
brew install --cask docker
```

### On Linux (Ubuntu/Debian)
```bash
# Update package index
sudo apt-get update

# Install dependencies
sudo apt-get install ca-certificates curl gnupg lsb-release

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Set up repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt-get update
sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add user to docker group
sudo usermod -aG docker $USER
```

### Verify Installation
```bash
docker --version
docker run hello-world
```

## Basic Concepts

### Images
Pre-built templates containing application code and dependencies.

### Containers
Running instances of Docker images.

### Dockerfile
Text file containing instructions to build a Docker image.

### Registry
Repository for storing and distributing Docker images (e.g., Docker Hub, Harbor).

## Basic Usage

### Working with Images
```bash
# Pull image from registry
docker pull nginx:latest

# List local images
docker images

# Build image from Dockerfile
docker build -t myapp:1.0 .

# Remove image
docker rmi myapp:1.0

# Tag image
docker tag myapp:1.0 myapp:latest

# Push image to registry
docker push myregistry.com/myapp:1.0
```

### Working with Containers
```bash
# Run container
docker run -d --name mycontainer -p 8080:80 nginx:latest

# List running containers
docker ps

# List all containers
docker ps -a

# Stop container
docker stop mycontainer

# Start stopped container
docker start mycontainer

# Restart container
docker restart mycontainer

# Remove container
docker rm mycontainer

# View container logs
docker logs mycontainer

# Follow logs in real-time
docker logs -f mycontainer

# Execute command in running container
docker exec -it mycontainer bash

# Inspect container
docker inspect mycontainer

# View container resource usage
docker stats mycontainer
```

## Dockerfile Examples

### Basic Dockerfile
```dockerfile
# Base image
FROM ubuntu:20.04

# Set working directory
WORKDIR /app

# Copy files
COPY . /app

# Run commands
RUN apt-get update && apt-get install -y python3

# Set environment variable
ENV PORT=8080

# Expose port
EXPOSE 8080

# Define entrypoint
ENTRYPOINT ["python3"]

# Define default command
CMD ["app.py"]
```

### Multi-stage Build
```dockerfile
# Build stage
FROM maven:3.8-openjdk-11 AS builder
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn clean package -DskipTests

# Runtime stage
FROM openjdk:11-jre-slim
WORKDIR /app
COPY --from=builder /app/target/myapp.jar .
EXPOSE 8080
CMD ["java", "-jar", "myapp.jar"]
```

### Node.js Application
```dockerfile
FROM node:16-alpine

WORKDIR /usr/src/app

COPY package*.json ./

RUN npm ci --only=production

COPY . .

EXPOSE 3000

USER node

CMD ["node", "server.js"]
```

## Docker Compose

### docker-compose.yml Example
```yaml
version: '3.8'

services:
  web:
    build: .
    ports:
      - "8080:8080"
    environment:
      - DATABASE_URL=postgresql://db:5432/mydb
    depends_on:
      - db
    volumes:
      - ./app:/app
    networks:
      - mynetwork

  db:
    image: postgres:13
    environment:
      - POSTGRES_DB=mydb
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=password
    volumes:
      - db-data:/var/lib/postgresql/data
    networks:
      - mynetwork

volumes:
  db-data:

networks:
  mynetwork:
    driver: bridge
```

### Docker Compose Commands
```bash
# Start services
docker-compose up -d

# Stop services
docker-compose down

# View logs
docker-compose logs -f

# Scale services
docker-compose up -d --scale web=3

# Build or rebuild services
docker-compose build

# Execute command in service
docker-compose exec web bash
```

## Advanced Features

### Volumes
```bash
# Create volume
docker volume create myvolume

# Mount volume
docker run -v myvolume:/data myimage

# Bind mount
docker run -v /host/path:/container/path myimage

# List volumes
docker volume ls

# Remove volume
docker volume rm myvolume
```

### Networks
```bash
# Create network
docker network create mynetwork

# Connect container to network
docker network connect mynetwork mycontainer

# Disconnect container from network
docker network disconnect mynetwork mycontainer

# List networks
docker network ls

# Inspect network
docker network inspect mynetwork
```

### Docker Swarm (Orchestration)
```bash
# Initialize swarm
docker swarm init

# Deploy stack
docker stack deploy -c docker-compose.yml mystack

# List services
docker service ls

# Scale service
docker service scale mystack_web=5

# Remove stack
docker stack rm mystack
```

## Integration with Other Tools

### Jenkins Integration
- Use Docker plugin in Jenkins
- Build and run containers in CI/CD pipeline
- Use Docker agents for Jenkins builds

### Harbor Integration
- Push images to Harbor registry
- Scan images for vulnerabilities
- Sign images for security

### Kubernetes Integration
- Deploy Docker containers to Kubernetes
- Use Docker images in Kubernetes pods
- Container runtime interface (CRI)

### Maven Integration
- Use Maven in Docker for builds
- Create Docker images from Maven projects
- Use Jib or Dockerfile-maven-plugin

## Best Practices
1. Use official base images when possible
2. Minimize number of layers in Dockerfile
3. Use .dockerignore file to exclude unnecessary files
4. Don't run containers as root
5. Use multi-stage builds to reduce image size
6. Pin specific image versions (avoid :latest in production)
7. Scan images for vulnerabilities
8. Use health checks
9. Store secrets using Docker secrets or external vault
10. Clean up unused images and containers regularly

## Security Considerations
- Run containers with least privileges
- Use read-only file systems when possible
- Limit container resources (CPU, memory)
- Scan images for vulnerabilities
- Use trusted base images
- Keep Docker and images updated
- Implement network segmentation
- Use secrets management
- Enable content trust
- Audit container activity

## Performance Optimization
- Use appropriate base images (alpine for smaller size)
- Implement layer caching effectively
- Use multi-stage builds
- Minimize image size by removing unnecessary files
- Use .dockerignore
- Optimize Dockerfile instruction order
- Use BuildKit for faster builds

## Troubleshooting

### Container won't start
```bash
# Check logs
docker logs mycontainer

# Inspect container
docker inspect mycontainer

# Check events
docker events
```

### Image build fails
```bash
# Build with verbose output
docker build --no-cache --progress=plain -t myapp .

# Check Dockerfile syntax
docker build --check -t myapp .
```

### Networking issues
```bash
# Inspect network
docker network inspect bridge

# Check container networking
docker exec mycontainer ping google.com

# List ports
docker port mycontainer
```

### Storage issues
```bash
# Check disk usage
docker system df

# Clean up unused resources
docker system prune -a

# Remove unused volumes
docker volume prune
```

## Useful Commands

### System Management
```bash
# View Docker info
docker info

# View disk usage
docker system df

# Clean up everything
docker system prune -a --volumes

# View events
docker events
```

### Image Management
```bash
# Save image to tar
docker save myimage:tag -o myimage.tar

# Load image from tar
docker load -i myimage.tar

# Export container filesystem
docker export mycontainer -o container.tar

# Import filesystem as image
docker import container.tar myimage:tag
```

## References
- Official Documentation: https://docs.docker.com/
- Docker Hub: https://hub.docker.com/
- Best Practices: https://docs.docker.com/develop/dev-best-practices/
- Dockerfile Reference: https://docs.docker.com/engine/reference/builder/
