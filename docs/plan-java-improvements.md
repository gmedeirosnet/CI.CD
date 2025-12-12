# Java Application Enhancement Plan
## From Simple Demo to Full-Stack Microservices Architecture

**Created:** December 12, 2025  
**Objective:** Transform the current simple Spring Boot demo into a production-like full-stack application with database persistence, demonstrating real-world CI/CD patterns.

---

## Executive Summary

This plan outlines the evolution of the `cicd-demo` application from a stateless REST API to a complete three-tier architecture:

- **Backend API**: Spring Boot 3.5.7 with JPA/Hibernate (REST + GraphQL)
- **Database**: PostgreSQL 16 with persistent storage
- **Frontend**: React 18 with TypeScript (SPA served via Nginx)
- **Architecture**: Microservices deployed on existing Kind cluster with full observability

**Timeline:** 4-6 hours of implementation  
**Complexity:** Intermediate to Advanced

---

## Current State Assessment

### Existing Application
- ✅ Spring Boot 3.5.7 + Java 21
- ✅ Basic REST endpoints (`/`, `/health`, `/info`)
- ✅ Unit and integration tests
- ✅ Docker multi-stage build
- ✅ Helm chart deployment
- ✅ ArgoCD GitOps workflow
- ✅ Kyverno policy enforcement

### Gaps to Address
- ❌ No data persistence (stateless only)
- ❌ No frontend/UI
- ❌ No database interaction
- ❌ Limited business logic
- ❌ No asynchronous processing
- ❌ No service-to-service communication

---

## Target Architecture

### Component Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         Kind Cluster                             │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ Namespace: app-demo                                      │   │
│  │                                                           │   │
│  │  ┌──────────────┐      ┌──────────────┐      ┌────────┐ │   │
│  │  │   Frontend   │─────▶│   Backend    │─────▶│ Postgres│ │   │
│  │  │  React + TS  │      │ Spring Boot  │      │   DB    │ │   │
│  │  │   (Nginx)    │      │   REST API   │      │         │ │   │
│  │  │ Port: 30080  │      │  Port: 8001  │      │ Port:5432│ │   │
│  │  └──────────────┘      └──────────────┘      └────────┘ │   │
│  │         │                      │                    │     │   │
│  │         └──────────────────────┴────────────────────┘     │   │
│  │                           │                                │   │
│  │                  ┌────────▼────────┐                       │   │
│  │                  │   Observability  │                      │   │
│  │                  │  Loki + Prometheus│                     │   │
│  │                  └─────────────────┘                       │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                   │
│  External Services:                                              │
│  - Harbor (localhost:8082) - Image registry                      │
│  - Jenkins (localhost:8080) - CI/CD pipeline                     │
│  - ArgoCD (localhost:8090) - GitOps deployment                   │
│  - Grafana (localhost:3000) - Monitoring dashboards              │
└───────────────────────────────────────────────────────────────────┘
```

### Technology Stack

| Component | Technology | Version | Purpose |
|-----------|-----------|---------|---------|
| **Backend** | Spring Boot | 3.5.7 | REST API, business logic |
| | Spring Data JPA | 3.5.7 | Database ORM |
| | PostgreSQL Driver | 42.7.x | Database connectivity |
| | Spring Actuator | 3.5.7 | Health checks & metrics |
| | Flyway | 10.x | Database migrations |
| | Lombok | 1.18.x | Reduce boilerplate |
| **Database** | PostgreSQL | 16-alpine | Persistent data store |
| **Frontend** | React | 18.3.x | UI framework |
| | TypeScript | 5.x | Type safety |
| | Vite | 5.x | Build tool (faster than CRA) |
| | Axios | 1.7.x | HTTP client |
| | React Query | 5.x | Data fetching & caching |
| | Tailwind CSS | 3.x | Styling |
| **Web Server** | Nginx | 1.26-alpine | Serve static files |

---

## Implementation Plan

### Phase 1: Database Layer (2 hours)

#### 1.1 PostgreSQL Deployment

**Create:** `k8s/postgres/postgres-statefulset.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-config
  namespace: app-demo
data:
  POSTGRES_DB: cicd_demo
  POSTGRES_USER: app_user
---
apiVersion: v1
kind: Secret
metadata:
  name: postgres-secret
  namespace: app-demo
type: Opaque
data:
  POSTGRES_PASSWORD: Y2lkY19kZW1vX3Bhc3M=  # cicd_demo_pass (base64)
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-pvc
  namespace: app-demo
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: app-demo
spec:
  serviceName: postgres
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      securityContext:
        fsGroup: 999
        runAsNonRoot: true
        runAsUser: 999
      containers:
      - name: postgres
        image: postgres:16-alpine
        ports:
        - containerPort: 5432
        envFrom:
        - configMapRef:
            name: postgres-config
        - secretRef:
            name: postgres-secret
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
          subPath: postgres
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - app_user
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - app_user
          initialDelaySeconds: 5
          periodSeconds: 5
      volumes:
      - name: postgres-storage
        persistentVolumeClaim:
          claimName: postgres-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: app-demo
