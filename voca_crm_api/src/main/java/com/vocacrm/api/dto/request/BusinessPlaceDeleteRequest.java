package com.vocacrm.api.dto.request;

import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/**
 * 사업장 삭제 확인 요청 DTO
 *
 * Type-to-Confirm 패턴을 위해 사업장 이름을 입력받습니다.
 */
@Data
@NoArgsConstructor
@AllArgsConstructor
public class BusinessPlaceDeleteRequest {

    /**
     * 삭제 확인을 위해 입력한 사업장 이름
     * 실제 사업장 이름과 정확히 일치해야 삭제가 진행됩니다.
     */
    @NotBlank(message = "사업장 이름을 입력해주세요")
    private String confirmName;
}
