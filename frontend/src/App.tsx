import { useState } from 'react';
import { QueryClient, QueryClientProvider, useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { taskApi } from './api/taskApi';

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