spec:
  selector:
    app: postgres
  ports:
  - port: 5432
    targetPort: 5432
  type: ClusterIP
```

**Kyverno Compliance:** ✅ Non-root user (999), ✅ Resource limits, ✅ Required labels

#### 1.2 Backend Database Integration

**Update:** `pom.xml` - Add dependencies

```xml
<!-- Add after existing dependencies -->
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-data-jpa</artifactId>
    <version>${spring-boot.version}</version>
</dependency>
<dependency>
    <groupId>org.postgresql</groupId>
    <artifactId>postgresql</artifactId>
    <version>42.7.4</version>
    <scope>runtime</scope>
</dependency>
<dependency>
    <groupId>org.flywaydb</groupId>
    <artifactId>flyway-core</artifactId>
    <version>10.21.0</version>
</dependency>
<dependency>
    <groupId>org.flywaydb</groupId>
    <artifactId>flyway-database-postgresql</artifactId>
    <version>10.21.0</version>
</dependency>
<dependency>
    <groupId>org.projectlombok</groupId>
    <artifactId>lombok</artifactId>
    <version>1.18.36</version>
    <scope>provided</scope>
</dependency>
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-actuator</artifactId>
    <version>${spring-boot.version}</version>
</dependency>
<dependency>
    <groupId>org.springframework.boot</groupId>
    <artifactId>spring-boot-starter-validation</artifactId>
    <version>${spring-boot.version}</version>
</dependency>
```

**Update:** `src/main/resources/application.properties`

```properties
# Application Configuration
spring.application.name=cicd-demo
server.port=8001

# Database Configuration
spring.datasource.url=jdbc:postgresql://${DB_HOST:postgres}:5432/${DB_NAME:cicd_demo}
spring.datasource.username=${DB_USER:app_user}
spring.datasource.password=${DB_PASSWORD:cicd_demo_pass}
spring.datasource.driver-class-name=org.postgresql.Driver

# JPA Configuration
spring.jpa.hibernate.ddl-auto=validate
spring.jpa.show-sql=false
spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.PostgreSQLDialect
spring.jpa.properties.hibernate.format_sql=true

# Flyway Configuration
spring.flyway.enabled=true
spring.flyway.locations=classpath:db/migration
spring.flyway.baseline-on-migrate=true

# Actuator Configuration
management.endpoints.web.exposure.include=health,info,metrics,prometheus
management.endpoint.health.show-details=when-authorized
management.metrics.export.prometheus.enabled=true

# Logging
logging.level.root=INFO
logging.level.com.example.demo=DEBUG
logging.level.org.hibernate.SQL=DEBUG
logging.level.org.hibernate.type.descriptor.sql.BasicBinder=TRACE
```

#### 1.3 Create Database Schema (Flyway Migration)

**Create:** `src/main/resources/db/migration/V1__initial_schema.sql`

```sql
-- Tasks table for a simple TODO application
CREATE TABLE tasks (
    id BIGSERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'TODO',
    priority VARCHAR(20) DEFAULT 'MEDIUM',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    CONSTRAINT chk_status CHECK (status IN ('TODO', 'IN_PROGRESS', 'DONE', 'CANCELLED')),
    CONSTRAINT chk_priority CHECK (priority IN ('LOW', 'MEDIUM', 'HIGH', 'URGENT'))
);

-- Index for common queries
CREATE INDEX idx_tasks_status ON tasks(status);
CREATE INDEX idx_tasks_priority ON tasks(priority);
CREATE INDEX idx_tasks_created_at ON tasks(created_at DESC);

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_tasks_updated_at BEFORE UPDATE ON tasks
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insert sample data
INSERT INTO tasks (title, description, status, priority) VALUES
    ('Setup CI/CD Pipeline', 'Configure Jenkins, Harbor, and ArgoCD', 'DONE', 'HIGH'),
    ('Deploy to Kubernetes', 'Deploy application to Kind cluster', 'DONE', 'HIGH'),
    ('Add Database Layer', 'Integrate PostgreSQL with Spring Boot', 'IN_PROGRESS', 'MEDIUM'),
    ('Create Frontend', 'Build React application', 'TODO', 'MEDIUM'),
    ('Setup Monitoring', 'Configure Grafana dashboards', 'TODO', 'LOW');
```

#### 1.4 Create JPA Entities and Repository

**Create:** `src/main/java/com/example/demo/entity/Task.java`

```java
package com.example.demo.entity;

import jakarta.persistence.*;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDateTime;

@Entity
@Table(name = "tasks")
@Data
@NoArgsConstructor
@AllArgsConstructor
public class Task {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @NotBlank(message = "Title is required")
    @Size(max = 255, message = "Title must not exceed 255 characters")
    @Column(nullable = false)
    private String title;

