package com.docusync.documentstorage.application.domain.model;

import java.util.List;

public record PageResult<T>(
    List<T> content,
    int currentPage,
    int totalPages,
    long totalElements,
    boolean hasNext
) {}
