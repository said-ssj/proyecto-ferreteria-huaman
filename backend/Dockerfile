FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /build
COPY pom.xml .
COPY src/ src/
RUN mvn -B -DskipTests -Dbackend.artifact-name=app package

FROM eclipse-temurin:21-jre-jammy
WORKDIR /app
COPY --from=build /build/target/app.jar ./app.jar
COPY certs/prod-ca-2021.crt ./certs/prod-ca-2021.crt
USER 10001:10001
EXPOSE 10000
ENTRYPOINT ["java", "-Djava.awt.headless=true", "-jar", "app.jar"]
