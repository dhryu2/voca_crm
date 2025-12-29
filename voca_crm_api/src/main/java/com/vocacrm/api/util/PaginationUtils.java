package com.vocacrm.api.util;

/**
 * 페이지네이션 유틸리티
 *
 * 모든 API에서 일관된 페이지네이션 제한을 적용합니다.
 */
public final class PaginationUtils {

    /**
     * 최대 페이지 크기
     */
    public static final int MAX_PAGE_SIZE = 100;

    /**
     * 기본 페이지 크기
     */
    public static final int DEFAULT_PAGE_SIZE = 20;

    private PaginationUtils() {
        // Utility class - prevent instantiation
    }

    /**
     * 페이지 크기를 검증하고 최대값 이내로 제한
     *
     * @param requestedSize 요청된 페이지 크기
     * @return 제한된 페이지 크기 (1 ~ MAX_PAGE_SIZE)
     */
    public static int limitPageSize(int requestedSize) {
        if (requestedSize < 1) {
            return DEFAULT_PAGE_SIZE;
        }
        return Math.min(requestedSize, MAX_PAGE_SIZE);
    }

    /**
     * 페이지 번호를 검증
     *
     * @param requestedPage 요청된 페이지 번호
     * @return 검증된 페이지 번호 (최소 0)
     */
    public static int validatePage(int requestedPage) {
        return Math.max(0, requestedPage);
    }
}
