package com.vocacrm.api.config;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.SerializationFeature;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.core.env.Environment;
import org.springframework.test.util.ReflectionTestUtils;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;

import java.time.LocalDateTime;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class WebConfigTest {

    @Mock
    private Environment environment;

    @Test
    void 개발환경에서는_localhost_CORS가_등록된다() {
        when(environment.getActiveProfiles()).thenReturn(new String[]{"dev"});
        WebConfig webConfig = new WebConfig(environment);

        CorsRegistry registry = new CorsRegistry();
        webConfig.addCorsMappings(registry);

        Map<String, CorsConfiguration> configurations = getCorsConfigurations(registry);
        assertThat(configurations).containsKey("/api/**");
        assertThat(configurations.get("/api/**").getAllowedOrigins())
                .contains("http://localhost:3000", "http://localhost:8080");
    }

    @Test
    void 운영환경에서_허용Origin이_없으면_CORS를등록하지않는다() {
        when(environment.getActiveProfiles()).thenReturn(new String[]{"prod"});
        WebConfig webConfig = new WebConfig(environment);
        ReflectionTestUtils.setField(webConfig, "allowedOrigins", new String[]{""});

        CorsRegistry registry = new CorsRegistry();
        webConfig.addCorsMappings(registry);

        assertThat(getCorsConfigurations(registry)).isEmpty();
    }

    @Test
    void 운영환경에서_허용Origin이_설정되면_CORS를등록한다() {
        when(environment.getActiveProfiles()).thenReturn(new String[]{"prod"});
        WebConfig webConfig = new WebConfig(environment);
        ReflectionTestUtils.setField(webConfig, "allowedOrigins", new String[]{"https://admin.vocacrm.com"});

        CorsRegistry registry = new CorsRegistry();
        webConfig.addCorsMappings(registry);

        Map<String, CorsConfiguration> configurations = getCorsConfigurations(registry);
        assertThat(configurations).containsKey("/api/**");
        assertThat(configurations.get("/api/**").getAllowedOrigins())
                .containsExactly("https://admin.vocacrm.com");
    }

    @SuppressWarnings("unchecked")
    private Map<String, CorsConfiguration> getCorsConfigurations(CorsRegistry registry) {
        return (Map<String, CorsConfiguration>) ReflectionTestUtils.invokeMethod(registry, "getCorsConfigurations");
    }

    @Test
    void objectMapper빈은_ISO8601로_날짜를직렬화한다() throws Exception {
        WebConfig webConfig = new WebConfig(environment);
        ObjectMapper mapper = webConfig.objectMapper();

        assertThat(mapper.getSerializationConfig().isEnabled(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS)).isFalse();

        String json = mapper.writeValueAsString(LocalDateTime.of(2026, 7, 19, 10, 30));
        assertThat(json).isEqualTo("\"2026-07-19T10:30:00\"");
    }
}
