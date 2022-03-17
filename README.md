# streaming example

Using Avro dummy data created with [kafka-connect-datagen](https://github.com/confluentinc/kafka-connect-datagen) and a schema stored in the [Confluent schema registry](https://www.confluent.io/product/confluent-platform/data-compatibility/) I show how to process this data using a streaming engine.
The idea is to demonstrate reading the events from kafka, performing some abitrary computation and writing back to kafka.
I will focus on the SQL-(ish) APIs over the code-based ones in this demonstration.

The following two Streaming engines will be compared:

- Apache Spark
- Apache Flink
- Kafka SQL

> NOTICE: This is not meant for performance comparision. Spark i.e. does not offer an active master replication whereas flink guarantees high availability. 
> Indeed, the resource manager will restart the Spark master - however this additional delay (depending on the use-case) might not be acceptable.

## environment setup

To get access to a kafka installation please start a couple of docker containers:

```bash
docker-compose up
```
- Schema Registry: localhost:8081
- Control Center: localhost:9021

In case you have any problems: [the official Confluent quickstart guide](https://docs.confluent.io/platform/current/quickstart) is a good resource when looking for answers.

Flink and Spark both currently work well with JDK 8 or 11. The most recent LTS (17) is not yet fully supported.

[KafkaEsqu](https://kafka.esque.at/) is a great Kafka Development GUI.
The latest release however, requires a Java 17 installation or newer.
On OsX it might fail to start. To fix it follow the instructions in [the official readme](https://github.com/patschuh/KafkaEsque):

```bash
xattr -rd com.apple.quarantine kafkaesque-2.1.0.dmg
```

## generating dummy data

I follow the `Orders` example from the official Confluent example https://docs.confluent.io/5.4.0/ksql/docs/tutorials/generate-custom-test-data.html.
[https://thecodinginterface.com/blog/kafka-connect-datagen-plugin/](https://thecodinginterface.com/blog/kafka-connect-datagen-plugin/) might additionally be a good resource when you want to learn more about this stack. We follow their example schema:

Let's use a custom schema:

```bash
{
  "type": "record",
  "name": "commercialrating",
  "fields": [
    {
      "name": "brand",
      "type": {
        "type": "string",
        "arg.properties": {
          "options": ["Acme", "Globex"]
        }
      }
    }, 
    {
      "name": "duration",
      "type": {
        "type": "int",
        "arg.properties": {
          "options": [30, 45, 60]
        }
      }
    },
    {
      "name": "rating",
      "type": {
        "type": "int",
        "arg.properties": {
          "range": { "min": 1, "max": 5 }
        }
      } 
    }
  ]
}
```

Go to the [Confluent Control Center on: localhost:9021](localhost:9021) and select the **controlcenter.cluster** cluster.

You can either use the UI:

![ui for datagen](img/ui-datagen.png)

or use the REST API to POST the user-defined schema from above to the kafka connect data generator. For this you need to set some additional properties (like how many data points should be generated):

As JSON:

```
{
  "name": "datagen-commercials-json",
  "config": {
    "connector.class": "io.confluent.kafka.connect.datagen.DatagenConnector",
    "kafka.topic": "commercials_json",
    "schema.string": "{\"type\":\"record\",\"name\":\"commercialrating\",\"fields\":[{\"name\":\"brand\",\"type\":{\"type\": \"string\",\"arg.properties\":{\"options\":[\"Acme\",\"Globex\"]}}},{\"name\":\"duration\",\"type\":{\"type\":\"int\",\"arg.properties\":{\"options\": [30, 45, 60]}}},{\"name\":\"rating\",\"type\":{\"type\":\"int\",\"arg.properties\":{\"range\":{\"min\":1,\"max\":5}}}}]}",
    "schema.keyfield": "brand",
    "key.converter": "org.apache.kafka.connect.storage.StringConverter",
    "value.converter": "org.apache.kafka.connect.json.JsonConverter",
    "value.converter.schemas.enable": "false",
    "max.interval": 1000,
    "iterations": 1000,
    "tasks.max": "1"
  }
}
```

As AVRO with the Confluent schema registry:

```
{
  "name": "datagen-commercials-avro",
  "config": {
    "connector.class": "io.confluent.kafka.connect.datagen.DatagenConnector",
    "kafka.topic": "commercials_avro",
    "schema.string": "{\"type\":\"record\",\"name\":\"commercialrating\",\"fields\":[{\"name\":\"brand\",\"type\":{\"type\": \"string\",\"arg.properties\":{\"options\":[\"Acme\",\"Globex\"]}}},{\"name\":\"duration\",\"type\":{\"type\":\"int\",\"arg.properties\":{\"options\": [30, 45, 60]}}},{\"name\":\"rating\",\"type\":{\"type\":\"int\",\"arg.properties\":{\"range\":{\"min\":1,\"max\":5}}}}]}",
    "schema.keyfield": "brand",
    "key.converter": "org.apache.kafka.connect.storage.StringConverter",
    "value.converter": "io.confluent.connect.avro.AvroConverter",
    "value.converter.schema.registry.url": "http://schema-registry:8081",
    "value.converter.schemas.enable": "false",
    "max.interval": 1000,
    "iterations": 1000,
    "tasks.max": "1"
  }
}
```

Notice how only the serializeer changes from:

```
"key.converter": "org.apache.kafka.connect.storage.StringConverter",
"value.converter": "org.apache.kafka.connect.json.JsonConverter",
```

to:

```
"value.converter": "io.confluent.connect.avro.AvroConverter",
"value.converter.schema.registry.url": "http://schema-registry:8081",
```

when switching over to avro

Assuming you have stored this JSON snippet as a file named: `datagen-json-commercials-config.json` you can now interact with the REST API using:

```
curl -X POST -H "Content-Type: application/json" -d @datagen-json-commercials-config.json http://localhost:8083/connectors | jq
```

Observe the running connector:

![running connector](img/running-connector.png)

But you can also check the status from the commandline:
```
curl http://localhost:8083/connectors/datagen-commercials-json/status | jq

curl http://localhost:8083/connectors/datagen-commercials-avro/status | jq
```

As a sanity check you can consume some records:

```
docker exec -it broker kafka-console-consumer --bootstrap-server localhost:9092 \
    --topic commercials_json --property print.key=true

docker exec -it broker kafka-console-consumer --bootstrap-server localhost:9092 \
    --topic commercials_avro --property print.key=true
```

These are also available in the UI of Confluent Control Center:

![control center topic contents](img/messages-in-topic.png)

And KafkaEsque. But KafkaEsque needs to be configured first to view the kafka records:

![KafkaEsque setup](img/k1.png)

Then the results are visible here:

![KafkaEsque visualization](img/k2.png)

To stop the connector simply either delete it in the UI of the control center or use the REST API:

```
curl -X DELETE http://localhost:8083/connectors/datagen-commercials-json

curl -X DELETE http://localhost:8083/connectors/datagen-commercials-avro
```


The official quickstart is 
first: the topic 

```bash
<path-to-confluent>/ksql-datagen quickstart=orders topic=orders_topic
```

## Spark

## Flink

## Kafka SQL

## summary

The code for this blog post is available at: XXX TODO XXX


gou mamba

heinz, manfred.