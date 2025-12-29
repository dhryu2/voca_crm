package com.vocacrm.api.dto.request;

import jakarta.validation.constraints.*;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 사업장 생성 요청 DTO
 */
@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class BusinessPlaceCreateRequest {

    @NotBlank(message = "사업장 이름은 필수입니다")
    @Size(min = 1, max = 100, message = "사업장 이름은 1~100자 사이로 입력해주세요")
    private String name;

    @Size(max = 200, message = "주소는 200자 이내로 입력해주세요")
    private String address;

    @Size(max = 20, message = "전화번호는 20자 이내로 입력해주세요")
    @Pattern(regexp = "^$|^01[0-9]-?[0-9]{3,4}-?[0-9]{4}$|^02-?[0-9]{3,4}-?[0-9]{4}$|^0[3-6][0-9]-?[0-9]{3,4}-?[0-9]{4}$|^1[56]\\d{2}-?[0-9]{4}$|^18\\d{2}-?[0-9]{4}$|^080-?[0-9]{3,4}-?[0-9]{4}$",
             message = "올바른 전화번호 형식이 아닙니다 (예: 02-1234-5678, 010-1234-5678, 1588-1234)")
    private String phone;
}
