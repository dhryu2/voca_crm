package com.vocacrm.api;

import io.github.cdimascio.dotenv.Dotenv;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

/**
 * VocaCRM API 애플리케이션의 메인 클래스
 *
 * Spring Boot 애플리케이션의 진입점(Entry Point)으로,
 * 음성 기반 고객 검색 및 회원 관리 CRM 시스템의 백엔드 API를 제공합니다.
 *
 * @SpringBootApplication 어노테이션은 다음 3가지를 포함합니다:
 * - @Configuration: 설정 클래스임을 나타냄
 * - @EnableAutoConfiguration: Spring Boot의 자동 설정 활성화
 * - @ComponentScan: 현재 패키지 및 하위 패키지의 컴포넌트 스캔
 *
 * @EnableScheduling: 스케줄링 기능 활성화 (예약 데이터 자동 정리 등)
 *
 * @author VocaCRM Team
 * @version 1.0
 */
@SpringBootApplication
@EnableScheduling
public class VocaCrmApiApplication {

	/**
	 * 애플리케이션 메인 메서드
	 *
	 * Spring Boot 애플리케이션을 시작하며,
	 * 내장 Tomcat 서버를 구동하여 REST API를 제공합니다.
	 *
	 * @param args 커맨드 라인 인자
	 */
	public static void main(String[] args) {
        // Docker 환경변수가 있으면 우선 사용, 없으면 .env 로드
        loadEnvironmentVariables();

        SpringApplication.run(VocaCrmApiApplication.class, args);
	}

    private static void loadEnvironmentVariables() {
        // Docker에서 환경변수가 이미 설정되어 있는지 확인
        if (System.getenv("DB_HOST") != null) {
            return;
        }

        // 로컬 개발: .env 파일 로드
        try {
            Dotenv dotenv = Dotenv.configure()
                    .directory("./")
                    .ignoreIfMissing()
                    .load();

            dotenv.entries().forEach(entry ->
                    System.setProperty(entry.getKey(), entry.getValue())
            );

        } catch (Exception e) {
            // .env 파일이 없으면 기본값 사용
        }
    }
}
