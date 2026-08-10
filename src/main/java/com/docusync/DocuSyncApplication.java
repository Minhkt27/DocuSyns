package com.docusync;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class DocuSyncApplication {

	public static void main(String[] args) {
		SpringApplication.run(DocuSyncApplication.class, args);
	}

}
