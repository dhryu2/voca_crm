package com.vocacrm.api.dto.request;

import jakarta.validation.constraints.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 회원 생성 요청 DTO
 *
 * 모든 필수 필드에 대한 검증 규칙을 정의합니다.
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class MemberCreateRequest {

    @NotBlank(message = "회원번호는 필수입니다")
    @Size(max = 50, message = "회원번호는 50자 이내로 입력해주세요")
    @Pattern(regexp = "^[a-zA-Z0-9\\-]+$", message = "회원번호는 영문, 숫자, 하이픈(-)만 입력 가능합니다")
    private String memberNumber;

    @NotBlank(message = "이름은 필수입니다")
    @Size(min = 1, max = 100, message = "이름은 1~100자 사이로 입력해주세요")
    private String name;

    @Size(max = 20, message = "전화번호는 20자 이내로 입력해주세요")
    @Pattern(regexp = "^$|^01[0-9]-?[0-9]{3,4}-?[0-9]{4}$|^02-?[0-9]{3,4}-?[0-9]{4}$|^0[3-6][0-9]-?[0-9]{3,4}-?[0-9]{4}$|^1[56]\\d{2}-?[0-9]{4}$|^18\\d{2}-?[0-9]{4}$|^080-?[0-9]{3,4}-?[0-9]{4}$",
             message = "올바른 전화번호 형식이 아닙니다 (예: 02-1234-5678, 010-1234-5678, 1588-1234)")
    private String phone;

    @Size(max = 100, message = "이메일은 100자 이내로 입력해주세요")
    @Email(message = "올바른 이메일 형식이 아닙니다")
    private String email;

    @NotBlank(message = "사업장 ID는 필수입니다")
    @Size(max = 36, message = "사업장 ID 형식이 올바르지 않습니다")
    private String businessPlaceId;

    @Size(max = 128, message = "소유자 ID 형식이 올바르지 않습니다")
    private String ownerId;

    @Size(max = 20, message = "등급은 20자 이내로 입력해주세요")
    private String grade;

    @Size(max = 2000, message = "비고는 2000자 이내로 입력해주세요")
    private String remark;
}
