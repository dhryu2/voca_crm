# ============================================
# Build Stage
# ============================================
# syntax = docker/dockerfile:1.4
FROM --platform=$BUILDPLATFORM gradle:8.14-jdk17 AS builder

WORKDIR /app

COPY gradlew .
COPY gradle gradle
COPY build.gradle .
COPY settings.gradle .

RUN chmod +x gradlew
RUN ./gradlew dependencies --no-daemon || true

COPY src src
RUN gradle bootJar --no-daemon -x test

# ============================================
# Runtime Stage
# ============================================
FROM eclipse-temurin:17-jre

WORKDIR /app

RUN useradd -r -m spring
USER spring:spring

COPY --from=builder /app/build/libs/*.jar app.jar

ENTRYPOINT ["java", "-jar", "app.jar"]
