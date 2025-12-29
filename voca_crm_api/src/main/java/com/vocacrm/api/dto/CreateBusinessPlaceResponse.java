package com.vocacrm.api.dto;

import com.vocacrm.api.model.BusinessPlace;
import com.vocacrm.api.model.User;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class CreateBusinessPlaceResponse {
    private BusinessPlace businessPlace;
    private User user;
}
