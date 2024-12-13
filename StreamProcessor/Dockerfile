FROM maven:3.9.9-amazoncorretto-8-alpine AS builder

WORKDIR /maven

COPY pom.xml . 
RUN mvn dependency:copy-dependencies

FROM apache/spark:3.4.4-python3

WORKDIR /app

COPY --from=builder maven/target/dependency/ /opt/spark/jars/

COPY . .

USER root

RUN pip install -r requirements.txt

CMD ["spark-submit", "src/StreamProcessor.py"]
