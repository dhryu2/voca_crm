package com.vocacrm.api.dto;

import com.vocacrm.api.model.User;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class SetDefaultBusinessPlaceResponse {
    private User user;
}
