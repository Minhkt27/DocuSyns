# Build stage
FROM eclipse-temurin:23-jdk AS build
WORKDIR /app
COPY .mvn/ .mvn/
COPY mvnw pom.xml ./
RUN chmod +x mvnw
RUN ./mvnw dependency:go-offline
COPY src ./src
RUN ./mvnw clean package -Dmaven.test.skip=true

# Run stage
FROM eclipse-temurin:23-jre
WORKDIR /app
# curl is used by the docker-compose healthcheck to probe /actuator/health
RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /app/target/DocuSync-0.0.1-SNAPSHOT.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
