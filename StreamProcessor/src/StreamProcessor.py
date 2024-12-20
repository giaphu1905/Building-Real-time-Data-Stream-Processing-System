from pyspark.sql import SparkSession
from pyspark.sql.functions import col, explode, udf, current_timestamp
from pyspark.sql.types import StringType
from pyspark.sql.avro.functions import from_avro
import uuid
import os

# Default config
cassandra_config = {
    'host': os.getenv('CASSANDRA_HOST', 'cassandra'),
    'keyspace': os.getenv('CASSANDRA_KEYSPACE', 'crypto_market_ksp'),
    'username': os.getenv('CASSANDRA_USERNAME', 'cassandra'),
    'password': os.getenv('CASSANDRA_PASSWORD', 'cassandra'),
    'tables': {
        'trades': os.getenv('CASSANDRA_TABLE_TRADES', 'trades'),
        'aggregates': os.getenv('CASSANDRA_TABLE_AGGREGATES', 'running_averages_15_sec')
    }
}

kafka_config = {
    'server': os.getenv('KAFKA_SERVER', 'kafka-service.pipeline.svc.cluster.local'),
    'port': os.getenv('KAFKA_PORT', '9092'),
    'topics': {
        'market': os.getenv('KAFKA_TOPIC_MARKET', 'crypto-market')
    },
    'min_partitions': os.getenv('KAFKA_MIN_PARTITIONS', '8')
}

spark_config = {
    'master': os.getenv('SPARK_MASTER', 'spark://spark-master:7077'),
    'appName': os.getenv('SPARK_APP_NAME', 'Stream Processor'),
    'max_offsets_per_trigger': os.getenv('SPARK_MAX_OFFSETS_PER_TRIGGER', '1000'),
    'shuffle_partitions': os.getenv('SPARK_SHUFFLE_PARTITIONS', '8'),
    'deprecated_offsets': os.getenv('SPARK_DEPRECATED_OFFSETS', 'false')
}

schemas_config = {
    'trades': os.getenv('SCHEMA_TRADES_PATH', 'src/schemas/trades.avsc')
}

# Hàm tạo UUID
def generate_uuid():
    return str(uuid.uuid1())

# Đăng ký UDF cho UUID
spark = SparkSession.builder.getOrCreate()
generate_uuid_udf = udf(generate_uuid, StringType())

# Tạo Spark session
    
spark = SparkSession.builder \
    .master(spark_config['master']) \
    .appName(spark_config['appName']) \
    .config("spark.sql.shuffle.partitions", spark_config['shuffle_partitions']) \
    .config("spark.cassandra.connection.host", cassandra_config['host']) \
    .config("spark.cassandra.auth.username", cassandra_config['username']) \
    .config("spark.cassandra.auth.password", cassandra_config['password']) \
    .config("spark.sql.streaming.stateStore.providerClass", "org.apache.spark.sql.execution.streaming.state.RocksDBStateStoreProvider") \
    .config("spark.sql.streaming.statefulOperator.stateRebalancing.enabled","true") \
    .config("spark.sql.streaming.statefulOperator.asyncCheckpoint.enabled","true") \
    .config("spark.sql.streaming.stateStore.rocksdb.changelogCheckpointing.enabled", "true") \
    .getOrCreate()

spark.sparkContext.setLogLevel("WARN") # > WARN

# Đọc schema của trades
with open(schemas_config['trades'], 'r') as file:
    trades_schema = file.read()

    
# Đọc streams từ Kafka
# 
input_df = spark.readStream \
    .format("kafka") \
    .option("kafka.bootstrap.servers", f"{kafka_config['server']}:{kafka_config['port']}") \
    .option("subscribe", kafka_config['topics']['market']) \
    .option("minPartitions", kafka_config['min_partitions']) \
    .option("maxOffsetsPerTrigger", spark_config['max_offsets_per_trigger']) \
    .option("useDeprecatedOffsetFetching", spark_config['deprecated_offsets']) \
    .load()

# Giải nén dữ liệu từ Avro
expanded_df = input_df \
    .withColumn("avroData", from_avro(col("value"), trades_schema)) \
    .select("avroData.*") \
    .select(explode("data"), "type") \
    .select("col.*")

# Đổi tên cột và thêm timestamp
final_df = expanded_df \
    .withColumn("uuid", generate_uuid_udf()) \
    .withColumnRenamed("c", "trade_conditions") \
    .withColumnRenamed("p", "price") \
    .withColumnRenamed("s", "symbol") \
    .withColumnRenamed("t", "trade_timestamp") \
    .withColumnRenamed("v", "volume") \
    .withColumn("trade_timestamp", (col("trade_timestamp") / 1000).cast("timestamp")) \
    .withColumn("ingest_timestamp", current_timestamp())

# Ghi dữ liệu vào Cassandra
query = final_df.writeStream \
    .trigger(processingTime='1000 milliseconds') \
    .foreachBatch(lambda batchDF, batchID:
        batchDF.write \
            .format("org.apache.spark.sql.cassandra") \
            .options(table=cassandra_config['tables']['trades'], keyspace=cassandra_config['keyspace']) \
            .mode("append") \
            .save()
    ) \
    .outputMode("update") \
    .start()

# Tạo dataframe với các aggregates - trung bình chạy trong 15 giây cuối cùng
summary_df = final_df \
    .withColumn("price_volume_multiply", col("price") * col("volume")) \
    .withWatermark("trade_timestamp", "15 seconds") \
    .groupBy("symbol") \
    .agg({"price_volume_multiply": "avg"})

# Đổi tên cột và thêm UUIDs 
final_summary_df = summary_df \
    .withColumn("uuid", generate_uuid_udf()) \
    .withColumn("ingest_timestamp", current_timestamp()) \
    .withColumnRenamed("avg(price_volume_multiply)", "price_volume_multiply")



query2 = final_summary_df \
    .writeStream \
    .trigger(processingTime='5 seconds') \
    .foreachBatch(lambda batchDF, batchID: 
        batchDF.write \
            .format("org.apache.spark.sql.cassandra") \
            .options(table=cassandra_config['tables']['aggregates'], keyspace=cassandra_config['keyspace']) \
            .mode("append") \
            .save()
    ) \
    .outputMode("update") \
    .start()

# Đợi cho đến khi các streams kết thúc
spark.streams.awaitAnyTermination()