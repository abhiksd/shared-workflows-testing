package com.example.javaapp.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDateTime;
import java.util.Map;

@RestController
public class HelloController {

    @GetMapping("/")
    public Map<String, Object> home() {
        return Map.of(
            "message", "Hello World from Java 21!",
            "timestamp", LocalDateTime.now(),
            "java.version", System.getProperty("java.version"),
            "app.version", "1.0.0"
        );
    }

    @GetMapping("/hello")
    public Map<String, String> hello() {
        return Map.of("message", "Hello from Spring Boot with Java 21!");
    }

    @GetMapping("/hello/{name}")
    public Map<String, String> helloName(@PathVariable String name) {
        return Map.of("message", "Hello " + name + " from Java 21!");
    }

    @GetMapping("/health")
    public Map<String, String> health() {
        return Map.of("status", "UP", "java.version", System.getProperty("java.version"));
    }
}