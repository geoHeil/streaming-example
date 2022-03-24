{{ config(materialized='source') }}

{% set source_name %}
    {{ mz_generate_name('metrics_brand_stream_m') }}
{% endset %}

CREATE SOURCE {{ source_name }}
  FROM KAFKA BROKER 'localhost:9092' TOPIC 'commercials_avro'
  FORMAT AVRO USING CONFLUENT SCHEMA REGISTRY 'http://localhost:8081'
  INCLUDE PARTITION, OFFSET, TIMESTAMP AS ts
  ENVELOPE NONE;