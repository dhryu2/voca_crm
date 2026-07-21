package com.vocacrm.api.util;

import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

class ValidationUtilsTest {

    @Test
    void isValidUUID_유효한_UUID면_true를_반환한다() {
        assertThat(ValidationUtils.isValidUUID("550e8400-e29b-41d4-a716-446655440000")).isTrue();
    }

    @Test
    void isValidUUID_형식이_틀리면_false를_반환한다() {
        assertThat(ValidationUtils.isValidUUID("not-a-uuid")).isFalse();
    }

    @Test
    void validateUUID_형식이_틀리면_예외를_발생시킨다() {
        assertThatThrownBy(() -> ValidationUtils.validateUUID("invalid", "memberId"))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void isValidBusinessPlaceId_유효한_형식이면_true를_반환한다() {
        assertThat(ValidationUtils.isValidBusinessPlaceId("ABC1234")).isTrue();
    }

    @Test
    void isValidUUID_null이면_false를_반환한다() {
        assertThat(ValidationUtils.isValidUUID(null)).isFalse();
    }

    @Test
    void isValidUUID_공백이면_false를_반환한다() {
        assertThat(ValidationUtils.isValidUUID("  ")).isFalse();
    }

    @Test
    void validateUUID_유효한_UUID면_예외를_던지지_않는다() {
        ValidationUtils.validateUUID("550e8400-e29b-41d4-a716-446655440000", "memberId");
    }

    @Test
    void parseUUID_유효한_UUID면_UUID를_반환한다() {
        UUID result = ValidationUtils.parseUUID("550e8400-e29b-41d4-a716-446655440000", "memberId");

        assertThat(result).isEqualTo(UUID.fromString("550e8400-e29b-41d4-a716-446655440000"));
    }

    @Test
    void parseUUID_형식이_틀리면_예외를_발생시킨다() {
        assertThatThrownBy(() -> ValidationUtils.parseUUID("invalid", "memberId"))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void isValidBusinessPlaceId_null이면_false를_반환한다() {
        assertThat(ValidationUtils.isValidBusinessPlaceId(null)).isFalse();
    }

    @Test
    void isValidBusinessPlaceId_공백이면_false를_반환한다() {
        assertThat(ValidationUtils.isValidBusinessPlaceId("  ")).isFalse();
    }

    @Test
    void isValidBusinessPlaceId_형식이_틀리면_false를_반환한다() {
        assertThat(ValidationUtils.isValidBusinessPlaceId("abc1234")).isFalse();
    }

    @Test
    void validateBusinessPlaceId_유효한_형식이면_예외를_던지지_않는다() {
        ValidationUtils.validateBusinessPlaceId("ABC1234");
    }

    @Test
    void validateBusinessPlaceId_형식이_틀리면_예외를_발생시킨다() {
        assertThatThrownBy(() -> ValidationUtils.validateBusinessPlaceId("invalid"))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void validateNotBlank_null이면_예외를_발생시킨다() {
        assertThatThrownBy(() -> ValidationUtils.validateNotBlank(null, "name"))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void validateNotBlank_공백이면_예외를_발생시킨다() {
        assertThatThrownBy(() -> ValidationUtils.validateNotBlank("  ", "name"))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void validateNotBlank_값이_있으면_예외를_던지지_않는다() {
        ValidationUtils.validateNotBlank("value", "name");
    }

    @Test
    void validateMaxLength_초과하면_예외를_발생시킨다() {
        assertThatThrownBy(() -> ValidationUtils.validateMaxLength("12345", 3, "name"))
                .isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void validateMaxLength_이내면_예외를_던지지_않는다() {
        ValidationUtils.validateMaxLength("123", 5, "name");
    }

    @Test
    void validateMaxLength_null이면_예외를_던지지_않는다() {
        ValidationUtils.validateMaxLength(null, 5, "name");
    }
}
