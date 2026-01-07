package com.vocacrm.api.util;

import java.util.UUID;
import java.util.regex.Pattern;

/**
 * 입력 값 검증 유틸리티
 *
 * ID 형식 검증을 통일하여 일관된 검증을 제공합니다.
 */
public final class ValidationUtils {

    private ValidationUtils() {
        // 유틸리티 클래스 - 인스턴스화 방지
    }

    /**
     * UUID 형식 정규식 패턴
     * 예: 550e8400-e29b-41d4-a716-446655440000
     */
    private static final Pattern UUID_PATTERN = Pattern.compile(
            "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
    );

    /**
     * Business Place ID 형식 정규식 패턴
     * 7자리 영문 대문자 + 숫자 조합
     * 예: ABC1234, XYZ9876
     */
    private static final Pattern BUSINESS_PLACE_ID_PATTERN = Pattern.compile(
            "^[A-Z0-9]{7}$"
    );

    /**
     * UUID 형식 검증
     *
     * @param id 검증할 ID
     * @return 유효한 UUID 형식이면 true
     */
    public static boolean isValidUUID(String id) {
        if (id == null || id.isBlank()) {
            return false;
        }
        return UUID_PATTERN.matcher(id).matches();
    }

    /**
     * UUID 형식 검증 (예외 발생)
     *
     * @param id 검증할 ID
     * @param fieldName 필드명 (에러 메시지용)
     * @throws IllegalArgumentException 유효하지 않은 UUID 형식인 경우
     */
    public static void validateUUID(String id, String fieldName) {
        if (!isValidUUID(id)) {
            throw new IllegalArgumentException(fieldName + "의 형식이 올바르지 않습니다. (UUID 형식 필요)");
        }
    }

    /**
     * UUID 파싱 (검증 포함)
     *
     * @param id 파싱할 ID
     * @param fieldName 필드명 (에러 메시지용)
     * @return 파싱된 UUID
     * @throws IllegalArgumentException 유효하지 않은 UUID 형식인 경우
     */
    public static UUID parseUUID(String id, String fieldName) {
        validateUUID(id, fieldName);
        try {
            return UUID.fromString(id);
        } catch (IllegalArgumentException e) {
            throw new IllegalArgumentException(fieldName + "의 형식이 올바르지 않습니다. (UUID 형식 필요)");
        }
    }

    /**
     * Business Place ID 형식 검증
     *
     * @param id 검증할 ID
     * @return 유효한 Business Place ID 형식이면 true
     */
    public static boolean isValidBusinessPlaceId(String id) {
        if (id == null || id.isBlank()) {
            return false;
        }
        return BUSINESS_PLACE_ID_PATTERN.matcher(id).matches();
    }

    /**
     * Business Place ID 형식 검증 (예외 발생)
     *
     * @param id 검증할 ID
     * @throws IllegalArgumentException 유효하지 않은 Business Place ID 형식인 경우
     */
    public static void validateBusinessPlaceId(String id) {
        if (!isValidBusinessPlaceId(id)) {
            throw new IllegalArgumentException("사업장 ID의 형식이 올바르지 않습니다. (7자리 영문 대문자/숫자 조합 필요)");
        }
    }

    /**
     * null 또는 빈 문자열 검증
     *
     * @param value 검증할 값
     * @param fieldName 필드명 (에러 메시지용)
     * @throws IllegalArgumentException null 또는 빈 문자열인 경우
     */
    public static void validateNotBlank(String value, String fieldName) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException(fieldName + "은(는) 필수입니다.");
        }
    }

    /**
     * 최대 길이 검증
     *
     * @param value 검증할 값
     * @param maxLength 최대 길이
     * @param fieldName 필드명 (에러 메시지용)
     * @throws IllegalArgumentException 최대 길이를 초과한 경우
     */
    public static void validateMaxLength(String value, int maxLength, String fieldName) {
        if (value != null && value.length() > maxLength) {
            throw new IllegalArgumentException(fieldName + "은(는) " + maxLength + "자를 초과할 수 없습니다.");
        }
    }
}
