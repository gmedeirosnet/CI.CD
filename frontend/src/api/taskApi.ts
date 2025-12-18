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
