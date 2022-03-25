{{ config(
    materialized ='sink'
) }}

{% set sink_name %}
    {{ mz_generate_name('metrics_per_brand') }}
{% endset %}

CREATE SINK {{ sink_name }}
FROM {{ ref('fct_commercials') }}
INTO KAFKA BROKER 'localhost:9092' TOPIC 'metrics_per_brand_materialize'
KEY (brand)

CONSISTENCY (TOPIC 'metrics_per_brand_materialize-consistency'
             FORMAT AVRO USING CONFLUENT SCHEMA REGISTRY 'http://localhost:8081')
WITH (reuse_topic=true)

FORMAT AVRO USING
    CONFLUENT SCHEMA REGISTRY 'http://localhost:8081';