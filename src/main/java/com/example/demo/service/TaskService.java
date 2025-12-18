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