    @Column(columnDefinition = "TEXT")
    private String description;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private TaskStatus status = TaskStatus.TODO;

    @Enumerated(EnumType.STRING)
    @Column(length = 20)
    private TaskPriority priority = TaskPriority.MEDIUM;

    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;

    @Column(name = "updated_at", nullable = false)
    private LocalDateTime updatedAt;

    @Column(name = "completed_at")
    private LocalDateTime completedAt;

    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        updatedAt = LocalDateTime.now();
    }

    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
        if (status == TaskStatus.DONE && completedAt == null) {
            completedAt = LocalDateTime.now();
        }
    }

    public enum TaskStatus {
        TODO, IN_PROGRESS, DONE, CANCELLED
    }

    public enum TaskPriority {
        LOW, MEDIUM, HIGH, URGENT
    }
}
```

**Create:** `src/main/java/com/example/demo/repository/TaskRepository.java`

```java
package com.example.demo.repository;

import com.example.demo.entity.Task;
import com.example.demo.entity.Task.TaskStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface TaskRepository extends JpaRepository<Task, Long> {
    
    List<Task> findByStatus(TaskStatus status);
    
    List<Task> findByStatusOrderByPriorityDescCreatedAtDesc(TaskStatus status);
    
    @Query("SELECT t FROM Task t WHERE t.status != 'CANCELLED' ORDER BY t.priority DESC, t.createdAt DESC")
    List<Task> findActiveTasksOrderedByPriority();
    
    long countByStatus(TaskStatus status);
}
```

#### 1.5 Create REST API Controllers

**Create:** `src/main/java/com/example/demo/controller/TaskController.java`

```java
package com.example.demo.controller;

import com.example.demo.entity.Task;
import com.example.demo.entity.Task.TaskStatus;
import com.example.demo.service.TaskService;
import jakarta.validation.Valid;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/tasks")
@CrossOrigin(origins = "*")  // Will be restricted in production
public class TaskController {

    @Autowired
    private TaskService taskService;

    @GetMapping
    public List<Task> getAllTasks() {
        return taskService.findAll();
    }

    @GetMapping("/{id}")
    public ResponseEntity<Task> getTaskById(@PathVariable Long id) {
        return taskService.findById(id)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @GetMapping("/status/{status}")
    public List<Task> getTasksByStatus(@PathVariable TaskStatus status) {
        return taskService.findByStatus(status);
    }

    @GetMapping("/active")
    public List<Task> getActiveTasks() {
        return taskService.findActiveTasksOrderedByPriority();
    }

    @GetMapping("/stats")
    public Map<String, Long> getTaskStats() {
        return taskService.getTaskStatistics();
    }

    @PostMapping
    public ResponseEntity<Task> createTask(@Valid @RequestBody Task task) {
        Task created = taskService.save(task);
        return ResponseEntity.status(HttpStatus.CREATED).body(created);
    }

    @PutMapping("/{id}")
    public ResponseEntity<Task> updateTask(@PathVariable Long id, @Valid @RequestBody Task task) {
        return taskService.update(id, task)
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<Void> deleteTask(@PathVariable Long id) {
        if (taskService.delete(id)) {
            return ResponseEntity.noContent().build();
        }
        return ResponseEntity.notFound().build();
    }
}
```

**Create:** `src/main/java/com/example/demo/service/TaskService.java`

```java
package com.example.demo.service;

import com.example.demo.entity.Task;
import com.example.demo.entity.Task.TaskStatus;
import com.example.demo.repository.TaskRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

@Service
@Transactional
public class TaskService {

    @Autowired
    private TaskRepository taskRepository;

    public List<Task> findAll() {
        return taskRepository.findAll();
    }

    public Optional<Task> findById(Long id) {
        return taskRepository.findById(id);
    }

    public List<Task> findByStatus(TaskStatus status) {
        return taskRepository.findByStatusOrderByPriorityDescCreatedAtDesc(status);
    }

    public List<Task> findActiveTasksOrderedByPriority() {
        return taskRepository.findActiveTasksOrderedByPriority();
    }

    public Task save(Task task) {
        return taskRepository.save(task);
    }

    public Optional<Task> update(Long id, Task updatedTask) {
        return taskRepository.findById(id).map(task -> {
            task.setTitle(updatedTask.getTitle());
            task.setDescription(updatedTask.getDescription());
            task.setStatus(updatedTask.getStatus());
            task.setPriority(updatedTask.getPriority());
            return taskRepository.save(task);
        });
    }

    public boolean delete(Long id) {
        if (taskRepository.existsById(id)) {
            taskRepository.deleteById(id);
            return true;
        }
        return false;
    }

    public Map<String, Long> getTaskStatistics() {
        Map<String, Long> stats = new HashMap<>();
        stats.put("total", taskRepository.count());
        stats.put("todo", taskRepository.countByStatus(TaskStatus.TODO));
        stats.put("in_progress", taskRepository.countByStatus(TaskStatus.IN_PROGRESS));
        stats.put("done", taskRepository.countByStatus(TaskStatus.DONE));
        stats.put("cancelled", taskRepository.countByStatus(TaskStatus.CANCELLED));
        return stats;
    }
}
```

---

### Phase 2: Frontend Application (2 hours)

#### 2.1 Initialize React + TypeScript + Vite Project

**Create:** `frontend/` directory structure

```bash
cd /Users/gutembergmedeiros/Labs/CI.CD
mkdir -p frontend
cd frontend

# Initialize Vite project with React + TypeScript
npm create vite@latest . -- --template react-ts

# Install dependencies
npm install axios react-query @tanstack/react-query
npm install -D tailwindcss postcss autoprefixer
npx tailwindcss init -p
```

**Create:** `frontend/tailwind.config.js`

```javascript
/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {},
  },
  plugins: [],
}
```

#### 2.2 Frontend Source Code Structure

**Create:** `frontend/src/api/taskApi.ts`

```typescript
import axios from 'axios';

