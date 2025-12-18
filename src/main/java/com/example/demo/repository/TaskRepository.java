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
