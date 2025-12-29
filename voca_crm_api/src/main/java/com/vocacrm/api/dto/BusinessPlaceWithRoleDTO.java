package com.vocacrm.api.dto;

import com.vocacrm.api.model.BusinessPlace;
import com.vocacrm.api.model.Role;

public class BusinessPlaceWithRoleDTO {
    private BusinessPlace businessPlace;
    private Role userRole;
    private int memberCount;

    public BusinessPlaceWithRoleDTO(BusinessPlace businessPlace, Role userRole, int memberCount) {
        this.businessPlace = businessPlace;
        this.userRole = userRole;
        this.memberCount = memberCount;
    }

    public BusinessPlace getBusinessPlace() {
        return businessPlace;
    }

    public void setBusinessPlace(BusinessPlace businessPlace) {
        this.businessPlace = businessPlace;
    }

    public Role getUserRole() {
        return userRole;
    }

    public void setUserRole(Role userRole) {
        this.userRole = userRole;
    }

    public int getMemberCount() {
        return memberCount;
    }

    public void setMemberCount(int memberCount) {
        this.memberCount = memberCount;
    }
}