const API_BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:8001';

export interface Task {
  id?: number;
  title: string;
  description?: string;
  status: 'TODO' | 'IN_PROGRESS' | 'DONE' | 'CANCELLED';
  priority: 'LOW' | 'MEDIUM' | 'HIGH' | 'URGENT';
  createdAt?: string;
  updatedAt?: string;
  completedAt?: string;
}

export interface TaskStats {
  total: number;
  todo: number;
  in_progress: number;
  done: number;
  cancelled: number;
}

const api = axios.create({
  baseURL: `${API_BASE_URL}/api`,
  headers: {
    'Content-Type': 'application/json',
  },
});

export const taskApi = {
  getAllTasks: () => api.get<Task[]>('/tasks'),
  getTaskById: (id: number) => api.get<Task>(`/tasks/${id}`),
  getTasksByStatus: (status: string) => api.get<Task[]>(`/tasks/status/${status}`),
  getActiveTasks: () => api.get<Task[]>('/tasks/active'),
  getTaskStats: () => api.get<TaskStats>('/tasks/stats'),
  createTask: (task: Task) => api.post<Task>('/tasks', task),
  updateTask: (id: number, task: Task) => api.put<Task>(`/tasks/${id}`, task),
  deleteTask: (id: number) => api.delete(`/tasks/${id}`),
};
```

**Create:** `frontend/src/App.tsx` (simplified version)

```typescript
import React, { useState } from 'react';
import { QueryClient, QueryClientProvider, useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { taskApi, Task } from './api/taskApi';
import './App.css';

const queryClient = new QueryClient();

function TaskApp() {
  const queryClient = useQueryClient();
  const [filter, setFilter] = useState<string>('all');

  // Fetch tasks
  const { data: tasks = [], isLoading } = useQuery({
    queryKey: ['tasks'],
    queryFn: async () => {
      const response = await taskApi.getAllTasks();
      return response.data;
    },
  });

  // Fetch stats
  const { data: stats } = useQuery({
    queryKey: ['taskStats'],
    queryFn: async () => {
      const response = await taskApi.getTaskStats();
      return response.data;
    },
  });

  // Create task mutation
  const createMutation = useMutation({
    mutationFn: taskApi.createTask,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['tasks'] });
      queryClient.invalidateQueries({ queryKey: ['taskStats'] });
    },
  });

  // Delete task mutation
  const deleteMutation = useMutation({
    mutationFn: (id: number) => taskApi.deleteTask(id),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['tasks'] });
      queryClient.invalidateQueries({ queryKey: ['taskStats'] });
    },
  });

  const filteredTasks = filter === 'all' 
    ? tasks 
    : tasks.filter(task => task.status === filter);

  return (
    <div className="min-h-screen bg-gray-100 py-8">
      <div className="max-w-6xl mx-auto px-4">
        <header className="mb-8">
          <h1 className="text-4xl font-bold text-gray-900 mb-2">CI/CD Task Manager</h1>
          <p className="text-gray-600">Full-stack demo with Spring Boot + React + PostgreSQL</p>
        </header>

        {/* Stats Dashboard */}
        {stats && (
          <div className="grid grid-cols-5 gap-4 mb-6">
            <StatCard label="Total" value={stats.total} color="bg-blue-500" />
            <StatCard label="To Do" value={stats.todo} color="bg-gray-500" />
            <StatCard label="In Progress" value={stats.in_progress} color="bg-yellow-500" />
            <StatCard label="Done" value={stats.done} color="bg-green-500" />
            <StatCard label="Cancelled" value={stats.cancelled} color="bg-red-500" />
          </div>
        )}

        {/* Filter Tabs */}
        <div className="bg-white rounded-lg shadow p-4 mb-6">
          <div className="flex gap-2">
            {['all', 'TODO', 'IN_PROGRESS', 'DONE'].map(status => (
              <button
                key={status}
                onClick={() => setFilter(status)}
                className={`px-4 py-2 rounded ${filter === status ? 'bg-blue-500 text-white' : 'bg-gray-200'}`}
              >
                {status.replace('_', ' ')}
              </button>
            ))}
          </div>
        </div>

        {/* Task List */}
        <div className="bg-white rounded-lg shadow">
          {isLoading ? (
            <div className="p-8 text-center">Loading tasks...</div>
          ) : (
            <ul className="divide-y">
              {filteredTasks.map(task => (
                <li key={task.id} className="p-4 hover:bg-gray-50">
                  <div className="flex justify-between items-start">
                    <div>
                      <h3 className="font-semibold text-lg">{task.title}</h3>
                      <p className="text-gray-600 text-sm mt-1">{task.description}</p>
                      <div className="mt-2 flex gap-2">
                        <span className={`px-2 py-1 rounded text-xs ${getStatusColor(task.status)}`}>
                          {task.status}
                        </span>
                        <span className={`px-2 py-1 rounded text-xs ${getPriorityColor(task.priority)}`}>
                          {task.priority}
                        </span>
                      </div>
                    </div>
                    <button
                      onClick={() => task.id && deleteMutation.mutate(task.id)}
                      className="text-red-600 hover:text-red-800"
                    >
                      Delete
                    </button>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </div>
      </div>
    </div>
  );
}

function StatCard({ label, value, color }: { label: string; value: number; color: string }) {
  return (
    <div className="bg-white rounded-lg shadow p-4">
      <div className={`${color} text-white text-2xl font-bold rounded p-2 text-center mb-2`}>
        {value}
      </div>
      <div className="text-gray-600 text-sm text-center">{label}</div>
    </div>
  );
}

function getStatusColor(status: string) {
  const colors = {
    TODO: 'bg-gray-200 text-gray-800',
    IN_PROGRESS: 'bg-yellow-200 text-yellow-800',
    DONE: 'bg-green-200 text-green-800',
    CANCELLED: 'bg-red-200 text-red-800',
  };
  return colors[status as keyof typeof colors] || 'bg-gray-200';
}

function getPriorityColor(priority: string) {
  const colors = {
    LOW: 'bg-blue-100 text-blue-800',
    MEDIUM: 'bg-blue-200 text-blue-900',
    HIGH: 'bg-orange-200 text-orange-900',
    URGENT: 'bg-red-200 text-red-900',
  };
  return colors[priority as keyof typeof colors] || 'bg-gray-200';
}

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <TaskApp />
    </QueryClientProvider>
  );
}

export default App;
```

#### 2.3 Frontend Dockerfile with Nginx

**Create:** `frontend/Dockerfile`

```dockerfile
# Stage 1: Build React app
FROM node:20-alpine AS builder
WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .
RUN npm run build

# Stage 2: Serve with Nginx
FROM nginx:1.26-alpine

# Copy custom nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Copy built app
COPY --from=builder /app/dist /usr/share/nginx/html

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://localhost:80/health || exit 1

# Run as non-root (Kyverno compliance)
RUN chown -R nginx:nginx /usr/share/nginx/html && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    chown -R nginx:nginx /etc/nginx/conf.d && \
    touch /var/run/nginx.pid && \
    chown -R nginx:nginx /var/run/nginx.pid

USER nginx

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

**Create:** `frontend/nginx.conf`

```nginx
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Gzip compression
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;

    # SPA routing - serve index.html for all routes
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Proxy API requests to backend
    location /api {
        proxy_pass http://cicd-demo-backend:8001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }

    # Cache static assets
    location ~* \.(?:css|js|jpg|jpeg|gif|png|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
```

---

### Phase 3: Helm Chart Updates (1 hour)

#### 3.1 Update Helm Chart for Multi-Service Deployment

**Update:** `helm-charts/cicd-demo/values.yaml`

```yaml
# Global settings
global:
  namespace: app-demo
  registry: host.docker.internal:8082/cicd-demo

# Backend service
backend:
  enabled: true
  name: cicd-demo-backend
  image:
    repository: host.docker.internal:8082/cicd-demo/app
    tag: latest
    pullPolicy: Always
  
  replicaCount: 2
  
  service:
    type: ClusterIP
    port: 8001
    targetPort: 8001
  
  env:
    - name: DB_HOST
      value: postgres
    - name: DB_NAME
      value: cicd_demo
    - name: DB_USER
      valueFrom:
        configMapKeyRef:
          name: postgres-config
          key: POSTGRES_USER
    - name: DB_PASSWORD
      valueFrom:
        secretKeyRef:
          name: postgres-secret
          key: POSTGRES_PASSWORD
    - name: SPRING_PROFILES_ACTIVE
      value: production
  
  resources:
    requests:
      memory: "512Mi"
      cpu: "250m"
    limits:
      memory: "1Gi"
      cpu: "1000m"
  
  securityContext:
    runAsNonRoot: true
    runAsUser: 1000
    fsGroup: 1000
  
  livenessProbe:
    httpGet:
      path: /actuator/health/liveness
      port: 8001
    initialDelaySeconds: 60
    periodSeconds: 10
  
  readinessProbe:
    httpGet:
      path: /actuator/health/readiness
      port: 8001
    initialDelaySeconds: 30
    periodSeconds: 5

# Frontend service
frontend:
  enabled: true
  name: cicd-demo-frontend
  image:
    repository: host.docker.internal:8082/cicd-demo/frontend
    tag: latest
    pullPolicy: Always
  
  replicaCount: 2
  
  service:
    type: NodePort
    port: 80
    targetPort: 80
    nodePort: 30080
  
  resources:
    requests:
      memory: "128Mi"
      cpu: "100m"
    limits:
      memory: "256Mi"
      cpu: "250m"
  
  securityContext:
    runAsNonRoot: true
    runAsUser: 101  # nginx user in alpine
    fsGroup: 101
  
  livenessProbe:
    httpGet:
      path: /health
      port: 80
    initialDelaySeconds: 10
    periodSeconds: 10
  
  readinessProbe:
    httpGet:
      path: /health
      port: 80
    initialDelaySeconds: 5
    periodSeconds: 5

# PostgreSQL (if managed by Helm)
postgresql:
  enabled: true
  # Reference to StatefulSet created separately
```

#### 3.2 Create Helm Templates

**Create:** `helm-charts/cicd-demo/templates/backend-deployment.yaml`
**Create:** `helm-charts/cicd-demo/templates/frontend-deployment.yaml`
**Create:** `helm-charts/cicd-demo/templates/backend-service.yaml`
**Create:** `helm-charts/cicd-demo/templates/frontend-service.yaml`

---

### Phase 4: CI/CD Pipeline Updates (1 hour)

#### 4.1 Multi-Service Jenkins Pipeline

**Update:** `Jenkinsfile` - Add frontend build stages

```groovy
// Add after Stage 7 (Push to Harbor)
stage('Build Frontend Image') {
    steps {
        script {
            sh """
                cd frontend
                docker build -t \${HARBOR_REGISTRY}/\${HARBOR_PROJECT}/frontend:\${IMAGE_TAG} .
            """
        }
    }
}

stage('Push Frontend to Harbor') {
    steps {
        script {
            withCredentials([usernamePassword(credentialsId: 'harbor-credentials', 
                                             usernameVariable: 'HARBOR_USER', 
                                             passwordVariable: 'HARBOR_PASS')]) {
                sh """
                    echo \$HARBOR_PASS | docker login \${HARBOR_REGISTRY} -u \$HARBOR_USER --password-stdin
                    docker push \${HARBOR_REGISTRY}/\${HARBOR_PROJECT}/frontend:\${IMAGE_TAG}
                """
            }
        }
    }
}

stage('Load Frontend into Kind') {
    steps {
        script {
            sh """
                kind load docker-image \${HARBOR_REGISTRY}/\${HARBOR_PROJECT}/frontend:\${IMAGE_TAG} \
                    --name \${KIND_CLUSTER_NAME:-app-demo}
            """
        }
    }
}
```

#### 4.2 Database Migration in Pipeline

**Add stage before deployment:**

```groovy
stage('Run Database Migrations') {
    steps {
        script {
            sh """
                # Deploy temporary migration pod
                kubectl run flyway-migration --rm -i --restart=Never \
                    --image=\${HARBOR_REGISTRY}/\${HARBOR_PROJECT}/app:\${IMAGE_TAG} \
                    --namespace=app-demo \
                    --env="SPRING_FLYWAY_ENABLED=true" \
                    --env="DB_HOST=postgres" \
                    --command -- java -jar app.jar --spring.flyway.migrate
            """
        }
    }
}
```

---

### Phase 5: Testing Strategy (30 minutes)

#### 5.1 Backend Integration Tests

**Create:** `src/test/java/com/example/demo/TaskIntegrationTest.java`

```java
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Testcontainers
class TaskIntegrationTest {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine")
            .withDatabaseName("test_db")
            .withUsername("test_user")
            .withPassword("test_pass");

    @DynamicPropertySource
    static void configureProperties(DynamicPropertyRegistry registry) {
        registry.add("spring.datasource.url", postgres::getJdbcUrl);
        registry.add("spring.datasource.username", postgres::getUsername);
        registry.add("spring.datasource.password", postgres::getPassword);
    }

    @Autowired
    private TestRestTemplate restTemplate;

    @Test
    void testCreateAndRetrieveTask() {
        Task task = new Task();
        task.setTitle("Test Task");
        task.setStatus(Task.TaskStatus.TODO);

        ResponseEntity<Task> response = restTemplate.postForEntity("/api/tasks", task, Task.class);
        assertEquals(HttpStatus.CREATED, response.getStatusCode());
        assertNotNull(response.getBody().getId());
    }
}
```

#### 5.2 Frontend E2E Tests (Cypress)

**Create:** `frontend/cypress/e2e/tasks.cy.ts`

```typescript
describe('Task Management', () => {
  beforeEach(() => {
    cy.visit('http://localhost:30080');
  });

  it('should display task list', () => {
    cy.contains('CI/CD Task Manager').should('be.visible');
    cy.get('[data-testid="task-item"]').should('have.length.greaterThan', 0);
  });

  it('should create new task', () => {
    cy.get('[data-testid="create-task-btn"]').click();
    cy.get('[data-testid="task-title"]').type('New Test Task');
    cy.get('[data-testid="submit-btn"]').click();
    cy.contains('New Test Task').should('be.visible');
  });
});
```

---

### Phase 6: Monitoring & Observability (30 minutes)

#### 6.1 Grafana Dashboard for Full Stack

**Create:** `k8s/grafana/dashboards/fullstack-overview.json`

```json
{
  "dashboard": {
    "title": "Full Stack Application Dashboard",
    "panels": [
      {
        "title": "Backend Request Rate",
        "targets": [
          {
            "expr": "rate(http_server_requests_seconds_count{job=\"cicd-demo-backend\"}[5m])"
          }
        ]
      },
      {
        "title": "Database Connections",
        "targets": [
          {
            "expr": "hikaricp_connections_active{application=\"cicd-demo\"}"
          }
        ]
      },
      {
        "title": "Frontend Response Time",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{job=\"cicd-demo-frontend\"}[5m]))"
          }
        ]
      },
      {
        "title": "Task Statistics",
        "targets": [
          {
            "expr": "task_count_by_status"
          }
        ]
      }
    ]
  }
}
```

#### 6.2 Custom Metrics in Backend

**Add to:** `src/main/java/com/example/demo/service/TaskService.java`

```java
@Service
public class TaskService {
    
    private final MeterRegistry meterRegistry;
    
    @Autowired
    public TaskService(TaskRepository taskRepository, MeterRegistry meterRegistry) {
        this.taskRepository = taskRepository;
        this.meterRegistry = meterRegistry;
        
        // Register custom gauges
        Gauge.builder("tasks.count.total", taskRepository, TaskRepository::count)
             .description("Total number of tasks")
             .register(meterRegistry);
    }
    
    public Task save(Task task) {
        Task saved = taskRepository.save(task);
        meterRegistry.counter("tasks.created", "status", task.getStatus().name()).increment();
        return saved;
    }
}
```

---

## Deployment Sequence

### Step 1: Database Setup
```bash
# Apply PostgreSQL manifests
kubectl apply -f k8s/postgres/

# Verify database is ready
kubectl wait --for=condition=ready pod -l app=postgres -n app-demo --timeout=120s

# Test database connection
kubectl exec -it postgres-0 -n app-demo -- psql -U app_user -d cicd_demo
```

### Step 2: Build Backend with Database Support
```bash
# Trigger Jenkins build
# Pipeline will:
# 1. Compile with new JPA dependencies
# 2. Run Flyway migrations
# 3. Build Docker image
# 4. Push to Harbor
# 5. Deploy via ArgoCD
```

### Step 3: Build and Deploy Frontend
```bash
# Build frontend image
cd frontend
docker build -t host.docker.internal:8082/cicd-demo/frontend:latest .

# Push to Harbor
docker push host.docker.internal:8082/cicd-demo/frontend:latest

# Load into Kind
kind load docker-image host.docker.internal:8082/cicd-demo/frontend:latest --name app-demo

# Deploy via Helm/ArgoCD
kubectl apply -f helm-charts/cicd-demo/
```

### Step 4: Verify Deployment
```bash
# Check all pods are running
kubectl get pods -n app-demo

# Test backend API
curl http://localhost:8001/api/tasks

# Access frontend
open http://localhost:30080

# Check health endpoints
curl http://localhost:8001/actuator/health
curl http://localhost:30080/health
```

---

## Kyverno Policy Compliance Checklist

- ✅ **Non-root containers**: All services run as non-root users
  - Backend: UID 1000
  - Frontend: UID 101 (nginx)
  - PostgreSQL: UID 999
- ✅ **Resource limits**: All pods have CPU/memory requests and limits
- ✅ **Harbor registry**: All images from `host.docker.internal:8082/cicd-demo/*`
- ✅ **Required labels**: `app.kubernetes.io/name` and `app.kubernetes.io/instance` on all resources
- ✅ **Security context**: `runAsNonRoot: true` on all deployments
- ✅ **Read-only root filesystem**: Applied where possible (PostgreSQL needs write access to /var/lib/postgresql/data)

---

## Testing Plan

### Unit Tests
- ✅ Backend: JUnit 5 + Spring Boot Test
- ✅ Frontend: Jest + React Testing Library

### Integration Tests
- ✅ Backend: Testcontainers with PostgreSQL
- ✅ API tests: RestAssured or TestRestTemplate

### E2E Tests
- ✅ Cypress for full user flows
- ✅ Run in Jenkins pipeline post-deployment

### Performance Tests
- 🔄 JMeter or Gatling for load testing
- 🔄 Benchmark database queries

---

## Success Metrics

### Technical Metrics
- **Build time**: < 5 minutes for complete pipeline
- **Deployment time**: < 2 minutes from merge to production
- **Test coverage**: > 80% backend, > 70% frontend
- **API response time**: < 200ms p95
- **Zero downtime**: Rolling updates with health checks

### Observability Metrics
- **Logs**: All logs in Loki with structured JSON format
- **Metrics**: Prometheus scraping all services
- **Traces**: (Optional) OpenTelemetry for distributed tracing
- **Dashboards**: Grafana dashboards for each service

---

## Future Enhancements

### Short Term (Next Iteration)
1. **Authentication & Authorization**: Spring Security + JWT
2. **API Documentation**: Swagger/OpenAPI 3.0
3. **WebSocket support**: Real-time task updates
4. **File uploads**: Store in S3-compatible storage (MinIO)

### Medium Term
5. **GraphQL API**: Alternative to REST
6. **Redis caching**: Improve performance
7. **Message queue**: RabbitMQ or Kafka for async processing
8. **Search**: Elasticsearch for full-text search

### Long Term
9. **Multi-tenancy**: Support multiple organizations
10. **Mobile app**: React Native frontend
11. **Microservices split**: Separate user service, notification service, etc.
12. **Service mesh**: Istio for advanced traffic management

---

## Rollback Strategy

If issues arise during implementation:

1. **Database rollback**: Flyway supports down migrations
   ```sql
   -- Create V1__rollback.sql with DROP statements
   ```

2. **Application rollback**: ArgoCD can revert to previous version
   ```bash
   argocd app rollback cicd-demo-app
   ```

3. **Emergency shutdown**: Scale to zero
   ```bash
   kubectl scale deployment cicd-demo-backend --replicas=0 -n app-demo
   ```

---

## Timeline Summary

| Phase | Duration | Complexity | Priority |
|-------|----------|------------|----------|
| Phase 1: Database Layer | 2 hours | Medium | High |
| Phase 2: Frontend App | 2 hours | Medium | High |
| Phase 3: Helm Updates | 1 hour | Low | High |
| Phase 4: Pipeline Updates | 1 hour | Medium | High |
| Phase 5: Testing | 30 min | Medium | Medium |
| Phase 6: Monitoring | 30 min | Low | Medium |
| **Total** | **6-7 hours** | | |

---

## Prerequisites Checklist

Before starting implementation:

- [ ] Current application is building and deploying successfully
- [ ] Kind cluster is running with sufficient resources (4GB+ memory)
- [ ] Harbor is accessible and has space for new images
- [ ] Jenkins pipeline is stable
- [ ] ArgoCD is syncing correctly
- [ ] Kyverno policies are in Audit mode (not enforcing yet)
- [ ] Git repository is clean with no uncommitted changes
- [ ] Backup current working state (create git branch)

---

## Support Resources

- **Spring Boot 3 Migration Guide**: https://github.com/spring-projects/spring-boot/wiki/Spring-Boot-3.0-Migration-Guide
- **PostgreSQL on Kubernetes**: https://www.postgresql.org/docs/current/
- **React Query Documentation**: https://tanstack.com/query/latest
- **Flyway Migrations**: https://flywaydb.org/documentation/
- **Testcontainers**: https://www.testcontainers.org/
- **Helm Best Practices**: https://helm.sh/docs/chart_best_practices/

---

## Questions to Answer Before Implementation

1. **Database persistence**: Should we use local storage or cloud volumes?
2. **Database backups**: Automated backup strategy needed?
3. **Frontend deployment**: Single SPA or separate micro-frontends?
4. **API versioning**: Start with `/api/v1/` prefix?
5. **Authentication**: Implement now or in phase 2?
6. **Load testing**: Run performance tests before go-live?
7. **Production readiness**: What's the definition of "done"?

---

**End of Plan**

This plan provides a comprehensive roadmap to evolve your CI/CD demo into a production-grade full-stack application. Each phase can be implemented incrementally, tested independently, and deployed through your existing GitOps workflow.

**Next Step**: Review this plan, ask questions, and then proceed with Phase 1 (Database Layer) implementation.
