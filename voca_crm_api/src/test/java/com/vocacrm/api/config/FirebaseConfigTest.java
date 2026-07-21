package com.vocacrm.api.config;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.MockedStatic;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.core.io.Resource;
import org.springframework.test.util.ReflectionTestUtils;

import java.io.ByteArrayInputStream;
import java.util.Collections;
import java.util.List;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.mockStatic;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class FirebaseConfigTest {

    @Mock
    private Resource serviceAccountResource;

    @Test
    void firebase비활성화면_FirebaseApp을_초기화하지않는다() {
        FirebaseConfig config = new FirebaseConfig();
        ReflectionTestUtils.setField(config, "firebaseEnabled", false);
        ReflectionTestUtils.setField(config, "serviceAccountResource", serviceAccountResource);

        try (MockedStatic<FirebaseApp> firebaseAppStatic = mockStatic(FirebaseApp.class)) {
            config.initialize();

            firebaseAppStatic.verifyNoInteractions();
        }
    }

    @Test
    void 인증파일이없으면_초기화를건너뛴다() throws Exception {
        FirebaseConfig config = new FirebaseConfig();
        ReflectionTestUtils.setField(config, "firebaseEnabled", true);
        ReflectionTestUtils.setField(config, "serviceAccountResource", serviceAccountResource);
        when(serviceAccountResource.exists()).thenReturn(false);

        try (MockedStatic<FirebaseApp> firebaseAppStatic = mockStatic(FirebaseApp.class)) {
            firebaseAppStatic.when(FirebaseApp::getApps).thenReturn(Collections.emptyList());

            config.initialize();

            firebaseAppStatic.verify(() -> FirebaseApp.initializeApp(any(com.google.firebase.FirebaseOptions.class)), never());
        }
    }

    @Test
    void 이미초기화된경우_다시초기화하지않는다() {
        FirebaseConfig config = new FirebaseConfig();
        ReflectionTestUtils.setField(config, "firebaseEnabled", true);
        ReflectionTestUtils.setField(config, "serviceAccountResource", serviceAccountResource);

        FirebaseApp existingApp = mock(FirebaseApp.class);
        try (MockedStatic<FirebaseApp> firebaseAppStatic = mockStatic(FirebaseApp.class)) {
            firebaseAppStatic.when(FirebaseApp::getApps).thenReturn(List.of(existingApp));

            config.initialize();

            firebaseAppStatic.verify(() -> FirebaseApp.initializeApp(any(com.google.firebase.FirebaseOptions.class)), never());
        }
    }

    @Test
    void 인증파일이있으면_FirebaseApp을초기화한다() throws Exception {
        FirebaseConfig config = new FirebaseConfig();
        ReflectionTestUtils.setField(config, "firebaseEnabled", true);
        ReflectionTestUtils.setField(config, "serviceAccountResource", serviceAccountResource);
        when(serviceAccountResource.exists()).thenReturn(true);
        when(serviceAccountResource.getInputStream()).thenReturn(new ByteArrayInputStream(new byte[0]));

        GoogleCredentials credentials = mock(GoogleCredentials.class);

        try (MockedStatic<FirebaseApp> firebaseAppStatic = mockStatic(FirebaseApp.class);
             MockedStatic<GoogleCredentials> credentialsStatic = mockStatic(GoogleCredentials.class)) {
            firebaseAppStatic.when(FirebaseApp::getApps).thenReturn(Collections.emptyList());
            credentialsStatic.when(() -> GoogleCredentials.fromStream(any())).thenReturn(credentials);

            config.initialize();

            firebaseAppStatic.verify(() -> FirebaseApp.initializeApp(any(com.google.firebase.FirebaseOptions.class)), times(1));
        }
    }
}
