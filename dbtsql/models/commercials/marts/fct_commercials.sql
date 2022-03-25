{{ config(
    materialized ='materializedview'
) }}

SELECT brand,
         COUNT(*) AS cnt,
         AVG(duration) AS  duration_mean,
         AVG(rating) AS rating_mean
  FROM {{ ref('stg_commercials_information') }}
  GROUP BY brand
