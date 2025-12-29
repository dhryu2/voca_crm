package com.vocacrm.api.repository;

import com.vocacrm.api.model.BusinessPlace;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

@Repository
public interface BusinessPlaceRepository extends JpaRepository<BusinessPlace, String> {
    boolean existsById(String id);
}
