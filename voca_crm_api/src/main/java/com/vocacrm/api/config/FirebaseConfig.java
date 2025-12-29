package com.vocacrm.api.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.core.io.Resource; // Resource import 추가

import jakarta.annotation.PostConstruct;
import java.io.IOException;
import java.io.InputStream; // InputStream import 추가

@Slf4j
@Configuration
public class FirebaseConfig {

    @Value("classpath:service-account.json")
    private Resource serviceAccountResource;

    @Value("${firebase.enabled:true}")
    private boolean firebaseEnabled;

    @PostConstruct
    public void initialize() {
        if (!firebaseEnabled) {
            log.info("Firebase is disabled. Push notifications will not work.");
            return;
        }

        if (FirebaseApp.getApps().isEmpty()) {
            try {
                if (!serviceAccountResource.exists()) {
                    log.warn("Firebase credentials not found at classpath:service-account.json");
                    log.warn("Push notifications will not work until the file is added.");
                    return;
                }

                try (InputStream serviceAccount = serviceAccountResource.getInputStream()) {
                    FirebaseOptions options = FirebaseOptions.builder()
                            .setCredentials(GoogleCredentials.fromStream(serviceAccount))
                            .build();

                    FirebaseApp.initializeApp(options);
                    log.info("Firebase Admin SDK initialized successfully");
                }
            } catch (IOException e) {
                log.error("Failed to initialize Firebase Admin SDK: {}", e.getMessage());
                log.warn("Push notifications will not work.");
            }
        } else {
            log.info("Firebase Admin SDK already initialized");
        }
    }
}