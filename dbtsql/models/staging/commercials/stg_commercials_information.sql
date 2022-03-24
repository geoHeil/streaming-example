/*

The purpose of this model is to create a flight_information staging model
with light transformations on top of the source.
*/

{{ config(
    materialized='view'
) }}


WITH source AS (

    SELECT * FROM {{ ref('rp_comercials_information') }}

),

converted AS (

    SELECT convert_from(data, 'utf8') AS data FROM source

),

casted AS (

    SELECT cast(data AS jsonb) AS data FROM converted

),

renamed AS (

    SELECT

       (data->>'brand')::string as brand,
       (data->>'duration')::int as duration,
       (data->>'rating')::int as rating

    FROM casted

)

SELECT * FROM renamed
