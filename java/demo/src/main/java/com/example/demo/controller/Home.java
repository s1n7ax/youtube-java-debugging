package com.example.demo.controller;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.PropertySource;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@PropertySource("classpath:application.properties")
@RestController
class Home {
    @Value("${greeting.text}")
    private String greeting;

    @GetMapping
    public String root(@RequestParam String name) {
        return greeting + " " + name;
    }
}
