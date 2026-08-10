package com.docusync.documentstorage.application.domain.model;

import java.io.InputStream;

public record FileDownload(
    InputStream stream,
    String fileName
) {}
